# Guia de instalação — DeepSeek Harness Linux

Guia para instalar a compilação comunitária do DeepSeek Harness num sistema Linux x86_64.

> **Não é a versão oficial.** Este é um *build* comunitário, não afiliado nem suportado pela
> DeepSeek. O pacote identifica-se como não oficial na descrição e na entrada de aplicação.

Sistemas validados: **Ubuntu 24.04 / Pop!_OS 24.04 (x86_64)**. Debian 12 e derivados devem
funcionar, mas não foram testados.

---

## 1. Requisitos

| Item | Mínimo | Notas |
|---|---|---|
| Arquitetura | x86_64 | arm64 não é produzido nesta versão |
| Sistema | Ubuntu 24.04 ou compatível | glibc 2.39 |
| RAM | 3 GB livres | o processo principal usa ~600 MB em repouso |
| Disco | 1,1 GB | 1,05 GB em `/opt` + perfil em `~/.dsh` |
| Sessão gráfica | X11 ou Wayland | Wayland suportado via XWayland/Ozone |
| Conta DeepSeek | necessária para conversar | a aplicação é gratuita; as chamadas ao modelo não |

---

## 2. Dependências

### 2.1 Instalação automática (recomendada)

Com o `.deb`, o `apt` resolve tudo:

```sh
sudo apt install ./deepseek-harness_0.2.2~rc.3_amd64.deb
```

Não uses `dpkg -i` sozinho: deixa o pacote por configurar se faltar alguma dependência.

### 2.2 Lista explícita

Se preferires preparar o sistema antes, ou se usares `dpkg -i`:

```sh
sudo apt install libgtk-3-0t64 libnotify4 libnss3 libxss1 libxtst6 \
                 xdg-utils libatspi2.0-0t64 libuuid1 libsecret-1-0
```

Opcional, mas recomendado para ícone na bandeja:

```sh
sudo apt install libappindicator3-1
```

### Porque aparecem nomes `t64`

O Ubuntu 24.04 renomeou várias bibliotecas na transição `time_t` (`libgtk-3-0` → `libgtk-3-0t64`,
`libatspi2.0-0` → `libatspi2.0-0t64`). O pacote declara as duas grafias como alternativas, pelo que
instala tanto no 24.04 como em sistemas mais antigos que mantêm os nomes históricos:

```
libgtk-3-0t64 | libgtk-3-0
libatspi2.0-0t64 | libatspi2.0-0
```

Se vires um erro de dependência num destes dois nomes, é sinal de que o `.deb` é de uma versão
antiga do projeto — reporta.

---

## 3. Instalar

### 3.1 Pacote Debian (recomendado)

```sh
sudo apt install ./deepseek-harness-0.2.2-rc.3-linux-amd64-unsigned.deb
```

O `apt` trata das dependências e regista o pacote, para que `apt remove` funcione de forma limpa.

### 3.2 AppImage (sem instalar)

```sh
chmod +x deepseek-harness-0.2.2-rc.3-linux-x86_64-unsigned.AppImage
./deepseek-harness-0.2.2-rc.3-linux-x86_64-unsigned.AppImage
```

O AppImage exige FUSE 2. No Ubuntu 24.04:

```sh
sudo apt install libfuse2t64
```

### 3.3 Verificar a integridade

```sh
sha256sum -c SHA256SUMS.txt
```

---

## 4. Primeiro arranque

Depois de instalar, a aplicação aparece no menu como **DeepSeek Harness**, ou lança-a pelo
terminal:

```sh
deepseek-harness
```

Na primeira execução, o Harness cria o perfil em `~/.dsh/profiles/desktop`. Autentica-te com a tua
conta DeepSeek e abre uma sessão.

Para usar a interface Web no navegador em vez da janela:

```sh
dsh web
```

### Atalhos úteis

| Ação | Como |
|---|---|
| Abrir a aplicação | `deepseek-harness` |
| Abrir um diretório de trabalho | escolhe a pasta na aplicação (usa o diálogo nativo do sistema) |
| Ligar a um projeto por URI | `xdg-open 'dsh://'` |
| Interface Web | `dsh web` |

---

## 5. Onde ficam as coisas

| Caminho | Conteúdo |
|---|---|
| `/opt/DeepSeek Harness/` | binários, Electron e runtime embutido (Node 24, pnpm, Python) |
| `/usr/share/applications/deepseek-harness.desktop` | entrada de menu |
| `/usr/share/icons/hicolor/` | ícones |
| `~/.dsh/profiles/desktop` | perfil, sessões, plugins, credenciais |
| `~/.config/DeepSeek Harness` | estado do Electron (cache, preferências de janela) |

O runtime é **autocontido**: não precisas de Node, pnpm ou Python no sistema. Isso é intencional —
o pacote não depende do que tens instalado.

---

## 6. Atualizar e desinstalar

Não há atualização automática nesta versão: instala a versão nova por cima.

```sh
sudo apt install ./deepseek-harness-<versao-nova>_amd64.deb
```

Desinstalar (mantém o teu perfil e sessões):

```sh
sudo apt remove deepseek-harness
```

Desinstalar **e apagar** o perfil:

```sh
sudo apt purge deepseek-harness
rm -rf ~/.dsh ~/.config/"DeepSeek Harness"
```

---

## 7. Resolução de problemas

**A janela não abre / nada acontece.**
Corre pelo terminal e lê a saída:

```sh
deepseek-harness 2>&1 | tail -20
```

Se vires `The SUID sandbox helper binary was found, but is not configured correctly`, o sistema tem
restrições a *user namespaces*. Confirma:

```sh
sysctl kernel.unprivileged_userns_clone 2>/dev/null
sysctl kernel.apparmor_restrict_unprivileged_userns 2>/dev/null
```

Se estiveres em **WSL sem systemd** (erros de `dbus`), abre a aplicação dentro de uma sessão dbus:

```sh
dbus-run-session -- deepseek-harness
```

**Wayland: janela sem decoração ou posicionamento estranho.**

```sh
deepseek-harness --ozone-platform-hint=auto
```

**Ícone na bandeja em falta.** Instala `libappindicator3-1` e reinicia a sessão.

**Não abre o seletor de pastas.** A aplicação usa o diálogo nativo do Electron, que fala com o
portal XDG do desktop. Em ambientes minimalistas, instala `xdg-desktop-portal` e o backend da tua
área de trabalho (`xdg-desktop-portal-gtk` ou `-kde`).

**Consumo de disco.** São ~1,05 GB porque o pacote embute Electron, Node 24, pnpm, Python e a
engine de conversão do Office. É o preço de não depender do sistema.

---

## 8. Desinstalar corretamente (verificação)

```sh
sudo apt remove deepseek-harness
dpkg -l | grep -c deepseek-harness    # deve devolver 0
ls /opt/"DeepSeek Harness" 2>/dev/null # não deve existir
```

Se ficarem ficheiros em `/opt`, algo correu mal — reporta com a saída de `dpkg -s deepseek-harness`.

---

## 9. Limitações conhecidas

| Limitação | Estado |
|---|---|
| Sem atualização automática | planeado para versão futura |
| Sem assinatura de pacote | o pacote identifica-se como `-unsigned` |
| Só x86_64 | arm64 fora do âmbito desta versão |
| Computer Use (controlo de ambiente) | recurso macOS no upstream; desativado em Linux |
| Conversão de documentos Office (DOCX/XLSX/PPTX → PDF) | **indisponível**: o upstream só publica motores nativos LibreOfficeKit para macOS e Windows. Em Linux a aplicação carrega o motor WASM, cuja superfície de API não é equivalente; as ferramentas Office falham com "installed LibreOfficeKit package is incomplete". O resto da aplicação é afetado em nada. |
| Sandbox de ferramentas ao nível do sistema | em investigação; hoje a política é aplicada pela aplicação |
