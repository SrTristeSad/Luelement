# Luelement

> **Distribuição:** o Luelement continua sendo um plugin Lua `.addko`. O AddKo Android inclui opcionalmente o módulo aprovado Elementum **dentro do próprio APK** na build completa. O addon não executa `.so` externo, e não requer um APK auxiliar. A integração nativa precisa ser validada em aparelho físico.


Luelement é um **plugin de serviço (ferramenta para outros addons)**, não um aplicativo de vídeos. Addons consumidores o declaram como dependência e chamam `addko.plugins.call("io.addko.luelement", ...)`. O usuário interage com a interface criada pelo addon consumidor. O serviço usa o **Elementum** como motor nativo de torrent/streaming, sem transformar o AddKo em Kodi nem portar o ecossistema Python do Kodi.

```text
AddKo → addon de vídeos (interface escolhida pelo autor)
         │ addko.plugins.call("io.addko.luelement", "stream"/"play", ...)
         ▼
     Luelement (serviço Lua, sem card na home)
         ├─ HTTP → Elementum :65220
         └─ RPC Lua :65221 ← Elementum
                                  ▼
                         libtorrent / BitTorrent
```

No Android, o motor nativo aprovado já vem no APK do AddKo (build completa):

```text
AddKo APK (motor Elementum aprovado e assinado)
  └─ Luelement.addko → addko.engines.start("elementum")
       └─ serviço Android nativo → Elementum + libtorrent
```

O núcleo do AddKo continua genérico. Não existe `addko.torrent` nem `addko.elementum`; existe a API `addko.engines` com permissão genérica `native_engine` e IDs de módulos já incluídos no APK.

## Estado atual — 0.2.2-dev

Já implementado no `main`:

- `manifest.json` compatível com o formato `.addko` atual;
- serviço Lua modular usando o `require` seguro do AddKo;
- tipo de manifesto `service`, oculto da tela inicial e acessível em Gerenciar addons;
- inicialização sob demanda na primeira chamada de um addon consumidor;
- rotas internas legadas de diagnóstico mantidas para testes, sem card de aplicativo;
- tela de torrents com progresso, status, peers, seeds e velocidades;
- formulário para adicionar magnet/URL de torrent;
- ações de pausa, retomada, recheck, remoção e reprodução;
- cliente Lua da API HTTP do Elementum;
- health-check silencioso via `/torrents/list`;
- resolução de reprodução por `/play`, capturando o redirect `/files/...`;
- ponte JSON-RPC 2.0 em Lua na porta `65221`;
- confirmação, seleção, teclado e alertas encaminhados para UI Flutter genérica do AddKo;
- player HTTP do AddKo com tela própria de reprodução;
- integração opcional com `addko.stream.register` do núcleo AddKo para transportar `/files/...` via HTTP Range e URL local temporária;
- revogação da fonte de mídia ao trocar de vídeo ou encerrar o serviço; fallback à URL direta em núcleos antigos;
- método de serviço `stream_stats` para o addon consumidor diagnosticar HTTP, requisições Range, bytes enviados e falhas sem acessar informações sensíveis;
- launcher standalone do daemon para hosts que permitam processos nativos;
- geração de `ConfigBundle` standalone sem depender das settings do Kodi;
- detecção de plataforma/arquitetura;
- download/cache do binário Elementum em hosts compatíveis;
- serviço Elementum assinado integrado ao APK ARM64 do AddKo;
- inicialização do serviço via API Lua genérica `addko.engines`;
- foreground service Android para manter o Elementum ativo;
- bibliotecas Android do Elementum pinadas por commit, tamanho exato e Git blob SHA-1;
- gerador Windows do pacote `.addko`;
- código experimental antigo do companion mantido apenas para referência histórica;
- 41 testes Lua executados no GitHub Actions, incluindo o motor nativo aprovado;
- testes do host AddKo para permissões, `native_engine`, filesystem e UI genérica.

## O que ainda falta validar

A suíte Lua passou no GitHub Actions (41/41 testes). O fluxo **ainda não foi testado de ponta a ponta em aparelho Android** com o engine e player reais.

O próximo marco real é um teste em Windows/aparelho Android provando:

```text
AddKo
  ↓
instala Luelement.addko (serviço)
  ↓
abre um addon de vídeos que depende de Luelement
  ↓
o AddKo inicia Luelement automaticamente ao receber a primeira chamada
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
dist/Luelement-0.2.2-dev.addko
```

O pacote contém somente:

```text
manifest.json
main.lua
src/
```

O motor nativo não fica dentro do `.addko`.

## Motor nativo no APK do AddKo

Não gere nem instale um companion Android. Faça o build completo do **AddKo Android ARM64**: o Gradle incorpora as bibliotecas oficiais Elementum fixadas por hash e produz **um único APK**.

O código histórico em `android-engine/` permanece como referência, mas não é utilizado no novo fluxo.

## Obter o pacote Lua atualizado

O workflow **Luelement Lua package** executa os testes e gera o artefato `Luelement-Lua-Addon` com o `.addko` atualizado. Use esse artefato, ou gere o pacote localmente com `BUILD_ADDKO.bat`. O arquivo preexistente em `dist/` pode estar desatualizado.

## Elementum pinado

```text
Elementum 0.1.114
repo: elgatito/elementum-binaries
commit: 2bfca0cd91cdf31e94eff121f997b78ff022224c
```

No Windows/Linux/macOS, quando o host oferecer processos nativos, o Luelement pode usar o launcher standalone. No Android, `process.spawn` permanece desativado; o serviço aprovado é solicitado por `addko.engines.start("elementum")`.

## Fluxo Android

```text
Plugin.start()
   ↓
ponte RPC Lua em 127.0.0.1:65221
   ↓
verifica Elementum em 127.0.0.1:65220
   ↓
addko.engines.available("elementum")
   ↓
addko.engines.start("elementum")
   ↓
serviço interno de módulo assinado, em processo Android separado
   ↓
Elementum + libtorrent sobe; retorna HTTP 200 em /torrents/list
   ↓
Luelement apresenta sua própria interface Lua
```

O manifesto declara `native_engine` e o módulo `elementum`; o usuário autoriza a permissão no diálogo do AddKo. **Nenhum outro APK é necessário.** A build leve do AddKo não inclui o módulo.

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
