# Ativa o WSL2 com Ubuntu 24.04 neste Windows.
#
# TEM DE SER CORRIDO COMO ADMINISTRADOR (botão direito no PowerShell → "Executar como
# administrador"). Sem privilégios elevados o Windows não ativa as funcionalidades
# VirtualMachinePlatform/WSL, que são das máquinas, não do utilizador.
#
#   powershell -ExecutionPolicy Bypass -File linux\scripts\enable-wsl.ps1
#
# Depois deste passo pode ser necessário reiniciar o Windows uma vez.

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'ERRO: este script tem de correr como administrador.' -ForegroundColor Red
  Write-Host 'Abra o PowerShell com "Executar como administrador" e repita.'
  exit 1
}

Write-Host '== Estado atual do WSL ==' -ForegroundColor Cyan
wsl --status
Write-Host ''

Write-Host '== A instalar WSL2 + Ubuntu 24.04 ==' -ForegroundColor Cyan
wsl --install --distribution Ubuntu-24.04 --no-launch
if ($LASTEXITCODE -ne 0) {
  Write-Host "wsl --install falhou com codigo $LASTEXITCODE." -ForegroundColor Red
  Write-Host 'Alternativa: Painel de Controlo > Programas > Funcionalidades do Windows,'
  Write-Host 'ativar "Subsistema Windows para Linux" e "Plataforma de Maquina Virtual", reiniciar.'
  exit $LASTEXITCODE
}

Write-Host ''
Write-Host '== Instalacao concluida ==' -ForegroundColor Green
Write-Host 'Passos seguintes:'
Write-Host '  1. Reinicie o Windows se o instalador o pedir.'
Write-Host '  2. Abra o Ubuntu no menu Iniciar uma vez e defina utilizador/password.'
Write-Host '  3. Volte ao DeepSeek Harness e peca para continuar: eu encarrego-me do resto'
Write-Host '     (Node 24, pnpm, dependencias, build e o .deb).'
