# Binários nativos

O Luelement pode funcionar sem armazenar os binários grandes do Elementum neste repositório.

A ordem usada por `src/daemon_manager.lua` é:

1. procurar binário empacotado em `native/<target>/`;
2. procurar binário já baixado no diretório persistente do plugin;
3. baixar a build oficial pinada em `src/config.lua`.

## Targets atuais

```text
native/
├── windows_x64/
│   └── elementum.exe
├── windows_x86/
│   └── elementum.exe
├── linux_x64/
│   └── elementum
├── linux_x86/
│   └── elementum
├── linux_arm64/
│   └── elementum
├── linux_armv7/
│   └── elementum
├── linux_armv6/
│   └── elementum
├── android_arm64/
│   └── elementum
├── android_arm/
│   └── elementum
├── android_x64/
│   └── elementum
├── android_x86/
│   └── elementum
└── darwin_x64/
    └── elementum
```

A plataforma é normalizada por `src/platform.lua`.

## Build pinada

```text
Elementum 0.1.114
repositório: elgatito/elementum-binaries
commit: 2bfca0cd91cdf31e94eff121f997b78ff022224c
```

Pinamos o commit para que uma alteração futura no branch `master` do repositório de binários não troque silenciosamente o executável usado pelo Luelement.

## Download automático

A URL é formada assim:

```text
https://raw.githubusercontent.com/elgatito/elementum-binaries/<commit>/<target>/elementum[.exe]
```

No Windows x64, por exemplo:

```text
.../2bfca0cd91cdf31e94eff121f997b78ff022224c/windows_x64/elementum.exe
```

O runtime AddKo deve preferencialmente implementar `addko.http.download` para salvar o arquivo diretamente em disco.

## Licença

O executável não passa a ser código do Luelement. Se for redistribuído dentro de um pacote final, devem ser preservados os avisos e a licença do projeto Elementum correspondente.
