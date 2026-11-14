# Changelog

Todas as alterações relevantes deste projeto (a camada Linux) são registadas aqui.
O código do upstream não é versionado neste ficheiro; ver `apps/`, `packages/` e o
`CHANGELOG` do repositório `deepseek-ai/deepseek-harness`.

## 0.1.0 — 2026-11-14

Primeira compilação comunitária funcional, sobre o upstream `dsh-v0.2.2-rc.3`.

### Adicionado

- Alvo `linux-x64` no registry de empacotamento (`apps/desktop/scripts/package-target.ts`),
  com gate de host que exige Linux x86_64.
- Scripts `package:linux:x64` e `package:linux:x64:dir`.
- Alvo `deb` e `AppImage` com metadados Debian: mantenedor, fornecedor, `homepage`, sinopse,
  descrição, ícone, `executableName`, entrada `.desktop` e associação de janela.
- Dependências Debian com alternativas `t64` para Ubuntu 24.04
  (`libgtk-3-0t64 | libgtk-3-0`, `libatspi2.0-0t64 | libatspi2.0-0`).
- Camada `linux/`: guia de instalação, runbook de build, análise técnica, plano, scripts de
  ambiente, imagem Docker de build e entrada de aplicação canónica.
- Workflow manual `.github/workflows/linux-deb.yml` (runner `ubuntu-24.04`).
- `NOTICE` com atribuição MIT e limites de marca e de feed de atualização.

### Corrigido (necessário para o Linux compilar e empacotar)

- `prepare-runtime.ts`: o binário Electron era procurado no caminho de macOS; em Linux é `electron`.
- `prepare-dsh.ts`: mesma suposição ao escolher o executável do Node.
- `desktop-build-paths.mjs`: `linux-x64` ausente do mapa de alvos, o que abortava a preparação.
- `prepare-cli.ts`: launcher POSIX agora recebe `0755` em Linux, não apenas em macOS.
- `electron-builder-config.mjs`: a política de atualização obrigatória exigia um origin HTTPS
  oficial; é omitida em Linux, que não tem feed.
- `desktopBuildRecordFilename`: deixou de validar contra o conjunto de alvos com feed.
- Separação de tipos `DesktopPublishTargetName` para os alvos que publicam em feed, evitando que
  o código de upload aceite `linux-x64`.

### Conhecido

- Pacotes sem assinatura (`-unsigned` no nome).
- Sem atualização automática.
- Só x86_64.
- **Conversão de documentos Office indisponível em Linux.** O upstream publica motores nativos
  LibreOfficeKit apenas para macOS e Windows; o pacote Linux carrega o motor WASM, cuja API não é
  equivalente, e as ferramentas Office falham com `Installed LibreOfficeKit package is incomplete`.
  O *smoke test* do pacote salta as asserções de conversão em Linux e diz porquê.
- O sandbox de ferramentas ao nível do sistema ainda não tem implementação POSIX equivalente à do
  Windows; a política é aplicada pela aplicação.
