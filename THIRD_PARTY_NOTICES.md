# Third-party notices

## Elementum

Luelement interoperates with and may download/distribute binaries from the Elementum project.

- Project: https://github.com/elgatito/elementum
- Binary repository: https://github.com/elgatito/elementum-binaries
- Original project author/maintainer attribution remains with the Elementum project and its contributors.
- License: MIT License (see the upstream repositories for the authoritative copyright notice and license text).

Luelement does not claim ownership of the Elementum daemon, libtorrent, libtorrent-go or their upstream components.

The Lua code in this repository is an independent integration layer for AddKo. Where behavior/protocol compatibility was derived from Elementum's public source code, the upstream license and attribution must be preserved as required by MIT.

## Runtime downloads

The development configuration currently pins Elementum `0.1.114` to binary repository commit:

```text
2bfca0cd91cdf31e94eff121f997b78ff022224c
```

Changing this pin should be reviewed together with the upstream license/notices and a compatibility smoke test.
