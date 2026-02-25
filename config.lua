Config = {}

-- Custo base de uma corrida
Config.BaseFare = 120

-- Valor cobrado por metro (distância em linha reta entre origem e destino)
Config.PricePerMeter = 0.35

-- Distância máxima para motorista enxergar solicitação
Config.DriverBroadcastRadius = 8000.0

-- Distância para considerar o passageiro embarcado
Config.PickupRange = 12.0

-- Distância para concluir corrida no destino
Config.DropoffRange = 18.0

-- Cooldown entre solicitações do mesmo passageiro (segundos)
Config.RequestCooldown = 30

-- Comando principal
Config.CommandName = 'ridego'

-- Quantia mínima de dinheiro para solicitar corrida
Config.MinimumBalance = 0

-- Modelo padrão de NPC para corridas NPC
Config.NPCModel = 'a_m_y_business_01'

-- Distância máxima para gerar o ped caso exista ajuste no futuro
Config.NPCSpawnRadius = 10.0

-- Exige CNH para ficar online como motorista
Config.RequireDriverLicense = true

-- Se true, valida CNH via ACE permission (ex.: add_ace identifier.license:xxx ridego.license allow)
Config.UseAceForLicense = false
Config.DriverLicenseAce = 'ridego.license'

-- Se UseAceForLicense for false, valida CNH pela lista de identificadores abaixo
Config.DriverLicenseIdentifiers = {
    -- ['license:SEU_IDENTIFIER_AQUI'] = true
}
