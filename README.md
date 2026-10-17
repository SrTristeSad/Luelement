# Luelement

> **Distribuição do produto:** Luelement é um plugin `.addko`, não um APK independente. A inicialização automática do antigo companion Android foi desativada. O pacote Lua instala no AddKo, mas **o motor nativo ainda não roda no AddKo Android atual**, que precisa de suporte genérico a módulos nativos de plugins. Não instale APK auxiliar como requisito do Luelement; o código `android-engine/` é um experimento legado, não a solução de distribuição pretendida.


Luelement é um plugin Lua experimental para o AddKo que usa o **Elementum** como motor nativo de torrent/streaming, sem transformar o AddKo em Kodi e sem portar o ecossistema Python do Kodi.

```text
AddKo
  ↓
Luelement (Lua)
  ├─ UI declarativa do AddKo
  ├─ HTTP → Elementum :65220
  └─ RPC Lua :65221 ← Elementum
                         ↓
                  libtorrent / BitTorrent
```

No Android, o motor nativo fica em um companion separado:

```text
AddKo + Luelement.addko
        │
        └─ system.open_uri("luelement-engine://start")
                         ↓
                Luelement Engine APK
                         ↓
                 Elementum + libtorrent
```

O núcleo do AddKo continua genérico. Não existe `addko.torrent`, `addko.elementum` ou qualquer permissão especial para o Luelement.

## Estado atual — 0.2.0-dev

Já implementado no `main`:

- `manifest.json` compatível com o formato `.addko` atual;
- frontend Lua modular usando o `require` seguro do AddKo;
- primeira UI real do Luelement usando o renderer declarativo do AddKo;
- tela inicial com estado do motor;
- tela de torrents com progresso, status, peers, seeds e velocidades;
- formulário para adicionar magnet/URL de torrent;
- ações de pausa, retomada, recheck, remoção e reprodução;
- cliente Lua da API HTTP do Elementum;
- health-check silencioso via `/torrents/list`;
- resolução de reprodução por `/play`, capturando o redirect `/files/...`;
- ponte JSON-RPC 2.0 em Lua na porta `65221`;
- confirmação, seleção, teclado e alertas encaminhados para UI Flutter genérica do AddKo;
- player HTTP do AddKo com tela própria de reprodução;
- launcher standalone do daemon para hosts que permitam processos nativos;
- geração de `ConfigBundle` standalone sem depender das settings do Kodi;
- detecção de plataforma/arquitetura;
- download/cache do binário Elementum em hosts compatíveis;
- companion Android ARM64 (`Luelement Engine`);
- auto-start transparente do companion via deep link genérico;
- foreground service Android para manter o Elementum ativo;
- bibliotecas Android do Elementum pinadas por commit, tamanho exato e Git blob SHA-1;
- gerador Windows do pacote `.addko`;
- build Windows do companion Android com Gradle pinado;
- testes Lua isolados de URL, plataforma, preflight, RPC, configuração, cliente HTTP, daemon, companion e UI;
- testes do host AddKo para filesystem, permissões, `system.open_uri` e UI genérica.

## O que ainda falta validar

O fluxo está implementado, mas **ainda não foi executado de ponta a ponta neste ambiente** porque aqui não há Flutter/Dart/Lua/Gradle disponíveis para rodar o AddKo, a suíte Lua e o build Android.

O próximo marco real é um teste em Windows/aparelho Android provando:

```text
AddKo
  ↓
instala Luelement.addko
  ↓
abre Luelement
  ↓
engine sobe
  ↓
magnet é adicionado
  ↓
Elementum faz buffering
  ↓
302 /files/...
  ↓
player do AddKo reproduz
```

Enquanto esse smoke test não passar em ambiente real, a versão continua `0.2.0-dev`.

## Estrutura

```text
Luelement/
├── BUILD_ADDKO.bat
├── BUILD_ENGINE_ANDROID.bat
├── manifest.json
├── main.lua
├── src/
│   ├── addko_host.lua
│   ├── app.lua
│   ├── companion.lua
│   ├── config.lua
│   ├── daemon_manager.lua
│   ├── elementum_client.lua
│   ├── platform.lua
│   ├── preflight.lua
│   ├── rpc_bridge.lua
│   ├── standalone_config.lua
│   ├── ui.lua
│   └── url.lua
├── tests/
│   ├── run.lua
│   ├── companion_spec.lua
│   ├── daemon_manager_spec.lua
│   ├── elementum_client_spec.lua
│   ├── platform_spec.lua
│   ├── preflight_spec.lua
│   ├── rpc_bridge_spec.lua
│   ├── standalone_config_spec.lua
│   ├── ui_spec.lua
│   └── url_spec.lua
├── android-engine/
├── tools/
│   ├── build_addko.ps1
│   └── build_engine_android.ps1
└── docs/
    ├── ADDKO_HOST_CONTRACT.md
    ├── ENGINE_INTEGRATION.md
    ├── SMOKE_TEST_ANDROID.md
    └── SMOKE_TEST_WINDOWS.md
```

## Gerar o plugin `.addko`

No Windows:

```bat
BUILD_ADDKO.bat
```

Resultado:

```text
dist/Luelement-0.2.0-dev.addko
```

O pacote contém somente:

```text
manifest.json
main.lua
src/
```

O motor nativo não fica dentro do `.addko`.

## Gerar o Luelement Engine Android

No Windows:

```bat
BUILD_ENGINE_ANDROID.bat
```

O script prepara Gradle 8.9 localmente quando necessário, usa o Android SDK instalado e gera:

```text
dist/Luelement-Engine-0.1.0-dev-arm64.apk
```

Durante o build são baixados do commit pinado:

```text
android_arm64/elementum.so
android_arm64/libc++_shared.so
```

Antes do APK ser gerado, o build verifica tamanho e Git blob SHA-1 de ambos.

## Elementum pinado

```text
Elementum 0.1.114
repo: elgatito/elementum-binaries
commit: 2bfca0cd91cdf31e94eff121f997b78ff022224c
```

No Windows/Linux/macOS, quando o host oferecer processos nativos, o Luelement pode usar o launcher standalone. No Android, `process.spawn` permanece desativado no AddKo e o companion é usado no lugar.

## Fluxo Android

```text
Plugin.start()
   ↓
preflight do AddKo
   ↓
abre RPC Lua em 127.0.0.1:65221
   ↓
testa /torrents/list
   ↓
engine offline
   ↓
addko.system.open_uri("luelement-engine://start")
   ↓
companion inicia foreground service
   ↓
Elementum sobe em 127.0.0.1:65220
   ↓
Luelement mostra a página inicial
```

O companion fecha sua Activity imediatamente após receber o deep link, portanto o usuário volta ao AddKo automaticamente.

## Reprodução

```text
GET /play?resume=<hash>
        ↓
Elementum seleciona arquivo / faz buffering
        ↓
HTTP 302
Location: http://127.0.0.1:65220/files/...
        ↓
addko.player.play(url)
        ↓
AddKo abre a tela de reprodução
```

Quando houver mais de um arquivo, o daemon pode chamar `Dialog_Select` pela ponte RPC. O Luelement converte isso em um diálogo Flutter genérico do AddKo.

## Rotas internas

```text
home
preflight
status
engine_diagnostics
engine_start
engine_stop
torrents
torrent_add
torrent_add_submit
torrent_pause
torrent_resume
torrent_recheck
torrent_remove
torrent_play
play_uri
session_pause
session_resume
movies_popular
movies_top
```

## Testes

Com Lua disponível:

```sh
lua tests/run.lua
```

Smoke tests reais:

- `docs/SMOKE_TEST_WINDOWS.md`
- `docs/SMOKE_TEST_ANDROID.md`

## Relação com Kodi

Luelement não tenta implementar:

```text
xbmc
xbmcgui
xbmcplugin
xbmcaddon
```

A ponte RPC existe apenas porque o **daemon Elementum** precisa pedir ações de UI/player ao host. Essas chamadas são convertidas para APIs genéricas do AddKo.

## Licença

O código original do Luelement é MIT. Elementum e demais componentes externos continuam sujeitos às respectivas licenças e avisos. Veja `THIRD_PARTY_NOTICES.md`.
