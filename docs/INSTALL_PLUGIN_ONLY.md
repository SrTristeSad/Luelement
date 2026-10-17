# Luelement integrado ao AddKo Android

O Luelement é um plugin `.addko`, não outro APK.

1. Instale uma build Android do **AddKo que contenha o módulo nativo aprovado Elementum** (build completa, não a variante leve).
2. No AddKo, abra **Loja → Instalar arquivo .addko**.
3. Selecione `Luelement-0.2.0-dev.addko` e confirme as permissões `network`, `storage`, `media`, `background` e `native_engine`.
4. Abra o Luelement na home. Ele consulta `addko.engines.available("elementum")`, abre a ponte RPC local e solicita `addko.engines.start("elementum")`.
5. Aguarde o serviço responder em `127.0.0.1:65220`, adicione um magnet permitido e reproduza pelo player AddKo.

**Sem segundo aplicativo:** o AddKo não permite que um repositório Lua carregue binários arbitrários. As bibliotecas aprovadas são fixadas por hash no build e assinadas com o APK.

**Estado:** o código de integração foi implementado; o teste completo com torrent e player num aparelho real continua obrigatório antes de anunciar streaming funcional.
