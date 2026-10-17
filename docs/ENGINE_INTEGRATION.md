# Integração com o daemon Elementum

## Arquitetura escolhida

```text
AddKo runtime
    │
    ├── executa main.lua
    │
    ▼
Luelement
    │
    ├── HTTP client ────────────────► 127.0.0.1:65220
    │                                  Elementum daemon
    │                                      │
    └── JSON-RPC server ◄──────────── 127.0.0.1:65221
                                           │
                                           ▼
                                      libtorrent
```

Não existe Kodi entre essas camadas.

## Por que a ponte RPC é necessária

A camada Python original do `plugin.video.elementum` fazia duas coisas principais:

1. iniciava/monitorava o binário Elementum;
2. abria um servidor JSON-RPC externo na porta `65221` para o daemon pedir ações de UI/player.

Portar apenas o `service.py` e ignorar `rpc.py` deixaria o daemon capaz de responder várias rotas HTTP, mas quebraria fluxos como `/play`, seleção de arquivos e acompanhamento do player.

O Luelement implementa essa segunda responsabilidade em `src/rpc_bridge.lua`.

## JSON-RPC usado pelo Elementum

O daemon envia mensagens JSON-RPC 2.0 sobre TCP, uma por linha:

```json
{"jsonrpc":"2.0","method":"Ping","params":[],"id":1}
```

O Luelement responde:

```json
{"jsonrpc":"2.0","id":1,"result":true}
```

A ponte implementa inicialmente os callbacks necessários para:

- ping/reset/refresh;
- notificações;
- teclado;
- confirmações e seleção;
- progresso de buffering;
- estado do player;
- posição/duração;
- seek;
- legendas;
- propriedades temporárias;
- plataforma e informações do plugin.

Recursos específicos do Kodi que não fazem sentido no AddKo retornam fallback neutro ou permanecem desativados pela configuração standalone.

## Como o daemon encontra a ponte Lua

O Luelement inicia o daemon com:

```text
-remoteHost=127.0.0.1
-remotePort=65221
```

Isso registra diretamente um host externo no Elementum. Não é necessário abrir/emular o JSON-RPC do Kodi na porta `9090` para o fluxo básico do Luelement.

## Configuração standalone

O daemon recebe obrigatoriamente:

```text
-configPath=<...>/elementum-config.json
```

Com `-configPath`, o Elementum carrega `ConfigBundle` de JSON/YAML em vez de buscar `AddonInfo` e settings no Kodi.

`src/standalone_config.lua` gera:

```text
Info
Platform
Settings
Language
SecondLanguage
Region
```

A biblioteca Kodi/STRM e sincronização de biblioteca ficam desativadas nesta fase.

## Inicialização do daemon

Argumentos atuais:

```text
-configPath=...
-addonPath=...
-profilePath=...
-tempPath=...
-torrentsPath=...
-libraryPath=...
-downloadsPath=...
-logPath=...
-localHost=127.0.0.1
-localPort=65220
-remoteHost=127.0.0.1
-remotePort=65221
-disableParentProcessWatcher
-disableLibrarySync
```

O plugin só considera a inicialização concluída depois que `GET /torrents/list` responde com sucesso.

### Por que não usamos `/status`

No Elementum, `/status` não é um endpoint de health-check. Essa rota monta as informações do daemon, chama `Dialog_Text` no host externo e só então retorna HTTP 200. Usá-la como probe faria verificações internas abrirem um diálogo no AddKo.

`/torrents/list` é apropriado para o probe porque, em server mode, devolve JSON silenciosamente e funciona mesmo com zero torrents ativos.

## Binário

Versão pinada para a primeira prova real:

```text
Elementum 0.1.114
elgatito/elementum-binaries
commit 2bfca0cd91cdf31e94eff121f997b78ff022224c
```

O Luelement procura primeiro um binário empacotado e depois um binário já armazenado no data dir. Se não encontrar, pode baixar apenas o executável da plataforma atual.

## Reprodução direta

Fluxo implementado em `ElementumClient:resolve_stream`:

```text
GET /play?uri=<magnet>&index=0
           │
           ├─ resolve metadata
           ├─ escolhe arquivo
           ├─ faz buffer inicial/final
           ▼
HTTP 302
Location: http://127.0.0.1:65220/files/<arquivo>
           │
           ▼
addko.player.play(url)
```

A chamada HTTP precisa usar `follow_redirects=false`. Caso contrário o cliente HTTP pode começar a consumir o stream no lugar do player.

Também existe reprodução de torrent já ativo via hash (`resume`).

## Seleção de arquivo

Para o primeiro teste podemos fornecer explicitamente `index=0`.

Quando o índice é omitido e há mais de um candidato, o daemon pode chamar `Dialog_Select` pela ponte RPC. O Luelement converte isso em `addko.ui.select`.

## Escopo intencional

Não estamos tentando fazer:

```text
AddKo -> emulador de Kodi -> addon Python -> Elementum
```

Nem:

```text
AddKo core -> BitTorrent/libtorrent
```

O desenho permanece:

```text
AddKo -> plugin Lua Luelement -> Elementum daemon -> libtorrent
```

## Critério para chamar 0.2 de funcional

O primeiro smoke test real precisa provar, no mesmo processo do AddKo:

1. `Plugin.start()` passa no preflight e abre a ponte RPC;
2. baixa/localiza `elementum.exe` no Windows x64;
3. gera a configuração standalone;
4. sobe o daemon sem Kodi instalado/rodando;
5. `/torrents/list` responde com JSON;
6. um magnet legal/de teste é aberto com `play_uri`;
7. `/play` devolve redirect `/files/...`;
8. o player do AddKo começa a reproduzir;
9. `Player_IsPlaying`/`Player_WatchTimes` funcionam pela ponte Lua;
10. seek funciona sobre o stream HTTP;
11. `Plugin.stop()` encerra apenas o daemon que o Luelement iniciou.

Até esse teste acontecer no runtime real, o projeto deve continuar marcado como `0.2.0-dev`.
