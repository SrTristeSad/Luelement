# Integração com o engine Elementum

## Arquitetura escolhida

```text
AddKo runtime
    │
    ├── executa Luelement/main.lua
    │
    ▼
Luelement
    │
    ├── HTTP client ────────────────► 127.0.0.1:65220
    │                                  Elementum
    │                                      │
    └── JSON-RPC server ◄──────────── 127.0.0.1:65221
                                           │
                                           ▼
                                      libtorrent
```

Não existe Kodi entre essas camadas.

## Duas formas de hospedar o engine

### Standalone

Em hosts que expõem processos nativos genéricos:

```text
Luelement Lua
   ↓ process.spawn
Elementum executable
```

`src/daemon_manager.lua` prepara configuração, caminhos, binário, processo e health-check.

### Android com módulo nativo já empacotado

O AddKo Android assina um módulo nativo aprovado na própria variante completa do APK. O plugin Lua chama `addko.engines.start("elementum")`, sem APK auxiliar, downloads de binários executáveis nem acesso direto a JNI. A permissão genérica `native_engine` e o ID `elementum` devem constar no manifesto.

O núcleo não implementa torrent nem Kodi; o registro nativo só permite módulos previamente incorporados ao build. O serviço corre em processo Android separado.

## Por que a ponte RPC é necessária

A camada Python original do `plugin.video.elementum` fazia duas responsabilidades relevantes:

1. iniciava/monitorava o engine;
2. abria um servidor JSON-RPC externo na porta `65221` para o daemon pedir ações de UI/player.

O Luelement substitui a segunda responsabilidade por `src/rpc_bridge.lua`.

A ponte cobre os métodos usados pela camada original para:

- ping/reset/refresh;
- notificações;
- teclado;
- confirmações e seleção;
- progresso;
- estado do player;
- posição/duração;
- seek;
- legendas;
- propriedades temporárias;
- plataforma e informações do plugin.

Métodos específicos de Kodi sem equivalente útil recebem fallback neutro quando seguro.

## Framing JSON-RPC

O cliente Go do Elementum usa `json.Encoder.Encode` e `json.Decoder.Decode` sobre a conexão TCP. Portanto documentos JSON separados por newline/whitespace são compatíveis.

Exemplo:

```json
{"jsonrpc":"2.0","method":"Ping","params":[],"id":1}
```

Resposta:

```json
{"jsonrpc":"2.0","id":1,"result":true}
```

O host AddKo permite ao plugin ouvir apenas em loopback.

## Como o engine encontra a ponte Lua

Argumentos:

```text
-remoteHost=127.0.0.1
-remotePort=65221
```

Não é necessário abrir/emular o JSON-RPC do Kodi na porta `9090`.

## Configuração standalone

O engine recebe:

```text
-configPath=<...>/elementum-config.json
```

Com `-configPath`, o Elementum carrega `ConfigBundle` de JSON/YAML em vez de buscar as settings no Kodi.

`src/standalone_config.lua` e `EngineConfig.kt` geram:

```text
Info
Platform
Settings
Language
SecondLanguage
Region
```

Biblioteca Kodi/STRM e sincronização de biblioteca ficam desativadas.

## Argumentos atuais

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

A inicialização só é considerada pronta depois que `GET /torrents/list` responde.

### Por que não `/status`

`/status` abre um diálogo de status pelo host RPC antes de responder. Usá-lo como probe faria o health-check interno abrir UI.

`/torrents/list` devolve JSON silenciosamente e funciona mesmo com zero torrents.

## Engine pinado

```text
Elementum 0.1.114
elgatito/elementum-binaries
commit 2bfca0cd91cdf31e94eff121f997b78ff022224c
```

### Android

O AddKo inclui a build compartilhada no APK completo:

```text
android_arm64/elementum.so
android_arm64/libc++_shared.so
```

O Makefile oficial do Elementum copia `libc++_shared.so` para o build Android; `libgnustl_shared.so` aparece apenas como código antigo comentado. O Gradle do AddKo confere tamanho e Git blob SHA-1 antes de empacotar ambas as bibliotecas.

O JNI chama a função exportada oficial:

```c
startWithLogAndArgs(char *logPath, char *args)
```

A implementação shared do Elementum reseta o estado de saída a cada start, executa `main()` e fecha os pipes ao terminar, permitindo reinicialização do engine dentro do processo dedicado do AddKo.

## Android 15 e foreground service

O AddKo mira uma API Android compatível e usa foreground service `dataSync`. Android 15 limita esse tipo, quando em segundo plano, a seis horas acumuladas por janela de 24 horas.

`NativeEngineService.onTimeout()` encerra `/shutdown` e chama `stopSelf()` rapidamente para evitar `RemoteServiceException` quando o limite do sistema é alcançado.

Isso é uma limitação do ciclo de vida Android, não do protocolo Luelement/Elementum.

## Reprodução direta

Fluxo de `ElementumClient:resolve_stream`:

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
           │
           ▼
AddKo abre a superfície de vídeo
```

A chamada HTTP usa `follow_redirects=false`; caso contrário o cliente HTTP consumiria o stream no lugar do player.

Também existe reprodução de torrent ativo via hash (`resume`).

## Seleção de arquivo

Quando o índice é omitido e há mais de um candidato, o daemon pode chamar `Dialog_Select` pela ponte RPC. O Luelement converte isso em `addko.ui.select`, que já possui diálogo Flutter no AddKo.

## UI

O Luelement já retorna documentos declarativos reais do AddKo:

- home/estado do engine;
- torrents;
- formulário de magnet;
- diagnóstico;
- catálogo inicial de filmes.

A árvore da lista de torrents é limitada para permanecer abaixo do limite de complexidade de UI do host.

## Escopo intencional

Não estamos fazendo:

```text
AddKo -> emulador de Kodi -> addon Python -> Elementum
```

nem:

```text
AddKo core -> BitTorrent/libtorrent
```

O desenho continua:

```text
AddKo -> Luelement Lua -> Elementum -> libtorrent
```

## Critério para chamar 0.2 de funcional

O smoke test real precisa provar:

1. `.addko` instala e abre no AddKo;
2. `Plugin.start()` abre a ponte RPC;
3. o engine standalone ou módulo assinado do AddKo inicia sem Kodi;
4. `/torrents/list` responde;
5. a UI do Luelement aparece;
6. um magnet legal/de teste é adicionado;
7. seleção de arquivo funciona quando necessária;
8. `/play` devolve redirect `/files/...`;
9. o player do AddKo reproduz;
10. `Player_IsPlaying` e `Player_WatchTimes` funcionam pela ponte;
11. seek funciona no stream HTTP;
12. stop encerra somente o engine controlado pelo Luelement.

Até esse teste acontecer em ambiente real, o projeto permanece `0.2.0-dev`.
