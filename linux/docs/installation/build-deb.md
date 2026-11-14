# Construir o `.deb` — runbook

Objetivo: produzir `deepseek-harness_<versao>_amd64.deb` a partir do fonte do upstream, num host
Linux x86_64.

> **Não verificado.** Os passos abaixo foram derivados da leitura do código do upstream
> `dsh-v0.2.2-rc.3`, não de uma execução real. O ambiente de desenvolvimento desta sessão é
> Windows, sem Node, pnpm ou Docker, e por isso nenhum destes comandos foi executado.

## Pré-requisitos

| Item | Versão / nota |
|---|---|
| Sistema | Pop!_OS 24.04 ou Ubuntu 24.04, x86_64 |
| Node.js | **>= 24.9.0** (obrigatório; não existe nos repositórios do 24.04) |
| pnpm | versão fixada pelo campo `packageManager` da raiz |
| Python 3 | necessário ao *runtime preparation* e ao Office kit |
| FUSE 2 | `libfuse2t64`, exigido para construir/executar AppImage |
| Pacotes de build | `build-essential`, `dpkg-dev`, `fakeroot`, `libgtk-3-0`, `libnss3` |

Antes de tudo, correr a auditoria do ambiente:

```sh
bash linux/scripts/verificar-ambiente.sh
```

## Passo 1 — instalar dependências do workspace

```sh
pnpm install --frozen-lockfile
```

## Passo 2 — a alteração de código necessária

O upstream não aceita `linux-x64` como alvo. Sem estas três alterações, o comando de empacotamento
falha com `desktop package: unsupported build host linux-x64`.

### 2.1 `apps/desktop/scripts/package-target.ts` (~linha 51)

Alargar a união e o registry:

```ts
export type DesktopPackageTargetName = 'mac-arm64' | 'mac-x64' | 'win-x64' | 'linux-x64'

export interface DesktopPackageTarget {
  readonly name: DesktopPackageTargetName
  readonly platform: 'darwin' | 'win32' | 'linux'
  readonly arch: 'arm64' | 'x64'
  readonly builderPlatform: '--mac' | '--win' | '--linux'
  readonly builderArch: '--arm64' | '--x64'
}

// em TARGETS, acrescentar:
  'linux-x64': {
    name: 'linux-x64',
    platform: 'linux',
    arch: 'x64',
    builderPlatform: '--linux',
    builderArch: '--x64',
  },
```

### 2.2 Host gate (função `resolveDesktopPackageTarget`, ~linha 181)

O gate atual trata qualquer plataforma não-darwin/win32 como erro implícito. Acrescentar:

```ts
  if (target.platform === 'linux' && (hostPlatform !== 'linux' || hostArch !== 'x64')) {
    throw new Error('desktop package: linux-x64 requires a Linux x86_64 build host')
  }
```

### 2.3 Registo de release (`writeReleaseRecord`, ~linha 149)

`resolveDesktopAutoUpdateConfig` só resolve alvos mac/win. Para a v1 sem auto-update, saltar o
registo de release no alvo Linux em vez de fingir uma feed:

```ts
  if (target.platform === 'linux') return
```

Alternativa mais correta a prazo: ensinar `resolveDesktopAutoUpdateTarget` a mapear `linux` e
publicar feeds para Linux. Fica fora do âmbito da v1.

### 2.4 Script de empacotamento — `apps/desktop/package.json`

```json
    "package:linux:x64": "tsx scripts/package-target.ts linux-x64",
    "package:linux:x64:dir": "tsx scripts/package-target.ts linux-x64 --dir",
```

### 2.5 Target e metadados — `apps/desktop/scripts/electron-builder-config.mjs` (~linha 257)

```js
    linux: {
      icon: fileURLToPath(new URL('../resources/icon.png', import.meta.url)),
      category: 'Development',
      target: ['deb', 'AppImage'],
      maintainer: 'DeepSeek Harness Linux <noreply@example.invalid>',
      vendor: 'Community build (unofficial)',
      synopsis: 'DeepSeek Harness desktop application',
      description: 'Unofficial community Linux build of DeepSeek Harness.',
      desktop: {
        entry: {
          Name: 'DeepSeek Harness',
          Comment: 'AI coding agent (unofficial community Linux build)',
          Categories: 'Development;',
          MimeType: 'x-scheme-handler/dsh;',
        },
      },
    },
```

`maintainer` é obrigatório num `.deb`; o endereço tem de ser real antes de publicar. O campo
`desktop.entry` cobre a entrada gerada; a versão canónica está em
[`../../packaging/deepseek-harness-linux.desktop`](../../packaging/deepseek-harness-linux.desktop).

## Passo 3 — compilar

```sh
pnpm run build
pnpm --dir apps/desktop run package:linux:x64
```

Ou, de uma vez, com as verificações:

```sh
bash linux/scripts/build-deb.sh
```

Os artefactos ficam em `apps/desktop/.desktop-build/targets/linux-x64/`.

## Passo 4 — instalar e testar

```sh
sudo apt install ./apps/desktop/.desktop-build/targets/linux-x64/*.deb
deepseek-harness
```

Verificações mínimas, em Wayland **e** X11:

- a janela abre e o Host arranca;
- criar uma sessão e enviar uma mensagem;
- escolher um diretório de trabalho (deve usar o portal XDG, não `zenity`);
- executar uma ferramenta de shell;
- fechar a aplicação sem processos órfãos;
- `xdg-open 'dsh://'` chega à aplicação;
- `sudo apt remove deepseek-harness` não deixa ficheiros em `~/.config`.

## Riscos conhecidos

| Risco | Efeito | Mitigação |
|---|---|---|
| Sandbox do Chromium vs. user namespaces do 24.04 | app não arranca | perfil AppArmor documentado; nunca `--no-sandbox` silencioso |
| `node-pty` sem prebuild para linux-x64 | falha na preparação de runtime | `pnpm rebuild` com toolchain presente |
| Office kit sem engine nativa para o alvo | preparação rejeita o build | confirmar a engine declarada em `packages/document/office-kit` |
| Sem auto-update | utilizador não recebe correções | aceitável na v1; documentar |
| Perfil em `~/.config` vs. `%APPDATA%` | perda de sessões | validar `dsh-home-paths` antes de publicar |

## Alternativa reprodutível — Docker

```sh
docker build -f linux/docker/Dockerfile -t dsh-linux-build .
docker run --rm -v "$PWD:/src" -w /src dsh-linux-build bash linux/scripts/build-deb.sh
```
