local RideRequests = {}
local PlayerRoles = {}
local DriverOnline = {}
local ActiveTrips = {}
local LastRequestAt = {}
local RequestCounter = 0

local function now()
    return os.time()
end

local function getPlayerNameSafe(src)
    local name = GetPlayerName(src)
    if not name or name == '' then
        return ('ID %s'):format(src)
    end
    return name
end

local function isDriverOnline(src)
    return DriverOnline[src] == true and PlayerRoles[src] == 'driver'
end

local function isPassenger(src)
    return PlayerRoles[src] == 'passenger' or PlayerRoles[src] == nil
end

local function hasDriverLicense(src)
    if not Config.RequireDriverLicense then
        return true
    end

    if Config.UseAceForLicense then
        return IsPlayerAceAllowed(src, Config.DriverLicenseAce)
    end

    local identifiers = GetPlayerIdentifiers(src)
    for _, identifier in ipairs(identifiers) do
        if Config.DriverLicenseIdentifiers[identifier] then
            return true
        end
    end

    return false
end

local function estimatePrice(origin, destination)
    local dx = destination.x - origin.x
    local dy = destination.y - origin.y
    local dz = destination.z - origin.z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    local total = Config.BaseFare + (distance * Config.PricePerMeter)
    return math.floor(total + 0.5), distance
end

local function sendHint(src, message)
    TriggerClientEvent('chat:addMessage', src, {
        color = { 0, 200, 255 },
        args = { '[RideGo]', message }
    })
end

local function broadcastToOnlineDrivers(eventName, payload)
    for _, playerId in ipairs(GetPlayers()) do
        local numericId = tonumber(playerId)
        if numericId and isDriverOnline(numericId) then
            TriggerClientEvent(eventName, numericId, payload)
        end
    end
end

local function clearRequest(requestId)
    local request = RideRequests[requestId]
    if not request then
        return
    end

    RideRequests[requestId] = nil
    TriggerClientEvent('ridego:client:requestClosed', -1, requestId)
end

AddEventHandler('playerDropped', function()
    local src = source
    local active = ActiveTrips[src]

    if active then
        local other = active.other
        local role = active.role
        ActiveTrips[src] = nil

        if other and ActiveTrips[other] then
            ActiveTrips[other] = nil
            sendHint(other, 'A corrida foi encerrada porque o outro jogador desconectou.')
            TriggerClientEvent('ridego:client:endTrip', other)
        end

        if role == 'driver' and active.requestId then
            clearRequest(active.requestId)
        end
    end

    PlayerRoles[src] = nil
    DriverOnline[src] = nil
    LastRequestAt[src] = nil

    for requestId, req in pairs(RideRequests) do
        if req.passenger == src or req.driver == src or req.requester == src then
            clearRequest(requestId)
        end
    end
end)

RegisterNetEvent('ridego:server:goOnline', function()
    local src = source

    if not hasDriverLicense(src) then
        sendHint(src, 'Você precisa de uma CNH')
        return
    end

    PlayerRoles[src] = 'driver'
    DriverOnline[src] = true
    sendHint(src, 'Você ficou Online como motorista e já pode receber chamadas.')
end)

RegisterNetEvent('ridego:server:goOffline', function()
    local src = source

    if ActiveTrips[src] and ActiveTrips[src].role == 'driver' then
        sendHint(src, 'Finalize ou cancele a corrida atual antes de ficar Offline.')
        return
    end

    DriverOnline[src] = false
    if PlayerRoles[src] == 'driver' then
        PlayerRoles[src] = nil
    end

    sendHint(src, 'Você ficou Offline e não receberá novas chamadas.')
end)

RegisterNetEvent('ridego:server:setRole', function(role)
    local src = source
    if role ~= 'passenger' then
        sendHint(src, 'Função inválida. Use passenger, online ou offline.')
        return
    end

    PlayerRoles[src] = role
    DriverOnline[src] = false
    sendHint(src, ('Você entrou no modo %s.'):format(role))
end)

RegisterNetEvent('ridego:server:requestRide', function(origin, destination, requestType)
    local src = source
    requestType = requestType == 'npc' and 'npc' or 'player'

    if requestType == 'player' and not isPassenger(src) then
        sendHint(src, 'Apenas passageiros podem solicitar corridas de player.')
        return
    end

    if ActiveTrips[src] then
        sendHint(src, 'Você já está em uma corrida ativa.')
        return
    end

    local last = LastRequestAt[src] or 0
    if now() - last < Config.RequestCooldown then
        sendHint(src, ('Aguarde %s segundos para pedir outra corrida.'):format(Config.RequestCooldown - (now() - last)))
        return
    end

    if type(origin) ~= 'table' or type(destination) ~= 'table' then
        sendHint(src, 'Coordenadas inválidas para corrida.')
        return
    end

    RequestCounter = RequestCounter + 1
    local price, distance = estimatePrice(origin, destination)

    local request = {
        id = RequestCounter,
        type = requestType,
        requester = src,
        requesterName = getPlayerNameSafe(src),
        origin = origin,
        destination = destination,
        price = price,
        distance = distance,
        createdAt = now(),
        status = 'open',
        npcModel = Config.NPCModel
    }

    if requestType == 'player' then
        request.passenger = src
        request.passengerName = getPlayerNameSafe(src)
    else
        request.passengerName = 'NPC'
    end

    RideRequests[request.id] = request
    LastRequestAt[src] = now()

    if requestType == 'npc' then
        sendHint(src, ('Corrida NPC criada (#%s). Estimativa: $%s.'):format(request.id, request.price))
    else
        sendHint(src, ('Corrida criada (#%s). Estimativa: $%s.'):format(request.id, request.price))
    end

    broadcastToOnlineDrivers('ridego:client:newRequest', request)
end)

RegisterNetEvent('ridego:server:acceptRide', function(requestId)
    local src = source
    requestId = tonumber(requestId)

    if not requestId then
        sendHint(src, 'ID de corrida inválido.')
        return
    end

    if not isDriverOnline(src) then
        sendHint(src, 'Você precisa ficar Online para aceitar corridas.')
        return
    end

    if ActiveTrips[src] then
        sendHint(src, 'Você já está em corrida ativa.')
        return
    end

    local request = RideRequests[requestId]
    if not request then
        sendHint(src, 'Essa corrida não está mais disponível.')
        return
    end

    if request.type == 'player' and ActiveTrips[request.passenger] then
        clearRequest(requestId)
        sendHint(src, 'Passageiro já entrou em outra corrida.')
        return
    end

    request.driver = src
    request.driverName = getPlayerNameSafe(src)
    request.status = 'accepted'

    if request.type == 'npc' then
        ActiveTrips[src] = {
            role = 'driver',
            other = nil,
            requestId = requestId,
            stage = 'pickup'
        }

        TriggerClientEvent('ridego:client:tripAccepted', src, request)
        TriggerClientEvent('ridego:client:requestClosed', -1, requestId)

        sendHint(src, ('Você aceitou a corrida NPC #%s.'):format(request.id))
        if request.requester then
            sendHint(request.requester, ('%s aceitou a corrida NPC #%s.'):format(request.driverName, request.id))
        end
        return
    end

    ActiveTrips[src] = {
        role = 'driver',
        other = request.passenger,
        requestId = requestId,
        stage = 'pickup'
    }

    ActiveTrips[request.passenger] = {
        role = 'passenger',
        other = src,
        requestId = requestId,
        stage = 'pickup'
    }

    TriggerClientEvent('ridego:client:tripAccepted', src, request)
    TriggerClientEvent('ridego:client:tripAccepted', request.passenger, request)
    TriggerClientEvent('ridego:client:requestClosed', -1, requestId)

    sendHint(src, ('Você aceitou a corrida #%s de %s.'):format(request.id, request.passengerName))
    sendHint(request.passenger, ('%s aceitou sua corrida #%s.'):format(request.driverName, request.id))
end)

RegisterNetEvent('ridego:server:updateStage', function(newStage)
    local src = source
    if newStage ~= 'onroute' and newStage ~= 'completed' then
        return
    end

    local active = ActiveTrips[src]
    if not active then
        return
    end

    local req = RideRequests[active.requestId]
    if not req then
        return
    end

    local other = active.other

    if newStage == 'onroute' then
        ActiveTrips[src].stage = 'onroute'
        if other and ActiveTrips[other] then
            ActiveTrips[other].stage = 'onroute'
        end

        TriggerClientEvent('ridego:client:tripStage', src, 'onroute', req)
        if other then
            TriggerClientEvent('ridego:client:tripStage', other, 'onroute', req)
        end
        return
    end

    TriggerClientEvent('ridego:client:endTrip', src)
    if other then
        TriggerClientEvent('ridego:client:endTrip', other)
    end

    sendHint(src, ('Corrida finalizada. Valor: $%s'):format(req.price))
    if other then
        sendHint(other, ('Corrida finalizada. Valor: $%s'):format(req.price))
    elseif req.requester then
        sendHint(req.requester, ('Corrida NPC #%s finalizada. Valor: $%s'):format(req.id, req.price))
    end

    ActiveTrips[src] = nil
    if other then
        ActiveTrips[other] = nil
    end
    clearRequest(active.requestId)
end)

RegisterNetEvent('ridego:server:cancelRide', function()
    local src = source

    local active = ActiveTrips[src]
    if active then
        local req = RideRequests[active.requestId]
        local other = active.other

        TriggerClientEvent('ridego:client:endTrip', src)
        if other then
            TriggerClientEvent('ridego:client:endTrip', other)
            sendHint(other, 'A corrida foi cancelada pelo outro jogador.')
            ActiveTrips[other] = nil
        elseif req and req.requester then
            sendHint(req.requester, 'A corrida NPC foi cancelada pelo motorista.')
        end

        ActiveTrips[src] = nil

        if req then
            clearRequest(req.id)
        end

        sendHint(src, 'Você cancelou a corrida.')
        return
    end

    for requestId, req in pairs(RideRequests) do
        if req.status == 'open' and (req.passenger == src or req.requester == src) then
            clearRequest(requestId)
            sendHint(src, 'Solicitação de corrida cancelada.')
            return
        end
    end

    sendHint(src, 'Nenhuma corrida ativa/pendente para cancelar.')
end)

RegisterCommand(Config.CommandName, function(source, args)
    local src = source
    local sub = (args[1] or ''):lower()

    if sub == 'online' then
        TriggerEvent('ridego:server:goOnline')
        return
    end

    if sub == 'offline' then
        TriggerEvent('ridego:server:goOffline')
        return
    end

    if sub == 'passenger' then
        TriggerEvent('ridego:server:setRole', 'passenger')
        return
    end

    if sub == 'accept' then
        TriggerEvent('ridego:server:acceptRide', args[2])
        return
    end

    if sub == 'cancel' then
        TriggerEvent('ridego:server:cancelRide')
        return
    end

    sendHint(src, ('Comandos: /%s online | offline | passenger | accept <id> | cancel'):format(Config.CommandName))
end, false)
