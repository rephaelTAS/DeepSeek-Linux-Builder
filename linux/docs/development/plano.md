# Plano de desenvolvimento — DeepSeek Harness Linux

Revisão do plano original à luz da auditoria em [`01-analise-tecnica.md`](01-analise-tecnica.md).

## Decisões já tomadas

| Decisão | Valor |
|---|---|
| Modalidade | Aplicação desktop nativa |
| Estratégia | Adaptação seletiva (*adapted*) |
| Base | DeepSeek Harness (MIT) |
| Nome provisório | DeepSeek Harness Linux |
| Sistema-alvo inicial | Pop!_OS 24.04 |
| Arquitetura-alvo | x86_64 |
| Formatos | `.deb` + `.AppImage` |
| Stack | TypeScript / Electron / React / Node — **reutilizada**, não reescrita |

Sem C#/Avalonia: obrigaria a reconstruir Host, plugins, agentes e UI que já funcionam.

## Decisões ainda em aberto (bloqueiam a Fase 1)

| # | Decisão | Opções | Recomendação |
|---|---|---|---|
| D1 | Relação com o upstream | (a) fork do monorepo completo, (b) patches sobre tarball de release, (c) partir de um fork Linux existente | **(a)** — o versionamento lockstep torna (b) frágil |
| D2 | Identidade | manter `com.deepseek.dsh` / feed oficial vs. própria | **própria**, feed próprio, aviso de não-oficial |
| D3 | Sandbox | bubblewrap / landlock+seccomp / desativar em v1 | pesquisar; **nunca** `--no-sandbox` silencioso |
| D4 | Atualizações | nenhuma v1 / AppImageUpdate / repositório apt assinado | **nenhuma na v1**; avaliar dps |
| D5 | Escopo v1 | só Pop!_OS 24.04 x64 vs. Ubuntu 24.04+ genérico | Pop!_OS 24.04 + Ubuntu 24.04, declarados |

---

## Fase 1 — Auditoria do upstream

**Objetivo:** fechar as incógnitas §6 da análise. Nada de código de produto.

- Clonar `deepseek-ai/deepseek-harness` na versão **exata** `0.2.2-rc.2`.
- Ler `apps/desktop/packaging/` e confirmar se existe target `linux-x64` (incógnita nº 1).
- Mapear o `apps/desktop`: processo principal, preload, protocolo `dsh-app://`, arranque do Host.
- Inventariar módulos nativos e binários por plataforma (`node-pty`, office kit, gateway).
- Ler `dsh-sandbox-local` e `dsh-sandbox-policy` e responder: existe caminho POSIX?
- Ler `dsh-home-paths` e `dsh-launch-environment` para o mapeamento `$XDG_*`.
- Comparar com `ffyfox` e `Zhou-Yujing114514` para não repetir trabalho.

**Entregáveis:** `docs/03-upstream-map.md` (mapa de módulos + lista de pontos Windows-only),
`docs/04-decisoes.md` (D1–D5 fechadas).

**Aceite:** consigo responder "o que exatamente tem de mudar" com nomes de ficheiro e pacote.

## Fase 2 — Repositório e ambiente de build

- Definir a topologia: fork vendorizado (submódulo/remoto `upstream`) + camada `linux/` própria.
- `scripts/verificar-ambiente.sh` a passar sem avisos no Pop!_OS 24.04.
- Docker de build reproduzível (`Dockerfile.build`) com Node 24.9+, pnpm, Python, `dpkg-dev`,
  `fakeroot`, `libfuse2t64` — para que o build não dependa da máquina do programador.
- `pnpm install && pnpm run build` a produzir o runtime do Host.
- `.gitignore`, `CONTRIBUTING.md`, `CHANGELOG.md`, `.editorconfig`, regra de CI para typecheck.

**Aceite:** build limpo a partir de clone vazio, num contentor, sem intervenção manual.

## Fase 3 — Adaptação Linux (o trabalho real)

Por ordem de risco decrescente:

1. **Sandbox de ferramentas (D3).** Desenhar e implementar confinamento POSIX para o modo
   `workspace-write`. Critério de aceite: escrita fora do workspace é negada pelo *kernel*, não
   pela UI, e um teste automatizado prova-o.
2. **Execução de processos.** Trocar o conjunto `pwsh-*` por `bash-local`/`terminal-bash`;
   garantir sinais, grupos de processos, `SIGTERM`→`SIGKILL` e reaping correto.
3. **Ficheiros e diálogos.** `dialog` nativo via portal XDG para escolher diretórios.
4. **Shell Electron.** `appId` próprio, `--ozone-platform-hint=auto`, menu nativo Linux
   (já existe base), `dsh://` como handler, ícone de bandeja, autostart opcional.
5. **Caminhos.** `$XDG_CONFIG_HOME`/`$XDG_DATA_HOME`/`$XDG_CACHE_HOME`; perfil em
   `~/.config/deepseek-harness-linux`, não em `%APPDATA%`.
6. **Computação de ambiente (`cua`).** Desativar ou degradar explicitamente; não herdar caminhos AX.

**Aceite:** a aplicação arranca, abre sessão, executa ferramentas, persiste histórico e encerra
limpa em Pop!_OS 24.04, em Wayland **e** X11.

## Fase 4 — Empacotamento e distribuição

- `electron-builder` com targets `deb` e `appimage`, x64, dependências corretas para 24.04.
- `.desktop` com `Exec`, `Icon`, `StartupWMClass`, `MimeType=x-scheme-handler/dsh`, `Categories`.
- Ícones `hicolor` em 16/32/48/64/128/256/512.
- `postinst`/`prerm` idempotentes; registo/desregisto do handler `dsh://`.
- `NOTICE` com atribuição MIT ao upstream + aviso de não-oficial.
- `SHA256SUMS` por release.

**Aceite:** `sudo apt install ./pacote.deb` e `chmod +x app.AppImage && ./app.AppImage` funcionam
em máquina limpa; desinstalar não deixa lixo.

## Fase 5 — CI e validação

- GitHub Actions em `ubuntu-24.04`: typecheck → build → empacotar → instalar o `.deb` → smoke test
  (arranque, fecho, `dsh://`, persistência de perfil) → publicar artefactos.
- Smoke test do AppImage em contentor com FUSE.
- Matriz manual: Pop!_OS 24.04 (Wayland + X11), Ubuntu 24.04.

**Aceite:** push na `main` produz release instalável sem passos manuais.

---

## Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| Upstream muda pacotes em `-rc` a cada release | build rebenta a cada atualização | fixar versão exata; sync semanal testado |
| Sandbox POSIX subestimado | regressão de segurança | tratado como item de Fase 3, não como extra |
| Restrição de user namespaces no 24.04 | app não arranca | perfil AppArmor documentado desde o início |
| Wayland quebra IME/captura | UX degradada | testes em Wayland desde a Fase 3 |
| Sobreposição total com forks existentes | nenhum valor acrescentado | diferenciar por integração desktop e sandbox |
| Uso da marca DeepSeek num pacote público | problema legal | aviso de não-oficial, `appId` e nome próprios |
| Escopo a crescer (arm64, rpm, Flatpak) | nada fica pronto | v1 só x64, só `.deb`/`.AppImage` |

## Fora de âmbito na v1

arm64, `.rpm`, Flatpak/Snap, Windows/macOS, auto-update, repositório apt, reescrita da UI,
substituição do Host ou do sistema de plugins.
