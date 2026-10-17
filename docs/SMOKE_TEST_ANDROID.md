# Android smoke test: AddKo + Luelement no mesmo APK

**Pré-requisitos:** um aparelho Android ARM64, um APK completo do AddKo com a extensão nativa aprovada Elementum e o pacote Lua `Luelement-0.2.0-dev.addko`. Não há companion APK.

## Preparar

1. Faça o build Android ARM64 do AddKo completo (`addkoIncludeElementum=true`, padrão).
2. Confirme que o APK assinado contém `libelementum.so`, `libc++_shared.so`, `libaddko_engine_bridge.so`, além da lib Lua. A build Gradle verifica as bibliotecas Elementum contra o commit e hash fixados.
3. Instale **somente o AddKo APK**.
4. Gere `Luelement-0.2.0-dev.addko` com `BUILD_ADDKO.bat` do Luelement, instale em **Loja → Instalar .addko** e confirme a permissão genérica `native_engine`.

## Inicialização

1. Abra Luelement na home do AddKo.
2. Verifique `addko.engines.available("elementum") == true`.
3. Confirme que o plugin inicia seu servidor JSON-RPC Lua em `127.0.0.1:65221`.
4. Ele solicita `addko.engines.start("elementum")` ao serviço Android interno não exportado do AddKo.
5. Aguarde o health check GET `http://127.0.0.1:65220/torrents/list`; a resposta deve ser HTTP 200.

O AddKo não inicia processos ou carrega bibliotecas de dentro do pacote Lua. O serviço nativo é incluído pelo build assinado. A build leve `-PaddkoIncludeElementum=false` retorna `available=false`.

## Exercício de vídeo/torrent legal

1. Adicione um magnet autorizado (por exemplo, um conteúdo de teste distribuído legalmente).
2. Confira peers, seeds, progresso e velocidade na página Torrents.
3. Se houver múltiplos arquivos, verifique o diálogo de seleção do host Lua.
4. Toque em reproduzir e confira o buffering até o redirect `/files/...` em `127.0.0.1:65220`.
5. Valide que o player do AddKo abre, reproduz, exibe duração e suporta seek HTTP.
6. Feche o Luelement: a ponte RPC é fechada; o engine só deve parar se iniciado pelo plugin ou quando solicitada parada explícita.

## Segurança e ciclo de vida

- Desinstalar Luelement não deve apagar dados privados sem confirmação.
- Addons sem `native_engine` e `native_engines` não devem acessar o serviço.
- Externamente o serviço Android tem `exported=false`.
- Verifique FGS, notificação, consumo de bateria e tempo máximo de `dataSync` no Android 15: seis horas acumuladas em segundo plano por janela de 24 horas.
- Valide erros em lib ausente, porta ocupada, daemon que falha e processo nativo reiniciado.

**Estado:** roteiro para teste real, não é evidência de reprodução concluída.
