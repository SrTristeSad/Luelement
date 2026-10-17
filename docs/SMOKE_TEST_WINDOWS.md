# Smoke test — Windows x64

Este é o primeiro teste que deve ser executado quando o runtime Lua do AddKo expuser o contrato de `docs/ADDKO_HOST_CONTRACT.md`.

## 1. Preflight

Chamar:

```lua
Plugin.route("preflight")
```

Esperado:

```text
ok = true
missing = []
```

Warnings podem existir, mas o teste não deve prosseguir se houver capacidades obrigatórias ausentes.

## 2. Inicialização

Chamar:

```lua
Plugin.start()
```

O fluxo esperado é:

```text
RPC Lua abre em 127.0.0.1:65221
        ↓
Luelement procura elementum.exe
        ↓
se ausente, baixa windows_x64/elementum.exe
        ↓
gera elementum-config.json
        ↓
inicia daemon com configPath + remoteHost
        ↓
GET http://127.0.0.1:65220/status
        ↓
sucesso
```

O resultado deve indicar `engine.owned=true` quando a instância foi criada pelo próprio Luelement.

## 3. Diagnóstico

```lua
Plugin.route("engine_diagnostics")
```

Verificar:

```text
ready = true
rpc_started = true
platform.target = windows_x64
paths.executable termina em elemento/0.1.114/windows_x64/elementum.exe
```

Consultar o `elementum.log` se `ready=false`.

## 4. Torrent de teste legal

Usar apenas um torrent/magnet de conteúdo que possa ser distribuído legalmente, por exemplo uma imagem ISO de distribuição Linux disponibilizada oficialmente via BitTorrent.

Para reduzir variáveis no primeiro teste, prefira um torrent com um único arquivo ou informe explicitamente `index=0`.

Exemplo conceitual:

```lua
Plugin.route("play_uri", {
    uri = TEST_MAGNET,
    index = 0,
})
```

## 5. Buffer e redirect

O log deve mostrar o torrent entrando em buffering.

A chamada `/play` deve terminar em HTTP 302 com `Location` semelhante a:

```text
http://127.0.0.1:65220/files/<arquivo>
```

O cliente Lua não deve consumir o corpo desse URL. Ele apenas entrega o endereço ao player.

## 6. Player

Após o redirect:

```text
addko.player.play(url)
```

Durante a reprodução o daemon consultará a ponte Lua na porta 65221:

```text
Player_IsPlaying
Player_IsPaused
Player_WatchTimes
```

Essas chamadas precisam refletir o estado real do player do AddKo.

## 7. Seek

Avançar manualmente no vídeo e confirmar que o player consegue solicitar ranges HTTP ao `/files/...` sem reiniciar o torrent.

## 8. Encerramento

```lua
Plugin.stop()
```

Se a instância foi criada pelo Luelement:

```text
/shutdown
→ daemon encerra
→ RPC 65221 fecha
```

Se o Luelement apenas se conectou a uma instância preexistente, não deve matar esse processo.

## Critério de aprovação

O smoke test passa somente se:

- daemon inicia sem Kodi instalado/rodando;
- `/status` funciona;
- RPC 65221 recebe chamadas do daemon;
- um magnet legal gera URL `/files/...`;
- vídeo começa no player do AddKo;
- seek funciona;
- encerramento não deixa processo órfão criado pelo Luelement.

Até isso ser executado em uma build real do AddKo, mantenha a versão como `0.2.0-dev`.
