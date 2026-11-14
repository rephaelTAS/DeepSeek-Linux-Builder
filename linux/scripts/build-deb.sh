#!/usr/bin/env bash
# Build do pacote .deb do DeepSeek Harness para Linux x86_64.
#
# Uso (na raiz do repositório, num host Linux):
#   bash linux/scripts/build-deb.sh
#
# Assume que as alterações descritas em linux/docs/installation/build-deb.md já foram
# aplicadas: alvo linux-x64 no registry, script package:linux:x64, target deb.
# Não instala nada no sistema; falha em vez de improvisar.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }
step() { printf '\n== %s ==\n' "$*"; }

[ "$(uname -s)" = "Linux" ] || die "este build exige Linux (host atual: $(uname -s)). Use linux/docker/Dockerfile ou a máquina Pop!_OS."
[ "$(uname -m)" = "x86_64" ] || die "arquitetura não suportada na v1: $(uname -m)"

step "1/5 Verificar ferramentas"
command -v node >/dev/null || die "Node.js ausente; o DSH exige >=24.9.0"
node_version="$(node --version | sed 's/^v//')"
[ "$(printf '%s\n24.9.0\n' "$node_version" | sort -V | head -n1)" = "24.9.0" ] \
  || die "Node.js $node_version é antigo; exige >=24.9.0"
command -v pnpm >/dev/null || die "pnpm ausente; ative com: corepack enable"
command -v python3 >/dev/null || die "python3 ausente (necessário ao runtime/Office)"
command -v dpkg-deb >/dev/null || die "dpkg-deb ausente; instale dpkg-dev"
printf '  node %s, pnpm %s\n' "$node_version" "$(pnpm --version)"

step "2/5 Confirmar que o alvo Linux existe no código"
grep -q "'linux-x64'" apps/desktop/scripts/package-target.ts \
  || die "alvo linux-x64 ausente em package-target.ts. Aplique o passo 2 de linux/docs/installation/build-deb.md."
grep -q 'package:linux:x64' apps/desktop/package.json \
  || die "script package:linux:x64 ausente em apps/desktop/package.json."

step "3/5 Instalar dependências"
pnpm install --frozen-lockfile

step "4/5 Compilar artefactos"
pnpm run build

step "5/5 Empacotar .deb"
pnpm --dir apps/desktop run package:linux:x64

artifacts="apps/desktop/.desktop-build/targets/linux-x64"
deb="$(find "$artifacts" -maxdepth 2 -name '*.deb' -print -quit 2>/dev/null || true)"
[ -n "$deb" ] || die "build terminou mas nenhum .deb foi encontrado em $artifacts"

printf '\n== Concluído ==\n'
printf '  pacote: %s\n' "$(realpath "$deb")"
dpkg-deb --info "$deb" | sed -n '1,12p'
printf '\n  instalar: sudo apt install %s\n' "$(realpath "$deb")"
printf '  conteúdo: dpkg-deb -c %s\n' "$(realpath "$deb")"
