# Contrato nativo genérico do AddKo para Luelement

O Luelement utiliza o runtime Lua, a UI, HTTP, JSON, armazenamento, TCP local e player do AddKo, além da API genérica de motores pré-aprovados.

O manifesto declara:

```json
{
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

HTTP do engine: `127.0.0.1:65220`. RPC Lua: `127.0.0.1:65221`. A reprodução entrega a URL `/files/...` ao `addko.player.play`.

A primeira instalação ainda precisa de smoke test físico para validar FGS, JNI, libtorrent, HTTP, RPC e player.
