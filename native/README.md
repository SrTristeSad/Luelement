# Binários nativos

Este diretório ficará responsável pelos binários do daemon Elementum usados pelo Luelement.

Nenhum binário foi copiado para o repositório nesta primeira etapa.

Estrutura prevista:

```text
native/
├── windows_amd64/
│   └── elementum.exe
├── linux_amd64/
│   └── elementum
├── linux_arm64/
│   └── elementum
├── android_arm64/
│   └── elementum
└── macos_amd64/
    └── elementum
```

Antes de incluir binários vamos fechar três pontos:

1. quais plataformas o AddKo realmente distribuirá;
2. como o Plugin v2 empacotará arquivos por plataforma;
3. como o Luelement gerará a configuração standalone do daemon sem depender do JSON-RPC do Kodi.

O daemon Elementum já possui modo servidor quando iniciado com configuração externa ou com o observador de processo pai desativado. O Luelement deverá usar o modo standalone, não iniciar uma instância dependente do Kodi.
