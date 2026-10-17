# Integração com o daemon Elementum

## O que já foi confirmado

O daemon Elementum expõe HTTP local por padrão em `127.0.0.1:65220`.

O Luelement usa essa API diretamente e não precisa portar `xbmc`, `xbmcgui`, `xbmcplugin` ou qualquer outro módulo Python do Kodi.

As rotas já usadas pela primeira base do Luelement incluem:

```text
/status
/torrents/list
/torrents/add
/torrents/pause
/torrents/resume
/torrents/recheck/:id
/torrents/delete/:id
```

`/torrents/add` aceita `uri` e o parâmetro opcional `all=1`, permitindo magnet links sem que Lua implemente BitTorrent.

## Modo servidor

O daemon considera que está em modo servidor quando recebe uma configuração externa (`-configPath`) ou quando `-disableParentProcessWatcher` está ativo.

O projeto oficial `ElementumOrg/elementum-docker` inicia o binário com argumentos como:

```text
-addonPath=...
-tempPath=...
-profilePath=...
-torrentsPath=...
-libraryPath=...
-logPath=...
-downloadsPath=...
-disableParentProcessWatcher
```

O Luelement seguirá a mesma ideia, mas sem Docker e sem depender de uma instalação do Kodi.

## Ponto que ainda precisa ser fechado

O Elementum original nasceu acoplado ao Kodi e várias funções de configuração/UX ainda consultam estruturas ligadas ao XBMC. Por isso não vamos simplesmente iniciar o binário com parâmetros incompletos e chamar isso de pronto.

A próxima etapa é gerar uma configuração standalone própria do Luelement e validar quais rotas funcionam sem qualquer JSON-RPC do Kodi. Se alguma função do daemon exigir callbacks de UI, ela será substituída no frontend Lua ou isolada atrás de uma ponte mínima específica do Luelement — não por uma camada genérica de compatibilidade com addons Kodi.

## Regra do projeto

O objetivo continua sendo:

```text
AddKo -> Lua Luelement -> Elementum daemon -> libtorrent
```

Não:

```text
AddKo -> emulador de Kodi -> addon Python -> Elementum
```
