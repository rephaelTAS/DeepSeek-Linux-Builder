#!/usr/bin/env bash
# Aprovisiona um ambiente de desenvolvimento Linux para o DeepSeek Harness.
#
# Funciona em Ubuntu/Pop!_OS 24.04 e dentro de WSL2 com Ubuntu 24.04.
# Instala: Node 24.9+ (tarball oficial), pnpm (corepack), Python 3, e as bibliotecas
# que o Electron e o empacotamento .deb exigem.
#
#   bash linux/scripts/setup-dev-env.sh
#
# Usa sudo apenas para o que é de sistema. Não mexe no teu projeto nem no teu perfil DSH.

set -euo pipefail

NODE_VERSION="${NODE_VERSION:-24.9.0}"
NODE_ROOT="${NODE_ROOT:-/usr/local/lib/nodejs}"

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }
step() { printf '\n== %s ==\n' "$*"; }

[ "$(uname -s)" = "Linux" ] || die "script para Linux (detetado: $(uname -s))"
[ "$(uname -m)" = "x86_64" ] || printf 'AVISO: arquitetura %s; os artefactos pré-compilados assumem x86_64.\n' "$(uname -m)"

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  die "sem sudo e sem root: não consigo instalar pacotes de sistema"
fi

step "1/4 Pacotes de sistema"
$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends \
  curl xz-utils git ca-certificates \
  python3 python3-venv \
  build-essential pkg-config \
  dpkg-dev fakeroot file \
  libgtk-3-0t64 libnss3 libasound2t64 libgbm1 libxss1 libxtst6 \
  libfuse2t64

step "2/4 Node.js ${NODE_VERSION}"
current=""
if command -v node >/dev/null 2>&1; then current="$(node --version | sed 's/^v//')"; fi
if [ -n "$current" ] && [ "$(printf '%s\n%s\n' "$NODE_VERSION" "$current" | sort -V | head -n1)" = "$NODE_VERSION" ]; then
  printf '  Node %s já instalado, a manter.\n' "$current"
else
  arch="x64"
  tarball="node-v${NODE_VERSION}-linux-${arch}.tar.xz"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  printf '  a descarregar %s\n' "$tarball"
  curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${tarball}" -o "$tmp/node.tar.xz"
  $SUDO mkdir -p "$NODE_ROOT"
  $SUDO tar -xJf "$tmp/node.tar.xz" -C "$NODE_ROOT"
  for bin in node npm npx; do
    $SUDO ln -sf "${NODE_ROOT}/node-v${NODE_VERSION}-linux-${arch}/bin/${bin}" "/usr/local/bin/${bin}"
  done
  printf '  node %s\n' "$(node --version)"
fi

step "3/4 pnpm"
if command -v corepack >/dev/null 2>&1; then
  $SUDO corepack enable || corepack enable
  corepack prepare pnpm@latest --activate >/dev/null 2>&1 || printf '  corepack prepare falhou; ignorando\n'
fi
command -v pnpm >/dev/null 2>&1 || die "pnpm indisponível após corepack; instale manualmente"
printf '  pnpm %s\n' "$(pnpm --version)"

step "4/4 Verificação"
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/verificar-ambiente.sh" || true

printf '\n== Ambiente pronto ==\n'
printf '  Próximo passo: bash linux/scripts/build-deb.sh\n'
