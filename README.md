# DCH Analog Way Picturall Pro Plugin

Plugin Q-SYS para controle inicial do Analog Way Picturall Pro, direcionado ao fluxo de Cue Stacks / Playbacks usado no Picturall Server 3.5.x.

## Recursos

- Conexão TCP/IP com porta padrão `11000`
- Botões de preset/cue stack configuráveis
- Botões configuráveis de `Playback Go` para playbacks 1 a 8
- Nome, playback, cue stack e comando textual por preset
- Status de conexão, reconexão, timeout e fila de comandos
- Logging/debug no padrão do projeto (`None`, `Tx/Rx`, `Function Calls`, `All`)
- Parsing conservador de feedback textual recebido para playback, cue stack, cue, estado e versão quando essas informações forem publicadas pelo servidor

## Protocolo

A documentação pública da Analog Way descreve o Picturall como controlável por Ethernet TCP/IP com protocolo externo textual. A documentação do módulo Bitfocus Companion para Analog Way Picturall confirma a porta TCP padrão `11000` e orienta obter os comandos exatos pelo `Commander Log` do Picturall Commander ou pelo botão `Learn` do Companion.

Por isso, este plugin não hardcodeia comandos TCP não documentados para presets. Cada preset envia o texto configurado no controle `PresetXCommand`, e cada botão de playback envia `PlaybackXGoCommand`, acrescido do `Line Ending` configurado nas propriedades.

Os comandos de `Playback Go` são inicializados por padrão como:

```text
Playback1GoCommand = set stack1 control command=1
Playback2GoCommand = set stack2 control command=1
Playback3GoCommand = set stack3 control command=1
...
```

Fluxo recomendado:

1. No Picturall Commander, habilite logging de comandos.
2. Execute manualmente a ação desejada, como selecionar um Cue Stack em um Playback e executar Go.
3. Copie a parte do comando após `-->`.
4. Cole no `PresetXCommand` correspondente no Q-SYS.

## Build

O projeto mantém a estrutura do Basic Plugin Framework com `plugin.lua` e includes Lua separados.

Artefato expandido:

```text
DCH-AnalogWay-Picturall-Pro_Plugin.qplug
```
