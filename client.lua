local pendingRequests = {}
local activeTrip = nil
local monitorThread = nil
local npcPed = nil
local uiOpen = false

local function notify(msg)
    TriggerEvent('chat:addMessage', {
        color = { 0, 200, 255 },
        args = { '[RideGo]', msg }
    })
end

local function getVecFromPlayer()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function drawHelp(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function stopMonitor()
    monitorThread = nil
end

local function cleanupNpc()
    if npcPed and DoesEntityExist(npcPed) then
        DeleteEntity(npcPed)
    end
    npcPed = nil
end

local function toRequestList()
    local list = {}
    for _, request in pairs(pendingRequests) do
        list[#list + 1] = {
            id = request.id,
            type = request.type,
            passengerName = request.passengerName,
            price = request.price
        }
    end

    table.sort(list, function(a, b)
        return a.id < b.id
    end)

    return list
end

local function updateUiRequests()
    SendNUIMessage({
        action = 'ridego:updateRequests',
        requests = toRequestList()
    })
end

local function openUi()
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'ridego:open',
        requests = toRequestList()
    })
end

local function closeUi()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'ridego:close' })
end

local function loadModel(modelHash)
    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        return false
    end

    RequestModel(modelHash)
    local timeoutAt = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) do
        Wait(50)
        if GetGameTimer() > timeoutAt then
            return false
        end
    end

    return true
end

local function spawnNpcForTrip()
    if not activeTrip or not activeTrip.isNpc then
        return false
    end

    if npcPed and DoesEntityExist(npcPed) then
        return true
    end

    local modelHash = joaat(activeTrip.npcModel or Config.NPCModel)
    if not loadModel(modelHash) then
        notify('Falha ao carregar modelo do NPC.')
        return false
    end

    npcPed = CreatePed(4, modelHash, activeTrip.origin.x + 0.0, activeTrip.origin.y + 0.0, activeTrip.origin.z + 0.0, 0.0, true, true)

    if not npcPed or npcPed == 0 then
        notify('Falha ao gerar NPC.')
        return false
    end

    SetEntityAsMissionEntity(npcPed, true, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)
    SetPedCanRagdoll(npcPed, false)

    SetModelAsNoLongerNeeded(modelHash)
    return true
end

local function getVehicleSeatForNpc(vehicle)
    local seatCount = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
    for seat = 0, seatCount - 2 do
        if IsVehicleSeatFree(vehicle, seat) then
            return seat
        end
    end
    return 0
end

local function requestRide(requestType)
    local ped = PlayerPedId()

    local waypoint = GetFirstBlipInfoId(8)
    if not DoesBlipExist(waypoint) then
        notify('Marque um destino no mapa e tente novamente.')
        return
    end

    if requestType == 'player' and IsPedInAnyVehicle(ped, false) then
        notify('Saia do veículo para solicitar corrida de player.')
        return
    end

    local destination = GetBlipInfoIdCoord(waypoint)
    local origin = getVecFromPlayer()

    TriggerServerEvent('ridego:server:requestRide', origin, {
        x = destination.x,
        y = destination.y,
        z = destination.z
    }, requestType)
end

local function startTripMonitor()
    if monitorThread then
        return
    end

    monitorThread = CreateThread(function()
        while activeTrip do
            Wait(0)

            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local stage = activeTrip.stage

            if stage == 'pickup' then
                local pickup = vector3(activeTrip.origin.x, activeTrip.origin.y, activeTrip.origin.z)
                local dist = #(pos - pickup)

                DrawMarker(1, pickup.x, pickup.y, pickup.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 2.2, 1.2, 0, 200, 255, 160, false, false, 2, false, nil, nil, false)

                if activeTrip.isDriver then
                    if activeTrip.isNpc then
                        drawHelp(('Chegue no marcador e buzine para chamar o NPC. Distância: %.1fm'):format(dist))

                        if dist <= Config.PickupRange and IsPedInAnyVehicle(ped, false) and IsControlJustPressed(0, 86) then
                            if spawnNpcForTrip() then
                                local vehicle = GetVehiclePedIsIn(ped, false)
                                local seat = getVehicleSeatForNpc(vehicle)
                                TaskEnterVehicle(npcPed, vehicle, -1, seat, 1.0, 1, 0)
                                activeTrip.npcCalled = true
                                notify('NPC chamado. Aguardando entrar no veículo...')
                            end
                        end

                        if activeTrip.npcCalled and npcPed and DoesEntityExist(npcPed) then
                            local vehicle = GetVehiclePedIsIn(ped, false)
                            if IsPedInVehicle(npcPed, vehicle, false) then
                                notify('NPC entrou no veículo. Corrida iniciada!')
                                TriggerServerEvent('ridego:server:updateStage', 'onroute')
                            end
                        end
                    else
                        drawHelp(('Vá até o passageiro. Distância: %.1fm'):format(dist))
                        if dist <= Config.PickupRange then
                            notify('Passageiro embarcado. Indo para destino...')
                            TriggerServerEvent('ridego:server:updateStage', 'onroute')
                        end
                    end
                else
                    drawHelp(('Aguarde o motorista. Distância: %.1fm'):format(dist))
                end
            elseif stage == 'onroute' then
                local destination = vector3(activeTrip.destination.x, activeTrip.destination.y, activeTrip.destination.z)
                local dist = #(pos - destination)

                DrawMarker(1, destination.x, destination.y, destination.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 2.2, 1.2, 50, 255, 50, 160, false, false, 2, false, nil, nil, false)

                if activeTrip.isDriver then
                    if activeTrip.isNpc then
                        drawHelp(('Chegue ao destino e buzine para finalizar a corrida. Distância: %.1fm'):format(dist))

                        if dist <= Config.DropoffRange and IsPedInAnyVehicle(ped, false) and IsControlJustPressed(0, 86) and not activeTrip.dropoffHornUsed then
                            activeTrip.dropoffHornUsed = true

                            if npcPed and DoesEntityExist(npcPed) then
                                local vehicle = GetVehiclePedIsIn(ped, false)
                                if IsPedInVehicle(npcPed, vehicle, false) then
                                    TaskLeaveVehicle(npcPed, vehicle, 0)
                                    notify('NPC está descendo do veículo...')
                                end
                            end
                        end

                        if activeTrip.dropoffHornUsed and npcPed and DoesEntityExist(npcPed) then
                            local vehicle = GetVehiclePedIsIn(ped, false)
                            if not IsPedInVehicle(npcPed, vehicle, false) and not activeTrip.finishSent then
                                activeTrip.finishSent = true
                                TriggerServerEvent('ridego:server:updateStage', 'completed')
                                Wait(1200)
                            end
                        end
                    else
                        drawHelp(('Leve o passageiro ao destino. Distância: %.1fm'):format(dist))
                        if dist <= Config.DropoffRange then
                            TriggerServerEvent('ridego:server:updateStage', 'completed')
                            Wait(1200)
                        end
                    end
                else
                    drawHelp(('A caminho do destino. Distância restante: %.1fm'):format(dist))
                end
            end
        end

        stopMonitor()
    end)
end

RegisterNUICallback('closeUi', function(_, cb)
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('goOnline', function(_, cb)
    TriggerServerEvent('ridego:server:goOnline')
    cb({ ok = true })
end)

RegisterNUICallback('goOffline', function(_, cb)
    TriggerServerEvent('ridego:server:goOffline')
    cb({ ok = true })
end)

RegisterNUICallback('setPassenger', function(_, cb)
    TriggerServerEvent('ridego:server:setRole', 'passenger')
    cb({ ok = true })
end)

RegisterNUICallback('requestPlayer', function(_, cb)
    requestRide('player')
    cb({ ok = true })
end)

RegisterNUICallback('requestNpc', function(_, cb)
    requestRide('npc')
    cb({ ok = true })
end)

RegisterNUICallback('cancelRide', function(_, cb)
    TriggerServerEvent('ridego:server:cancelRide')
    cleanupNpc()
    cb({ ok = true })
end)

RegisterNUICallback('acceptRide', function(data, cb)
    local requestId = tonumber(data and data.requestId)
    if requestId and requestId > 0 then
        TriggerServerEvent('ridego:server:acceptRide', requestId)
    else
        notify('ID da corrida inválido para aceitar.')
    end
    cb({ ok = true })
end)

RegisterNetEvent('ridego:client:newRequest', function(request)
    pendingRequests[request.id] = request
    updateUiRequests()

    if request.type == 'npc' then
        notify(('Nova corrida NPC #%s | solicitante: %s | preço: $%s'):format(request.id, request.requesterName, request.price))
        return
    end

    notify(('Nova corrida #%s | %s | preço: $%s'):format(request.id, request.passengerName, request.price))
end)

RegisterNetEvent('ridego:client:requestClosed', function(requestId)
    pendingRequests[requestId] = nil
    updateUiRequests()
end)

RegisterNetEvent('ridego:client:tripAccepted', function(request)
    local playerServerId = GetPlayerServerId(PlayerId())
    local isDriver = request.driver == playerServerId

    activeTrip = {
        id = request.id,
        origin = request.origin,
        destination = request.destination,
        price = request.price,
        stage = 'pickup',
        isDriver = isDriver,
        isNpc = request.type == 'npc',
        npcModel = request.npcModel,
        npcCalled = false,
        dropoffHornUsed = false,
        finishSent = false
    }

    if isDriver then
        SetNewWaypoint(request.origin.x + 0.0, request.origin.y + 0.0)
        if activeTrip.isNpc then
            notify(('Corrida NPC #%s aceita. Vá ao local, buzine no marcador e pegue o NPC.'):format(request.id))
        else
            notify(('Corrida #%s aceita. Busque o passageiro e siga para destino.'):format(request.id))
        end
    else
        notify(('Motorista %s está a caminho. Aguarde no local.'):format(request.driverName))
    end

    startTripMonitor()
end)

RegisterNetEvent('ridego:client:tripStage', function(stage, request)
    if not activeTrip then
        return
    end

    activeTrip.stage = stage
    if stage == 'onroute' then
        SetNewWaypoint(request.destination.x + 0.0, request.destination.y + 0.0)
        notify('Corrida iniciada. Rota para destino atualizada.')
    end
end)

RegisterNetEvent('ridego:client:endTrip', function()
    if activeTrip then
        notify(('Corrida #%s encerrada.'):format(activeTrip.id))
    end

    cleanupNpc()
    activeTrip = nil
end)

RegisterCommand('ridegoui', function()
    if uiOpen then
        closeUi()
    else
        openUi()
    end
end, false)
RegisterKeyMapping('ridegoui', 'Abrir app RideGo', 'keyboard', 'F6')

RegisterCommand(Config.CommandName, function(_, args)
    local sub = (args[1] or ''):lower()

    if sub == '' or sub == 'ui' then
        if uiOpen then
            closeUi()
        else
            openUi()
        end
        return
    end

    if sub == 'request' then
        requestRide('player')
        return
    end

    if sub == 'npcrequest' then
        requestRide('npc')
        return
    end

    if sub == 'cancel' then
        TriggerServerEvent('ridego:server:cancelRide')
        cleanupNpc()
        return
    end

    if sub == 'online' or sub == 'offline' or sub == 'passenger' or sub == 'accept' then
        return
    end

    notify(('UI: /%s ui (ou F6)'):format(Config.CommandName))
    notify(('Comandos rápidos: /%s request | /%s npcrequest | /%s cancel'):format(Config.CommandName, Config.CommandName, Config.CommandName))
end, false)
