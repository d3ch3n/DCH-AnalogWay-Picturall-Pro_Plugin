# DCH NovaStar KC40 Plugin

Plugin Q-SYS para controle básico do NovaStar KC40 / família COEX via HTTP API.

## Recursos

- Aplicar presets do KC40
- Alternar modo de display entre `Normal` e `Black`
- Configuração de IP, porta HTTP, `screenID`, `canvasIDs` e quantidade de presets
- Status de conexão e resposta HTTP/API
- Debug `None`, `Tx/Rx`, `Function Calls`, `All`

## Protocolo

A API COEX da NovaStar usa HTTP. Em modo online, o controlador usa o IP real do equipamento e porta `8001`.

Endpoints usados:

- `POST /api/v1/preset/current/update`
- `PUT /api/v1/device/displaymode`

O endpoint de preset usa:

```json
{"sequenceNumber":0,"screenID":"string"}
```

O endpoint de modo usa:

```json
{"value":0,"canvasIDs":[1]}
```

A documentação pública mostra o formato do campo `value`, mas não publica a tabela completa de valores. Por isso, os valores de modo são propriedades configuráveis:

- `Normal Mode Value`, padrão `0`
- `Black Mode Value`, padrão `1`

Valide esses valores no KC40/VMP do projeto antes do uso em produção.

## Observação

Este diretório contém apenas os fontes do plugin. O `.qplug` deve ser gerado manualmente pelo usuário.
