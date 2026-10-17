# Instalação do Luelement como plugin do AddKo

O formato de instalação é **`.addko`**, não `.apk`.

1. Obtenha `dist/Luelement-0.2.0-dev.addko` do repositório.
2. No AddKo, abra Loja > Instalar arquivo `.addko`.
3. Selecione o arquivo e confirme as permissões genéricas já oferecidas pelo AddKo.
4. Abra Luelement na tela inicial do AddKo.

**Limitação atual:** o frontend Lua e a interface podem ser instalados, mas o AddKo Android ainda não possui carregamento genérico de módulos nativos exigidos para executar o Elementum/libtorrent *dentro do próprio plugin*. A reprodução de torrents no Android ainda não funciona sem esse suporte. O produto final não exigirá outro APK. Não anuncie o pacote de desenvolvimento como versão de streaming funcional.

No desktop, a capacidade genérica `process.spawn` do AddKo já existe, mas é necessária uma build de desktop e validação real.
