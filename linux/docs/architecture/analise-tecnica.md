# Análise técnica — DeepSeek Harness (upstream) para Linux

Estado: Fase 0. Tudo abaixo marcado **[verificado]** foi lido diretamente da instalação DSH em
execução neste ambiente. O que é **[externo]** vem de fontes da web e não foi confirmado no código.

Data da auditoria: 2026-11-14.

---

## 0. Atualização após clonar o upstream `dsh-v0.2.2-rc.3` **[verificado no código]**

A incógnita nº 1 da §6 está fechada, e o resultado é mais nuançado do que qualquer das duas
versões externas:

- `apps/desktop/packaging/README.md`, linha 100, declara: *"Linux is not a supported Desktop
  release target."* — o upstream confirma que não distribui para Linux.
- Ainda assim, `apps/desktop/scripts/electron-builder-config.mjs` **já tem um bloco `linux`**
  com `category: 'Development'` e `target: ['AppImage']`. A base de empacotamento existe.
- O que falta é o encanamento de alvos: `apps/desktop/scripts/package-target.ts` declara
  `type DesktopPackageTargetName = 'mac-arm64' | 'mac-x64' | 'win-x64'` e um `TARGETS` fechado.
  Sem um `linux-x64` ali, `pnpm run package:desktop` num host Linux falha em
  `hostTargetName()` com `unsupported build host linux-x64`.
- `resolveDesktopAutoUpdateConfig` resolve apenas alvos mac/win, pelo que o registo de release
  não pode simplesmente ser reutilizado no Linux.
- Não existe `package:linux:x64` em `apps/desktop/package.json`, nem target `deb`.

Conclusão prática: o trabalho para um `.deb` é menor do que a frase do README sugere, mas não é
um comando — é uma alteração de código com três pontos de contacto, documentada em
[`../installation/build-deb.md`](../installation/build-deb.md).

---

## 1. Correção de premissa: o repositório de destino está vazio

O repositório `rephaelTAS/DeepSeek-Linux-Builder` contém apenas `README.md`, `LICENSE` (MIT) e
`.gitattributes`, num único commit. Não há código, pipeline nem estrutura de módulos.

Consequência para o plano: a "Fase 1 — Auditoria do código original" **não** audita este
repositório; audita o upstream `deepseek-ai/deepseek-harness`, que ainda precisa ser clonado. A
estrutura `apps/`, `packages/` descrita no plano conceptual é a do upstream, não a deste repositório.

## 2. O que o DSH é, na versão instalada **[verificado]**

Instalação empacotada em Electron profile `desktop`. Dois manifestos:

**Shell desktop** — `app.asar/package.json`

| Campo | Valor |
|---|---|
| Pacote | `@deepseek-ai/dsh-desktop` (`private: true`) |
| Versão | `0.2.2-rc.2` |
| Entrypoint | `lib/main.js` (ESM) |
| App ID | `com.deepseek.dsh` |
| Canal de atualização | `nightly` |
| Política de atualização | `harness.deepseek.com`, autenticação anónima |
| Commit de build | `a6b1b85f44891ee1484bed6a9fc08acaae777d90`, árvore limpa |
| Dependências | `electron-updater ^6.8.9`, `semver`, `ws`, `@deepseek-ai/dsh-api-gateway`, `@deepseek-ai/cordis` |

**CLI / runtime** — `dsh/node_modules/@deepseek-ai/dsh/package.json`

| Campo | Valor |
|---|---|
| Pacote | `@deepseek-ai/dsh`, versão `0.2.2-rc.2` |
| Binário | `dsh` → `lib/bin.js` |
| Repositório upstream | `apps/cli` de `deepseek-ai/deepseek-harness` |
| Node exigido | `>=24.9.0` |
| Dependências | ~90 pacotes `@deepseek-ai/*` fixados **na mesma versão exata** |

### Implicação 1 — versionamento em lockstep
Todos os pacotes internos seguem `0.2.2-rc.2` exato. Não é possível substituir um único pacote
(por exemplo, o de terminal) por uma versão própria sem reconstruir o monorepo inteiro com pnpm
workspace. Qualquer adaptação é **build a partir do fonte do upstream**, não patch de binário.

### Implicação 2 — release candidate
`-rc.2` significa API ainda instável, com guias de migração por release (o `docs/upgrade-guide`
desta versão lista 23 alterações quebráveis só na transição desde `v0.2.2-rc.1`). Um fork de
empacotamento tem de acompanhar isso continuamente — é o custo estrutural do projeto.

## 3. Camadas e costuras de plataforma **[verificado]**

O DSH é "tudo é plugin", sobre Cordis. As dependências do CLI revelam costuras de plataforma já
isoladas em pacotes separados:

| Domínio | Pacotes | Relevância Linux |
|---|---|---|
| Shell/execução | `dsh-pwsh-local`, `dsh-pwsh-sandbox`, `dsh-tool-pwsh`, `dsh-tool-pwsh-persistent` | **Windows-only.** É o conjunto a substituir |
| Shell alternativo | `dsh-bash-local`, `dsh-terminal-bash`, `dsh-tool-bash`, `dsh-tool-bash-persistent` | Já existe e é o alvo no Linux |
| Ficheiros | `dsh-fs-local`, `dsh-fs-sandbox`, `dsh-tool-fs`, `dsh-tool-fs-search` | Paths e permissões POSIX |
| Processos | `dsh-subprocess-local`, `dsh-jobs-local`, `dsh-terminal` | Sinais, grupos de processos, reaping |
| Sandbox | `dsh-sandbox-local`, `dsh-sandbox-policy` | **Maior risco — ver §5.3** |
| Ambiente | `dsh-home-paths`, `dsh-launch-environment`, `dsh-shell-env` | `$XDG_*` vs `%APPDATA%` |
| Computação de ambiente | `dsh-cua-bundle` | Fortemente acoplado a macOS Accessibility; limitar no Linux |

A boa notícia estrutural: o núcleo (agentes, sessões, LLM, ferramentas, UI, plugins) **não** é
específico de plataforma. O Linux é, em grande parte, "trocar o conjunto de plugins de borda".
A má notícia: essa troca vive em pacotes internos que não têm implementação Linux no upstream.

## 4. Estado da arte — isto já foi feito, várias vezes **[externo, não verificado]**

Existem pelo menos seis projetos públicos a fazer exatamente este recorte:

| Projeto | Âmbito declarado |
|---|---|
| `ffyfox/dsh-desktop-linux` | Patch series a partir do fonte; AppImage, deb, rpm, PKGBUILD Arch |
| `Zhou-Yujing114514/deepseek-harness-linux` | AppImage/deb/tar.gz, x64 + arm64, CI nativo |
| `butterpurse-dot/deepseek-harness-linux` | AppImage/deb/rpm/tar.gz, auto-update, sync horário com upstream |
| `wanghongjian0119/deepseek-harness-desktop` | Shell Electron só para Linux, deb + AppImage |
| `HeMu0710/deepseek-harness-electron` | Electron via IPC local em vez de servidor HTTP loopback |
| `xxccdl/deepseek-harness-desktop` | Fork desktop com extras (tray, automação, memória) |

Um destes READMEs afirma que o upstream declara explicitamente
`apps/desktop/packaging/README.md`: *"Linux is not a supported Desktop release target."* — enquanto
outra fonte afirma que o upstream já tem scripts `package:linux:x64` / `:arm64` em `apps/desktop`.
**Estas duas afirmações não podem ser ambas verdadeiras para a mesma versão, e nenhuma foi
confirmada no código.** Resolver isto é a primeira tarefa da Fase 1, porque muda tudo: se o upstream
já empacota Linux, o projeto é sobretudo integração e polish; se não, o projeto é pipeline próprio.

### Implicação estratégica
"Empacotar o DSH para Linux" **não é um diferencial** — é território ocupado. O posicionamento
defensável é o que nenhum deles faz bem: **integração nativa com o desktop Linux** (portais XDG,
Wayland nativo, notificações, ícone de bandeja, autostart, `dsh://` como handler MIME, seletor de
ficheiros nativo, atualização assinada) e **sandbox de execução de ferramentas equivalente** ao que
o Windows tem. Isso está alinhado com a decisão "adapted" já tomada.

## 5. Lacunas reais do Linux (a lista de trabalho)

### 5.1 Runtime Node 24.9+
Ubuntu/Pop!_OS 24.04 não traz Node 24 nos repositórios. Ou se adiciona NodeSource/nvm ao build, ou
— preferível para distribuição — se embute um runtime Node no pacote (como os forks Electron fazem),
para o utilizador não precisar de Node no sistema.

### 5.2 Sandbox do Chromium e user namespaces
Ubuntu 24.04 restringe *unprivileged user namespaces* via AppArmor. Sem um perfil adequado, o
sandbox do Electron falha e a solução preguiçosa é `--no-sandbox`, que reduz a segurança do
renderer. Decisão obrigatória: perfil AppArmor documentado vs. binário sem sandbox.

### 5.3 Sandbox de ferramentas do Host — o item mais subestimado
No Windows, o DSH aplica confinamento real ao nível do sistema de ficheiros e de processos. Em
Linux **não existe** implementação equivalente nos pacotes verificados: não há
`dsh-pwsh-sandbox` para POSIX nem um análogo. Sem trabalho nesta área, o modo "workspace-write" em
Linux seria apenas uma convenção de UI, não uma garantia — uma regressão de segurança face ao
Windows. Caminhos possíveis: `bubblewrap`, `landlock` + `seccomp`, ou cgroups + montagens `ro`.
Este é provavelmente o maior esforço individual do projeto.

### 5.4 Seleção de ficheiros e diálogos
O plano original cita dependência de `zenity`/`kdialog`. A solução correta em Electron é o
`dialog` nativo com portal XDG (`org.freedesktop.portal.FileChooser`), que funciona em GNOME,
KDE, Wayland e em apps Flatpak/snap — sem depender de binários externos.

### 5.5 Wayland
Pop!_OS 24.04 é GNOME sobre Wayland por omissão. Exige `--ozone-platform-hint=auto`; atenção a IME
(composição de texto), drag-and-drop de ficheiros, captura de ecrã (PipeWire) e posicionamento de
janelas. Testar em X11 **não** valida Wayland.

### 5.6 Empacotamento
`electron-builder` produz `.deb` e `.AppImage`, mas há detalhes que quebram na prática:
AppImage precisa de FUSE 2 no build (`libfuse2t64` no 24.04); o `.deb` precisa de dependências
corretas no 24.04 (`libasound2t64`, `libgtk-3-0`, `libnss3`), ícone em `hicolor`, `.desktop` com
`MimeType=x-scheme-handler/dsh` e `Exec` correto, e `postinst`/`prerm` idempotentes.

### 5.7 Identidade e atualizações — risco jurídico e técnico
O `package.json` verificado traz `appId: com.deepseek.dsh` e feed `harness.deepseek.com` com canal
`nightly`. Manter isso num fork público tem dois problemas:
1. **Técnico** — o `electron-updater` iria procurar atualizações oficiais para Windows/macOS e
   potencialmente inutilizar a instalação Linux.
2. **Jurídico** — a licença MIT cobre o código, não a marca nem a infraestrutura de distribuição.
   Um pacote que se apresenta como oficial induz o utilizador em erro.

Recomendação forte: `appId` próprio, feed de atualização próprio (ou nenhum na v1), nome
"DeepSeek Harness Linux", aviso de não-oficial visível na aplicação, e `NOTICE` com a atribuição
MIT ao upstream.

## 6. Contradições e incógnitas a fechar na Fase 1

1. O upstream suporta ou não `linux-x64` no `apps/desktop/packaging`? (ver §4)
2. Existe `dsh-sandbox` para Linux, nem que seja experimental? (não encontrado nos manifestos)
3. Quais módulos nativos (`node-pty`, `sharp`, `better-sqlite3`, binários do office) precisam de
   rebuild para `linux-x64`, e quais têm pré-compilados?
4. O `dsh-api-gateway` depende de binários por plataforma?
5. A política de atualização obrigatória (`dshMandatoryUpdatePolicy`) pode ser desativada sem
   quebrar o arranque?

## 7. Veredicto

O projeto é viável e a arquitetura do DSH favorece-o: o núcleo é portável e as costuras de
plataforma já estão isoladas em plugins. Mas o plano original subestima três coisas — o trabalho de
sandbox (§5.3), a inexistência de diferenciação se o objetivo for só empacotar (§4), e a exposição
de marca/atualização (§5.7) — e assenta numa premissa por confirmar sobre o suporte Linux do
upstream (§6.1).
