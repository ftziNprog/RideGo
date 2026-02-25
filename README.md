# RideGo (FiveM)

Sistema em **Lua** para FiveM que simula um aplicativo de corridas estilo Uber para celular in-game, agora com **UI clicável (NUI)**.

## Funcionalidades

- Corrida entre **players** (passageiro chama e motorista aceita).
- Corrida com **NPC** (motorista aceita, busca NPC no marker, buzina para chamar, NPC entra no carro e inicia a viagem).
- Controle de trabalho do motorista pela UI:
  - **Ficar Online** para receber chamadas.
  - **Ficar Offline** para parar de receber chamadas.
- Validação de **CNH** ao ficar online como motorista.
- Fluxo automático de corrida:
  - Buscar passageiro/NPC.
  - Iniciar rota para destino.
  - Finalizar corrida NPC com buzina no destino + desembarque do NPC.
- Cancelamento de corridas pendentes/ativas.

## Instalação

1. Coloque a pasta `RideGo` em `resources/[local]/RideGo`.
2. No `server.cfg`, adicione:

```cfg
ensure RideGo
```

## Uso (Interface)

- Abra o app com:
  - `F6` (atalho padrão), ou
  - `/<comando> ui`, ou
  - `/<comando>`
- Na UI, use os botões para:
  - Ficar Online / Ficar Offline.
  - Entrar como Passageiro.
  - Solicitar corrida Player ou NPC.
  - Aceitar corrida por ID.
  - Cancelar corrida.

> Se o jogador não tiver CNH, ao tentar ficar online aparecerá: **"Você precisa de uma CNH"**.

## Fluxo da corrida NPC

1. Solicitante abre a UI e usa **Chamar Corrida (NPC)** com waypoint marcado.
2. Motorista fica online e aceita a corrida na UI por ID.
3. O mapa marca o ponto de coleta do NPC.
4. Ao chegar no marker, o motorista **buzina**.
5. O NPC vai até o veículo e entra.
6. A corrida inicia e o mapa marca o destino final.
7. Ao chegar no destino, o motorista buzina novamente para finalizar.
8. O NPC desce do veículo e a corrida é encerrada.

> O comando padrão é `ridego` (editável em `config.lua`).

## Configuração

Você pode ajustar em `config.lua`:

- Preço base e valor por metro.
- Distâncias de pickup/dropoff.
- Cooldown de solicitações.
- Nome do comando.
- Modelo do NPC (`Config.NPCModel`).
- Exigência de CNH (`Config.RequireDriverLicense`).
- Método de validação da CNH:
  - ACE permission (`Config.UseAceForLicense = true`) com `Config.DriverLicenseAce`.
  - Lista de identificadores (`Config.DriverLicenseIdentifiers`).
