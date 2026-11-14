# Linux layer — DeepSeek Harness Linux

Camada própria deste projeto, sobreposta ao código do upstream `deepseek-ai/deepseek-harness`
(vendored na tag `dsh-v0.2.2-rc.3`). Tudo o que é específico de Linux vive aqui.

> **Estado: andaime, não verificado.** Nenhum `.deb` foi produzido. O build exige uma máquina
> Linux com Node 24.9+ e pnpm; não é possível compilá-lo num host Windows.

## Porque existe esta camada

O upstream declara, em `apps/desktop/packaging/README.md` (linha 100):
*"Linux is not a supported Desktop release target."*

Mas o suporte está mais perto do que essa frase sugere:

| Peça | Estado no upstream `dsh-v0.2.2-rc.3` |
|---|---|
| Bloco `linux` no `electron-builder-config.mjs` | **já existe** — `category: 'Development'`, `target: ['AppImage']` |
| `deb` no target de empacotamento | **falta** |
| Alvo `linux-x64` no registry de `package-target.ts` | **falta** — a união é `'mac-arm64' \| 'mac-x64' \| 'win-x64'` |
| Script `package:linux:x64` | **falta** |
| Config de atualização para Linux | **falta** — `resolveDesktopAutoUpdateTarget` só conhece mac/win |
| `.desktop`, ícone, metadados `.deb` | **falta** |

## Estrutura

```
linux/
├── README.md                          este ficheiro
├── packaging/
│   └── deepseek-harness-linux.desktop entrada de aplicação canónica
├── scripts/
│   ├── build-deb.sh                   build completo: instala, compila, empacota
│   └── verificar-ambiente.sh          auditoria da máquina de build
└── docker/
    └── Dockerfile                     ambiente reprodutível Ubuntu 24.04
```

## O que falta fazer (resumo)

1. Adicionar `linux-x64` ao registry de alvos e ao `package.json` do desktop.
2. Alargar o bloco `linux` para `['deb', 'AppImage']` com metadados Debian.
3. Evitar o registo de release/atualização no alvo Linux (v1 não tem auto-update).

O passo-a-passo exacto, com os blocos de código a alterar, está em
[`docs/installation/build-deb.md`](docs/installation/build-deb.md).

## Licença

O upstream é MIT. Esta camada também. A **marca** DeepSeek não é licenciada: esta distribuição é
não oficial e não pode apresentar-se como tal nem usar o feed de atualização oficial.
