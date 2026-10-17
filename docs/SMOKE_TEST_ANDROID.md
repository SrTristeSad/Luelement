# Teste Android: AddKo + Luelement + VideoTorrent

**Objetivo:** validar uma reprodução real por torrent, não apenas a notificação do
serviço nativo. Nenhum outro addon é considerado concluído até este fluxo funcionar.

## Pacotes necessários

1. **AddKo APK Android ARM64 completo**, recompilado a partir do main atual, com
   o módulo Elementum aprovado incluído. A build leve não contém o motor.
2. **Luelement-0.2.2-dev.addko**: addon do tipo `service` com permissão
   `native_engine`, disponível em **Configurações → Gerenciar addons**.
   Serviços não aparecem na tela inicial do AddKo.
3. **VideoTorrent-0.1.3.addko**: addon de interface comum, instalado após
   Luelement. Ele aparece no launcher como **Vídeo por Torrent**.

O APK deve conter `libelementum.so`, `libc++_shared.so`,
`libaddko_engine_bridge.so` e a biblioteca Lua. O Gradle verifica
as bibliotecas nativas usadas pelo projeto.

## Diagnóstico em etapas

1. **Abrir o addon.** Pressione ENTRAR em Vídeo por Torrent.
   A tela Lua deve abrir *sem* aguardar o Elementum.
   Se não abrir, é erro na UI/runtime, antes de qualquer conexão torrent.
2. **Inicializar o serviço.** Toque em **Verificar novamente**. A chamada
   `addko.plugins.call("io.addko.luelement", "health", {})` inicia o
   serviço sob demanda, incluindo sua ponte RPC em `127.0.0.1:65221`.
3. **Verificar motor.** O Luelement chama `addko.engines.start("elementum")`
   se necessário. Confirmar `GET http://127.0.0.1:65220/torrents/list`
   com HTTP 200. A notificação Android **não** comprova essa etapa.
4. **Reprodução.** Usar um magnet ou URL `.torrent` de **vídeo legalmente
   distribuído, com peers/seeds verificados**. O magnet incluído no
   VideoTorrent é apenas diagnóstico: não garante seeds nem arquivo de vídeo.
5. **Resolução da mídia.** `GET /play?uri=...` deve produzir HTTP 302 com
   `Location: http://127.0.0.1:65220/files/...`. O cliente Lua consome
   apenas os headers, não o corpo do vídeo.
6. **Player.** A tela Flutter deve abrir com indicação de preparação da mídia,
   iniciar a reprodução quando houver dados suficientes e permitir
   pausa e seek. Em caso de falha na inicialização, deve exibir erro visível.

## Evidências a registrar

| Etapa | Evidência esperada | Se falhar |
| --- | --- | --- |
| ENTRAR | Tela Vídeo por Torrent | Conferir erro de Lua/UI, botão e versões |
| Verificar novamente | Motor conectado | Conferir Luelement, permissões e APK completo |
| Motor Android | HTTP 200 em /torrents/list | Inspecionar logs do NativeEngineService e Elementum |
| Solicitar torrent | Metadados e peers | Confirmar seeds/tracker e licença do conteúdo |
| GET /play | 302 e header Location | Conferir RPC e seleção do arquivo |
| Player | Vídeo, pausa e seek | Conferir codec, URL /files, HTTP Range e log Flutter |

## Critério de aceitação

Só declarar a integração **funcional** quando um aparelho Android físico
realizar toda a sequência: instalar → abrir UI → inicializar Luelement
→ motor responde → obter um stream real → assistir → pausar → avançar
→ fechar corretamente. Testes unitários e mocks não substituem essa prova.

**Segurança:** não permitir executar binários arbitrários dentro de .addko.
Módulos nativos Android precisam estar previamente aprovados e assinados.
O núcleo do AddKo continua genérico: o BitTorrent pertence à integração do
Luelement, e não à API de interface do AddKo.
