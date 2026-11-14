# Linux layer — DeepSeek Harness Linux

Camada própria deste projeto, sobreposta ao código do upstream `deepseek-ai/deepseek-harness`
(vendored na tag `dsh-v0.2.2-rc.3`). Tudo o que é específico de Linux vive aqui.

> **Compilação comunitária e não oficial.** Ver [`../NOTICE`](../NOTICE).

## Estado

**Funcional e verificado.** O `.deb` e o `.AppImage` são produzidos a partir do fonte do upstream,
instalam e arrancam num Ubuntu 24.04 x86_64.

| Verificação | Resultado |
|---|---|
| `pnpm run typecheck` | 5/5 gates (host e client) |
| `pnpm run build` | 10/10 gates |
| Runtime preparado | CLI offline, `dsh web`, pty, sharp, koffi, ripgrep |
| Office | skills carregam; **conversão indisponível** (o upstream não publica motor nativo para Linux) |
| Pacote gerado | 279 MB, 9 186 ficheiros, `install ok installed` |
| Arranque | Host sobe em `127.0.0.1`, perfil criado em `~/.dsh` |
| Electron / Node embutidos | 44.7.0 / 24.21.0 |

## Porque existe esta camada

O upstream declara, em `apps/desktop/packaging/README.md` (linha 100):
*"Linux is not a supported Desktop release target."*

O alvo não existia, mas a base quase toda já estava lá — o `electron-builder-config.mjs` tinha um
bloco `linux` com `target: ['AppImage']`. O que faltava era o encanamento:

| Peça | Estado no upstream | Estado aqui |
|---|---|---|
| Bloco `linux` no electron-builder | parcial (só AppImage) | `deb` + `AppImage`, ícone, `.desktop`, mantenedor |
| Alvo `linux-x64` no registry de `package-target.ts` | ausente | presente |
| Script `package:linux:x64` | ausente | presente |
| Mapa de caminhos de build | ausente | `linux-x64` reconhecido |
| Launcher POSIX do CLI | só macOS | `cli/dsh` instalado com `0755` |
| Caminho do Electron para Linux | assumia macOS | corrigido |
| Política de atualização obrigatória | exigia origin oficial | omitida em Linux |
| Metadados Debian | — | `homepage`, mantenedor, dependências `t64` |

## Estrutura

```
linux/
├── README.md                          este ficheiro
├── packaging/
│   └── deepseek-harness-linux.desktop entrada de aplicação canónica
├── scripts/
│   ├── build-deb.sh                   build completo: instala, compila, empacota
│   ├── setup-dev-env.sh               aprovisiona o ambiente Linux de build
│   ├── enable-wsl.ps1                 ativa WSL2 + Ubuntu 24.04 (Windows, requer admin)
│   └── verificar-ambiente.sh          auditoria da máquina de build
├── docker/
│   └── Dockerfile                     ambiente reprodutível Ubuntu 24.04
└── docs/
    ├── architecture/analise-tecnica.md
    ├── development/plano.md
    └── installation/
        ├── INSTALL.md                 guia de instalação e dependências
        └── build-deb.md               como construir a partir do fonte
```

## Construir

```sh
bash linux/scripts/setup-dev-env.sh   # Node 24, pnpm, dependências (uma vez)
bash linux/scripts/build-deb.sh       # gera .deb + .AppImage
```

O resultado fica em `apps/desktop/.desktop-build/targets/linux-x64/unsigned-artifacts/`.

Em CI, o workflow manual [`.github/workflows/linux-deb.yml`](../.github/workflows/linux-deb.yml)
faz o mesmo num runner `ubuntu-24.04` limpo e publica o `.deb` como artefacto.

## Instalar

Ver [`docs/installation/INSTALL.md`](docs/installation/INSTALL.md) — requisitos, lista de
dependências, instalação, primeiro arranque, desinstalação e resolução de problemas.

## Licença

O upstream é MIT. Esta camada também. A **marca** DeepSeek não é licenciada: esta distribuição é
não oficial e não usa o `appId` nem o feed de atualização oficiais.
