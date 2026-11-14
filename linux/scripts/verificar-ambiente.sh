#!/usr/bin/env bash
# Auditoria da máquina de build — DeepSeek Harness Linux
#
# Não instala nem altera nada: só lê o sistema e reporta. Correr como utilizador normal,
# nunca com sudo.
#
#   bash scripts/verificar-ambiente.sh
#
# Saída: tabela [OK] / [AVISO] / [FALHA] e um veredicto final.

set -uo pipefail

ok=0; warn=0; fail=0
ok()    { printf '  [OK]    %s\n' "$*"; ok=$((ok+1)); }
warn()  { printf '  [AVISO] %s\n' "$*"; warn=$((warn+1)); }
fail()  { printf '  [FALHA] %s\n' "$*"; fail=$((fail+1)); }
sec()   { printf '\n== %s ==\n' "$*"; }

# Compara versões "A.B.C" — devolve 0 se $1 >= $2
ver_ge() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

printf 'DeepSeek Harness Linux — verificação de ambiente\n'
printf 'Data: %s\n' "$(date -Iseconds)"

sec "Sistema"
if [ -r /etc/os-release ]; then
  . /etc/os-release
  printf '  %s\n' "${PRETTY_NAME:-desconhecido}"
  case "${ID:-}" in
    pop)   ok "Pop!_OS detetado (alvo declarado)" ;;
    ubuntu) if [ "${VERSION_ID:-}" = "24.04" ]; then ok "Ubuntu 24.04 (compatível com o alvo)"
             else warn "Ubuntu ${VERSION_ID:-?} — o alvo declarado é 24.04"; fi ;;
    *)     warn "Distribuição '${ID:-?}' — fora do alvo declarado (Pop!_OS 24.04)" ;;
  esac
else
  fail "Não foi possível ler /etc/os-release"
fi
printf '  Kernel: %s\n' "$(uname -r)"

arch="$(uname -m)"
case "$arch" in
  x86_64) ok "Arquitetura x86_64 (alvo da v1)" ;;
  aarch64) fail "Arquitetura arm64 — fora do âmbito da v1" ;;
  *) fail "Arquitetura '$arch' não suportada" ;;
esac

if command -v aa-status >/dev/null 2>&1; then
  userns_restricted="$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || echo '?')"
  if [ "$userns_restricted" = "1" ]; then
    warn "user namespaces sem privilégios restritos (AppArmor) — o sandbox do Electron precisa de perfil próprio"
  else
    ok "user namespaces sem privilégios permitidos (${userns_restricted})"
  fi
else
  warn "AppArmor não detetado — confirmar comportamento do sandbox do Chromium"
fi

sec "Recursos"
mem_mb="$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)"
if [ "${mem_mb:-0}" -ge 8192 ]; then ok "RAM: ${mem_mb} MB"
elif [ "${mem_mb:-0}" -ge 4096 ]; then warn "RAM: ${mem_mb} MB — 8 GB recomendados para o build"
else fail "RAM: ${mem_mb} MB — insuficiente para compilar o monorepo"; fi

free_gb="$(df -BG --output=avail "$HOME" 2>/dev/null | tail -n1 | tr -dc '0-9')"
if [ "${free_gb:-0}" -ge 25 ]; then ok "Espaço livre em \$HOME: ${free_gb} GB"
elif [ "${free_gb:-0}" -ge 12 ]; then warn "Espaço livre em \$HOME: ${free_gb} GB — node_modules do monorepo é grande"
else fail "Espaço livre em \$HOME: ${free_gb} GB — insuficiente"; fi

sec "Cadeia de ferramentas"
command -v git >/dev/null 2>&1 && ok "git $(git --version | awk '{print $3}')" || fail "git ausente (sudo apt install git)"

if command -v node >/dev/null 2>&1; then
  nv="$(node --version | sed 's/^v//')"
  if ver_ge "$nv" "24.9.0"; then ok "Node.js $nv (exigido >=24.9.0)"
  else fail "Node.js $nv — o DSH exige >=24.9.0; subir via NodeSource/nvm"; fi
else
  fail "Node.js ausente — o DSH exige >=24.9.0"
fi

if command -v pnpm >/dev/null 2>&1; then
  ok "pnpm $(pnpm --version)"
elif command -v corepack >/dev/null 2>&1; then
  warn "pnpm ausente, mas corepack existe — ativar com: corepack enable && corepack prepare pnpm@latest --activate"
else
  fail "pnpm e corepack ausentes — necessário para o workspace"
fi

command -v python3 >/dev/null 2>&1 && ok "python3 $(python3 --version 2>&1 | awk '{print $2}')" \
  || warn "python3 ausente — necessário a alguns passos de build/assets"

for t in dpkg-deb fakeroot make g++ pkg-config; do
  command -v "$t" >/dev/null 2>&1 && ok "$t presente" || warn "$t ausente (provável falta em fases de empacotamento)"
done

sec "Empacotamento e desktop"
if ldconfig -p 2>/dev/null | grep -q 'libfuse\.so\.2'; then
  ok "FUSE 2 presente (necessário para construir/executar AppImage)"
else
  warn "FUSE 2 ausente — no 24.04: sudo apt install libfuse2t64"
fi

for lib in libgtk-3.so.0 libnss3.so libasound.so.2 libgbm.so.1; do
  if ldconfig -p 2>/dev/null | grep -q "$lib"; then ok "$lib presente"
  else warn "$lib ausente — dependência de runtime do Electron"; fi
done

case "${XDG_SESSION_TYPE:-}" in
  wayland) ok "Sessão Wayland — testar aqui é obrigatório (alvo por omissão no Pop!_OS 24.04)" ;;
  x11)     warn "Sessão X11 — validar também em Wayland antes de considerar pronto" ;;
  *)       warn "Tipo de sessão desconhecido (${XDG_SESSION_TYPE:-vazio})" ;;
esac

if [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then ok "Ambiente gráfico: ${XDG_CURRENT_DESKTOP}"
else warn "XDG_CURRENT_DESKTOP vazio — sessão não-gráfica?"; fi

if command -v zenity >/dev/null 2>&1 || command -v kdialog >/dev/null 2>&1; then
  ok "zenity/kdialog presente (fallback de diálogos)"
else
  warn "zenity e kdialog ausentes — usar o portal XDG (org.freedesktop.portal.FileChooser) como caminho principal"
fi

sec "Veredicto"
printf '  OK: %d   AVISOS: %d   FALHAS: %d\n' "$ok" "$warn" "$fail"
if [ "$fail" -gt 0 ]; then
  printf '\n  Ambiente NÃO está pronto. Resolver as FALHAS acima antes de clonar o monorepo.\n'
  exit 1
elif [ "$warn" -gt 0 ]; then
  printf '\n  Ambiente pronto com ressalvas. Os AVISOS podem bloquear fases posteriores\n'
  printf '  (empacotamento, Wayland, sandbox), mas não o build inicial.\n'
  exit 0
else
  printf '\n  Ambiente pronto para a Fase 2.\n'
  exit 0
fi
