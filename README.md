# Luelement

Luelement é um plugin Lua experimental para o AddKo que usa o **daemon do Elementum** como motor nativo de torrent/streaming, sem portar o ecossistema de addons do Kodi.

A ideia é simples:

```text
AddKo
  ↓
Luelement (Lua)
  ↓ HTTP local
Elementum daemon (Go + libtorrent)
```

O núcleo do AddKo continua genérico. Torrent, DHT, magnet, peers, buffering e gerenciamento da sessão permanecem no daemon do Elementum; a interface, navegação e integração com o AddKo ficam em Lua.

## Estado atual

Primeira base do projeto:

- cliente Lua para a API HTTP local do Elementum;
- operações de status e gerenciamento de torrents;
- adapter isolado para o host AddKo;
- bootstrap do plugin;
- contrato mínimo documentado para o runtime Lua do AddKo.

Ainda não há binários do Elementum neste repositório e o formato final de empacotamento do Plugin v2 do AddKo ainda pode mudar. Por isso, toda integração específica do host fica concentrada em `src/addko_host.lua`.

## Estrutura

```text
Luelement/
├── main.lua
├── plugin.json
├── src/
│   ├── addko_host.lua
│   ├── app.lua
│   ├── config.lua
│   ├── elementum_client.lua
│   └── url.lua
├── native/
│   └── README.md
└── docs/
    └── ADDKO_HOST_CONTRACT.md
```

## Objetivo da primeira fase

1. iniciar ou conectar ao daemon Elementum;
2. verificar `/status`;
3. listar torrents por `/torrents/list`;
4. adicionar magnet/torrent por `/torrents/add`;
5. pausar, continuar e remover torrents;
6. entregar a URL de reprodução ao player do AddKo;
7. depois portar catálogo, busca e fluxo de seleção de streams.

## Relação com Elementum

Luelement é um projeto independente. Ele não pretende copiar a camada Python/Kodi do `plugin.video.elementum`; a meta é criar uma integração Lua própria para o AddKo usando a API do daemon.

Elementum: https://github.com/elgatito/elementum

## Licença

O código original do Luelement é disponibilizado sob MIT. Componentes externos, quando forem distribuídos junto ao plugin, continuam sujeitos às respectivas licenças e avisos.
