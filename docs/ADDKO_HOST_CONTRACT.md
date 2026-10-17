# Contrato mínimo do host AddKo

O Luelement **não emula Kodi**. Ele usa somente serviços genéricos que o runtime Lua do AddKo pode oferecer a qualquer plugin.

Toda dependência do host fica concentrada em `src/addko_host.lua`.

## Global

O runtime injeta:

```lua
_G.addko
```

## HTTP

```lua
local response = addko.http.request({
    method = "GET",
    url = "http://127.0.0.1:65220/status",
    headers = {},
    body = nil,
    timeout_seconds = 15,
    follow_redirects = true,
})
```

Retorno mínimo:

```lua
{
    status = 200,
    body = "{}",
    headers = {},
    url = "http://127.0.0.1:65220/status",
}
```

Para reprodução, `follow_redirects = false` precisa preservar respostas 30x e o cabeçalho `Location`. Isso é necessário porque `/play` do Elementum faz buffering e então redireciona para `/files/...`.

Para binários grandes é recomendado:

```lua
addko.http.download({
    url = "https://.../elementum.exe",
    path = ".../elementum.exe",
    timeout_seconds = 180,
})
```

O fallback por `http.request(response_type="bytes")` existe, mas não é o caminho ideal para um executável de dezenas de MB.

## JSON

```lua
local value = addko.json.decode(text)
local text = addko.json.encode(value)
```

## Plataforma

```lua
addko.platform.os
addko.platform.arch
```

Valores aceitos são normalizados pelo plugin. Exemplos:

```text
windows / amd64
linux / x86_64
android / arm64
macos / x64
```

## Locale

Opcional:

```lua
addko.locale.language
addko.locale.region
addko.locale.second_language
```

Sem isso o Luelement usa `en-US` como fallback.

## Caminhos

```lua
addko.paths.plugin("native/windows_x64/elementum.exe")
addko.paths.data("elementum/0.1.114/profile")
```

`plugin()` aponta para arquivos empacotados e `data()` para a área persistente privada do plugin.

## Filesystem

Aceito pelo adapter:

```lua
addko.fs.exists(path)
addko.fs.mkdirp(path)
addko.fs.write_text(path, text)
addko.fs.write_bytes(path, bytes)
addko.fs.set_executable(path, true) -- não necessário no Windows
```

Também existem aliases tolerados para algumas operações (`mkdirs`, `create_directories`, `write`, `chmod`).

## Processo nativo

```lua
local handle = addko.process.spawn({
    path = executable,
    args = {},
    cwd = directory,
    env = {},
    hidden = true,
})

addko.process.stop(handle)
```

Isso é uma API genérica para processos nativos. O núcleo do AddKo não precisa conhecer Elementum, torrent ou libtorrent.

## TCP local

O daemon Elementum usa JSON-RPC 2.0 sobre TCP para conversar com a antiga camada Python. O Luelement substitui essa camada com Lua em `127.0.0.1:65221`.

Contrato esperado:

```lua
local server = addko.net.tcp.listen({
    host = "127.0.0.1",
    port = 65221,
    framing = "lines",
    on_message = function(line)
        return response_line
    end,
})
```

Também pode ser exposto como `listen_lines`.

Cada requisição e resposta JSON-RPC é um documento JSON terminado por quebra de linha. O valor retornado por `on_message` deve ser enviado ao mesmo cliente como uma linha completa.

Para fechar:

```lua
addko.net.tcp.close(server)
```

## Temporização

```lua
addko.sleep(250)
```

O plugin usa isso para aguardar o daemon subir/encerrar sem busy-wait.

## UI

Estas funções são opcionais; o adapter possui fallbacks simples quando possível:

```lua
addko.ui.refresh()
addko.ui.navigate(route)
addko.ui.notify({ title=..., message=... })
addko.ui.input({...})
addko.ui.alert({...})
addko.ui.confirm({...})
addko.ui.select({...})
addko.ui.pick_file({...})

addko.ui.progress_create({...})
addko.ui.progress_update(handle, {...})
addko.ui.progress_is_cancelled(handle)
addko.ui.progress_close(handle)
```

Essas funções atendem aos callbacks que o daemon usa durante seleção de arquivo, buffering e notificações.

## Player

Para reprodução real:

```lua
addko.player.play(url)
addko.player.current_url()
addko.player.is_playing()
addko.player.is_paused()
addko.player.times()       -- { position=..., duration=... }
addko.player.seek(seconds)
addko.player.subtitles()
addko.player.set_subtitles(urls)
```

A URL entregue ao player é servida pelo próprio Elementum em `http://127.0.0.1:65220/files/...`.

## O que NÃO existe

Não existe contrato AddKo como:

```text
addko.torrent
addko.elementum
addko.dht
addko.magnet
```

Essas responsabilidades ficam inteiramente dentro do Luelement/Elementum. O runtime fornece apenas capacidades genéricas de app/plugin.
