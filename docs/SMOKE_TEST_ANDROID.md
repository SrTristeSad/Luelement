# Smoke test Android — AddKo + Luelement Engine

Este roteiro valida o caminho Android real do Luelement sem Kodi e sem Python.

## Arquitetura testada

```text
AddKo (Flutter + Lua)
   │
   ├─ Luelement.addko
   │    ├─ HTTP 127.0.0.1:65220 ───────────► Elementum
   │    └─ RPC  127.0.0.1:65221 ◄───────────┘
   │
   └─ system.open_uri("luelement-engine://start")
                  │
                  ▼
        Luelement Engine APK
        └─ foreground service + libelementum.so
```

O AddKo não recebe uma API de torrent. O deep link é aberto pela operação genérica `system.open_uri`.

## Pré-requisitos no Windows

- JDK 17 ou superior no `PATH`;
- Android SDK instalado;
- Android SDK Platform 35;
- CMake 3.22.1 pelo Android SDK Manager;
- um aparelho Android ARM64 com Android 7.0 ou superior;
- depuração USB/ADB apenas se você quiser instalar via cabo.

## 1. Gerar o APK do companion

Na raiz do Luelement:

```bat
BUILD_ENGINE_ANDROID.bat
```

O script:

1. encontra o Android SDK;
2. baixa Gradle 8.9 em `.tools/` quando necessário;
3. baixa `elementum.so` e `libc++_shared.so` do commit pinado;
4. confere tamanho exato e Git blob SHA-1 dos binários;
5. compila o companion ARM64;
6. copia o resultado para:

```text
dist/Luelement-Engine-0.1.0-dev-arm64.apk
```

## 2. Gerar o plugin `.addko`

```bat
BUILD_ADDKO.bat
```

Resultado:

```text
dist/Luelement-0.2.0-dev.addko
```

## 3. Compilar o AddKo atualizado

No repositório do AddKo:

```bat
BUILD_ANDROID.bat
```

Use uma build que contenha, no mínimo:

- runtime Lua persistente;
- HTTP com `follow_redirects=false`;
- TCP local por linhas;
- player de vídeo;
- UI genérica de plugin;
- `system.open_uri`.

## 4. Instalar no aparelho

Instale primeiro:

```text
AddKo APK
Luelement Engine APK
```

O companion pode ser aberto manualmente para confirmar que a tela mostra:

```text
Motor parado
```

Não é necessário iniciar manualmente.

## 5. Instalar o Luelement

No AddKo:

1. toque em **Instalar pacote .addko**;
2. escolha `Luelement-0.2.0-dev.addko`;
3. confirme as permissões genéricas solicitadas;
4. toque em **Abrir** no Luelement.

## 6. Resultado esperado da inicialização

Ao abrir o plugin:

1. Lua inicia a ponte RPC em `127.0.0.1:65221`;
2. Luelement testa `GET /torrents/list` em `65220`;
3. se o engine estiver parado, chama `luelement-engine://start`;
4. o companion inicia o foreground service e fecha sua Activity imediatamente;
5. o usuário retorna ao AddKo;
6. Luelement aguarda até `/torrents/list` responder;
7. a página inicial mostra **Motor ativo pelo Luelement Engine**.

Se o companion não estiver instalado, o plugin deve mostrar uma página de erro em vez de travar.

## 7. Testar torrent/magnet

Use somente um torrent que você tenha direito de baixar/distribuir.

Na tela do Luelement:

1. abra **Adicionar magnet**;
2. cole o magnet/URL;
3. toque em **Adicionar**;
4. abra **Torrents**;
5. confirme que progresso, status, peers e velocidade aparecem.

Quando houver mais de um arquivo e o Elementum pedir escolha, o diálogo deve ser exibido pelo Flutter do AddKo através da ponte RPC Lua.

## 8. Testar reprodução

Na lista de torrents toque em **Reproduzir**.

Fluxo esperado:

```text
Luelement
   ↓
GET /play?resume=<hash>
   ↓
Elementum faz buffering
   ↓
HTTP 302 Location: /files/...
   ↓
addko.player.play(http://127.0.0.1:65220/files/...)
   ↓
AddKo abre a tela de reprodução
```

O Android do AddKo já permite HTTP claro apenas para `localhost`/`127.0.0.1`, portanto o stream local não precisa de HTTPS.

## 9. Diagnóstico

A tela **Diagnóstico** do Luelement mostra:

- engine pronto ou não;
- estado da ponte RPC;
- plataforma;
- disponibilidade do companion;
- se o companion foi iniciado pelo plugin.

Problemas comuns:

### Companion não instalado

Sintoma: `system.open_uri` retorna `false` ao abrir `luelement-engine://start`.

Solução: instalar o APK do Luelement Engine.

### Porta 65220 ocupada

Outro processo está usando a porta HTTP do Elementum. Encerre esse processo ou a instância antiga do engine.

### Porta 65221 ocupada

Outra sessão está segurando a ponte RPC. Feche/reabra o Luelement ou reinicie o AddKo durante o desenvolvimento.

### Engine inicia mas `/torrents/list` não responde

Abra manualmente o Luelement Engine e consulte o arquivo interno de log do Elementum durante desenvolvimento. O plugin também mantém a página de diagnóstico disponível.

## Estado de validação

O fluxo está implementado no código, mas este ambiente de desenvolvimento do assistente não possui Flutter/Dart/Lua/Gradle instalados para executar o APK e o `.addko` aqui. Portanto, este documento é o procedimento do **primeiro teste físico**, e não uma afirmação de que o smoke test já passou em aparelho real.
