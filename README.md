# Luelement

Luelement é um plugin Lua experimental para o AddKo que usa o **daemon do Elementum** como motor nativo de torrent/streaming, sem portar o ecossistema de addons do Kodi.

```text
AddKo
  ↓
Luelement (Lua)
  ├─ HTTP → Elementum :65220
  └─ RPC Lua :65221 ← Elementum
                 ↓
        libtorrent / BitTorrent
```

O núcleo do AddKo continua genérico. Torrent, DHT, magnet, peers, buffering e gerenciamento da sessão permanecem no daemon do Elementum. A inicialização, navegação, UI, callbacks e integração com o player ficam em Lua.

## Estado atual — 0.2.0-dev

Já implementado no `main`:

- cliente Lua da API HTTP do Elementum;
- inicialização standalone do daemon com `-configPath`;
- geração do `ConfigBundle` sem depender das settings do Kodi;
- detecção de Windows/Linux/Android/macOS e arquitetura;
- download automático do binário oficial Elementum v0.1.114, pinado em commit específico;
- cache do binário por plataforma;
- gerenciamento de diretórios de profile, temp, torrents, library e downloads;
- ponte JSON-RPC 2.0 em Lua na porta `65221`, substituindo a função central do antigo `rpc.py`;
- callbacks de diálogo, progresso e estado do player mapeados para APIs genéricas do AddKo;
- listagem, adição, pausa, retomada, recheck e remoção de torrents;
- resolução de reprodução por `/play`, capturando o redirect `/files/...`;
- entrega da URL resultante ao player do AddKo;
- health-check silencioso via `/torrents/list`;
- preflight do runtime AddKo;
- testes Lua sem dependências externas para URL, plataforma, preflight, RPC e configuração standalone;
- diagnóstico do daemon e da plataforma.

### Ainda não validado de ponta a ponta

Este repositório já contém o fluxo necessário, porém ele **ainda não foi executado dentro do runtime Lua real do AddKo**. Para o primeiro teste completo, o AddKo precisa expor o contrato genérico documentado em `docs/ADDKO_HOST_CONTRACT.md`, principalmente:

- HTTP com opção de não seguir redirects;
- filesystem;
- processos nativos;
- servidor TCP local por linhas;
- player;
- temporização.

Não existe API especial de torrent no AddKo.

## Fluxo alvo

```text
Plugin.start()
   ↓
preflight do runtime
   ↓
abre RPC Lua em 127.0.0.1:65221
   ↓
localiza ou baixa elementum
   ↓
gera elementum-config.json
   ↓
inicia daemon em 127.0.0.1:65220
   ↓
/torrents/list responde silenciosamente
   ↓
magnet/torrent
   ↓
/play faz buffering
   ↓
302 Location: /files/...
   ↓
AddKo player.play(url)
```

> Observação: `/status` do Elementum não é usado como health-check porque essa rota abre um diálogo de status pela ponte RPC.

## Estrutura

```text
Luelement/
├── main.lua
├── plugin.json
├── src/
│   ├── addko_host.lua
│   ├── app.lua
│   ├── config.lua
│   ├── daemon_manager.lua
│   ├── elementum_client.lua
│   ├── platform.lua
│   ├── preflight.lua
│   ├── rpc_bridge.lua
│   ├── standalone_config.lua
│   └── url.lua
├── tests/
│   ├── run.lua
│   ├── platform_spec.lua
│   ├── preflight_spec.lua
│   ├── rpc_bridge_spec.lua
│   ├── standalone_config_spec.lua
│   └── url_spec.lua
├── native/
│   └── README.md
└── docs/
    ├── ADDKO_HOST_CONTRACT.md
    ├── ENGINE_INTEGRATION.md
    └── SMOKE_TEST_WINDOWS.md
```

## Binário Elementum

Por padrão, o Luelement não precisa guardar binários grandes neste repositório. Na primeira execução ele pode baixar apenas o executável da plataforma atual do repositório oficial `elgatito/elementum-binaries`.

A versão está atualmente pinada em:

```text
Elementum 0.1.114
commit 2bfca0cd91cdf31e94eff121f997b78ff022224c
```

Também é possível empacotar um executável previamente em `native/<target>/elementum[.exe]`; o plugin dá preferência ao binário empacotado.

## Rotas internas iniciais do Luelement

```text
home
preflight
status
engine_diagnostics
engine_start
engine_stop
torrents
torrent_add
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

`status` é uma rota do próprio Luelement e faz health-check silencioso; ela não chama `/status` do daemon.

Exemplo conceitual:

```lua
Plugin.route("play_uri", {
    uri = "magnet:?xt=urn:btih:...",
    index = 0,
})
```

O índice pode ser omitido. Quando o torrent possui vários arquivos, o Elementum pode solicitar seleção através da ponte RPC Lua, que encaminha o diálogo ao AddKo.

## Testes

Quando houver um interpretador Lua 5.4/compatível disponível na raiz do projeto:

```sh
lua tests/run.lua
```

Os testes não dependem de Kodi, Elementum ou internet; eles cobrem a camada Lua isoladamente. O smoke test real do daemon/player está documentado em `docs/SMOKE_TEST_WINDOWS.md`.

## Relação com Elementum

Luelement é um projeto independente. Ele não tenta portar `xbmc`, `xbmcgui`, `xbmcplugin` nem oferecer compatibilidade genérica com addons do Kodi. A única ponte implementada é a que o **próprio daemon Elementum** precisa para conversar com UI/player.

- Elementum daemon: https://github.com/elgatito/elementum
- Binários oficiais: https://github.com/elgatito/elementum-binaries

## Licença

O código original do Luelement é disponibilizado sob MIT. Componentes externos continuam sujeitos às respectivas licenças e avisos. Veja também `THIRD_PARTY_NOTICES.md`.
