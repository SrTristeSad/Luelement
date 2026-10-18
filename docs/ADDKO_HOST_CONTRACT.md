# Contrato nativo genérico do AddKo para Luelement

O Luelement é uma ferramenta de serviço, chamada por outro addon via `addko.plugins.call`; não possui experiência visual obrigatória. Utiliza o runtime Lua, HTTP, JSON, armazenamento, TCP local e player do AddKo, além da API genérica de motores pré-aprovados.

O manifesto declara:

```json
{
  "type": "service",
  "permissions": ["network", "storage", "media", "background", "native_engine"],
  "native_engines": ["elementum"]
}
```

A permissão `native_engine` aparece na confirmação de instalação; `native_engines` limita quais IDs podem ser chamados. O APK completo precisa incluir o motor, ou `available()` retornará falso.

```lua
local available = addko.engines.available("elementum")
local started = addko.engines.start("elementum")
local status = addko.engines.status("elementum")
local stopped = addko.engines.stop("elementum")
```

O aplicativo nunca carrega `.so` fornecido pelo `.addko`. Um serviço Android não exportado executa somente o módulo incluído previamente no APK assinado. Chamadas de rede e player continuam usando APIs genéricas.

HTTP do engine: `127.0.0.1:65220`. RPC Lua: `127.0.0.1:65221`. Na versão nova do AddKo, o Luelement registra a URL de `/files/...`
via `addko.stream.register({url=...})`, entrega ao player a URL local
`/media/<token>` e libera o registro ao substituir a fonte ou ao
encerrar o serviço. O núcleo faz o transporte HTTP Range diretamente
para o player, sem transferir bytes para Lua.

Se o AddKo instalado ainda não oferece `media_stream_proxy`,
o Luelement preserva a reprodução anterior usando a URL direta
`/files/...`. Essa compatibilidade não é prova de reprodução real.

Além disso, o contrato de serviço expõe
`addko.plugins.call("io.addko.luelement", "stream_stats", {})`
para addons dependentes. A resposta contém somente métricas e códigos de
HTTP da fonte ativa, sem tokens, cabeçalhos de autenticação ou URLs de
origem. Em uma versão antiga do núcleo ou sem fonte ativa,
`ready = false`.

A primeira instalação ainda precisa de smoke test físico para validar FGS, JNI, libtorrent, HTTP, RPC e player.
