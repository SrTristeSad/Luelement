# Contrato genérico do host AddKo usado pelo Luelement

O Luelement **não emula Kodi** e o AddKo **não possui API especial de torrent**. O plugin usa somente capacidades genéricas que também podem servir a outros mini-apps Lua.

Toda adaptação fica concentrada em `src/addko_host.lua`.

## Estado atual no AddKo

O `main` do AddKo já possui a base necessária para o Luelement:

- HTTP/HTTPS com controle de redirects;
- JSON;
- paths privados do plugin;
- filesystem sandboxed;
- servidor TCP local por linhas;
- temporização;
- player HTTP;
- callbacks genéricos de UI;
- abertura segura de URI externo (`system.open_uri`) no Android.

No Android, `process.spawn` permanece **desativado por design**. O Luelement usa o companion **Luelement Engine** para hospedar a biblioteca nativa Elementum. Em plataformas onde processos nativos forem suportados, o mesmo plugin pode usar `daemon_manager.lua`.

## Global

O runtime injeta:

```lua
_G.addko
```

## HTTP

```lua
local response = addko.http.request({
    method = "GET",
    url = "http://127.0.0.1:65220/torrents/list",
    headers = {},
    body = nil,
    timeout_seconds = 15,
    follow_redirects = true,
})
```

Retorno:

```lua
{
    status = 200,
    body = "[]",
    headers = {},
    url = "http://127.0.0.1:65220/torrents/list",
}
```

Para reprodução, `follow_redirects = false` preserva a resposta 30x e o cabeçalho `Location`. `/play` faz o buffering e redireciona para `/files/...`.

Para downloads:

```lua
addko.http.download({
    url = "https://...",
    path = "...",
    timeout_seconds = 180,
})
```

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

Exemplos aceitos pelo normalizador do Luelement:

```text
windows / amd64
linux / x86_64
android / arm64
macos / x64
```

## Locale

```lua
addko.locale.language
addko.locale.region
addko.locale.second_language
```

O plugin possui fallback quando algum desses valores não estiver disponível.

## Caminhos

```lua
addko.paths.plugin("src/ui.lua")
addko.paths.data("elementum/profile")
```

`plugin()` aponta para o conteúdo instalado do `.addko`; `data()` aponta para a área persistente privada do plugin.

## Filesystem

```lua
addko.fs.exists(path)
addko.fs.mkdirp(path)
addko.fs.write_text(path, text)
addko.fs.write_bytes(path, bytes)
```

Em hosts que permitem executáveis graváveis também podem existir:

```lua
addko.fs.set_executable(path, true)
addko.fs.chmod(path, "755")
```

No Android do AddKo essas operações de executável são deliberadamente indisponíveis.

## Processo nativo

Contrato usado pelo launcher standalone quando o host oferecer a capacidade:

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

No Android atual:

```text
capabilities.process = false
```

Por isso o plugin não tenta baixar e executar um ELF no diretório de dados.

## Abertura de URI externo

O AddKo expõe no Android:

```lua
addko.system.open_uri("luelement-engine://start")
```

É uma capacidade genérica. O core não conhece Luelement nem Elementum.

O host rejeita esquemas locais/perigosos como:

```text
file:
content:
data:
javascript:
intent:
```

O Luelement usa:

```text
luelement-engine://start
luelement-engine://stop
```

para controlar o companion Android.

## TCP local

A ponte JSON-RPC Lua escuta em `127.0.0.1:65221`:

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

Cada mensagem JSON-RPC é uma linha. Para fechar:

```lua
addko.net.tcp.close(server)
```

O host restringe o servidor TCP do plugin ao loopback.

## Temporização

```lua
addko.sleep(250)
```

Usado para polling de inicialização/encerramento sem busy-wait.

## UI

O AddKo possui uma UI declarativa para páginas do mini-app e também callbacks genéricos usados pelo RPC do Elementum.

Callbacks relevantes:

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

`input`, `alert`, `confirm` e `select` já são conectados a diálogos Flutter reais. O file picker genérico ainda retorna cancelamento nesta etapa; progresso já possui contrato funcional básico, mas ainda pode ganhar uma apresentação visual mais sofisticada.

O Luelement exige os callbacks de diálogo no preflight porque o Elementum pode pedir seleção de arquivo durante `/play`.

## UI declarativa

`Plugin.start()` e ações do Luelement agora retornam documentos do próprio AddKo, por exemplo:

```lua
return {
    type = "page",
    title = "Luelement",
    body = {
        type = "column",
        children = {
            {
                type = "button",
                label = "Torrents",
                action = "route",
                args = { "torrents" },
            },
        },
    },
}
```

O AddKo atual suporta componentes como texto, botões, cards, row/column, grid/list, imagens e campos de formulário.

## Player

```lua
addko.player.play(url)
addko.player.current_url()
addko.player.is_playing()
addko.player.is_paused()
addko.player.times()
addko.player.seek(seconds)
addko.player.subtitles()
addko.player.set_subtitles(urls)
```

A URL entregue ao player é normalmente:

```text
http://127.0.0.1:65220/files/...
```

Ao iniciar mídia por um plugin, o AddKo abre uma superfície de reprodução genérica em tela própria. O Android permite cleartext somente para `localhost` e `127.0.0.1`, portanto não foi necessário liberar HTTP globalmente.

## Capacidades verificadas pelo Luelement

No modo externo/companion:

```text
http
tcp_server
player
sleep
ui
```

No launcher standalone, adicionalmente:

```text
filesystem
process
```

No Android, o companion também verifica:

```text
open_uri
```

## O que NÃO existe

Não existe:

```text
addko.torrent
addko.elementum
addko.dht
addko.magnet
```

Torrent, DHT, magnet, peers e buffering continuam inteiramente dentro do Elementum/Luelement. O AddKo fornece somente capacidades genéricas de uma plataforma de mini-apps.
