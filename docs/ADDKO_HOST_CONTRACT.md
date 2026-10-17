# Contrato mínimo do host AddKo

O Luelement não tenta emular Kodi. Ele depende somente de serviços genéricos que o runtime Lua do AddKo pode oferecer a qualquer plugin.

Toda dependência do host fica em `src/addko_host.lua`.

## Global

O runtime injeta uma tabela global:

```lua
_G.addko
```

## HTTP

```lua
addko.http.request({
    method = "GET",
    url = "http://127.0.0.1:65220/status",
    headers = {},
    body = nil,
    timeout_seconds = 15,
})
```

Retorno mínimo:

```lua
{
    status = 200,
    body = "{}",
}
```

## JSON

```lua
local value = addko.json.decode(text)
```

## Plataforma

```lua
addko.platform.os
addko.platform.arch
```

Valores previstos para `os`: `windows`, `linux`, `android`, `macos`.

## Caminhos

```lua
addko.paths.plugin("native/windows_amd64/elementum.exe")
addko.paths.data("elementum")
```

`plugin()` aponta para arquivos empacotados do plugin e `data()` para a área persistente do Luelement.

## Processo nativo

A próxima etapa do Luelement usará:

```lua
local handle = addko.process.spawn({
    path = executable,
    args = {},
    cwd = directory,
    env = {},
})

addko.process.stop(handle)
```

Isso é uma API genérica de processo do runtime, não uma permissão ou API especial de torrent.

## Temporização

```lua
addko.sleep(250)
```

Usado para aguardar o daemon subir sem implementar busy-wait.

## UI e player

A lógica atual retorna modelos Lua e ainda não exige uma API visual específica. Isso é intencional: primeiro estabilizamos comunicação e ciclo de vida do Elementum; depois conectamos os modelos à UI do Plugin v2 e ao player do AddKo.

## Regra arquitetural

O AddKo não precisa saber o que é Elementum, torrent, magnet ou libtorrent. Para o núcleo, Luelement é apenas um plugin Lua que usa HTTP, arquivos, processo nativo e player.
