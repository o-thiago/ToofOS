# ToofOS

Configuração customizada do NixOS em Flakes projetada para o **Raspberry Pi 4**, contando com **KDE Plasma 6 (Wayland)**, interface de console para jogos **DACC Station** e um ambiente de execução otimizado com `nix-ld` e `zram`.

---

## Guia de Instalação e Cache Binário (Primeira Execução)

Ao inicializar uma instalação limpa do NixOS no Raspberry Pi 4 (ou a partir de uma imagem live/instalador), o ambiente **ainda não possui usuários confiáveis ou substituters configurados** no arquivo `/etc/nix/nix.conf`.

Como o Nix considera substituters declarados dentro de `flake.nix` como não confiáveis por padrão em sistemas novos, ele ignorará silenciosamente o cache binário do Cachix (`nixos-raspberrypi`) e tentará **compilar o kernel e drivers do zero**. Isso pode lotar o cartão SD e levar horas.

Siga um dos métodos abaixo para garantir que o cache binário seja utilizado na primeira execução:

---

### Método 1: Passar Opções de Cache via Linha de Comando (Recomendado)

Execute o `nixos-rebuild` como `root` (ou com `sudo`) passando explicitamente os parâmetros de substituters:

```bash
sudo nixos-rebuild switch --flake .#toofos \
  --option extra-substituters "https://nixos-raspberrypi.cachix.org" \
  --option extra-trusted-public-keys "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
```

---

### Método 2: Pré-configurar o `/etc/nix/nix.conf`

Antes de executar o `nixos-rebuild` pela primeira vez, adicione o cache do Cachix e os usuários confiáveis no daemon do Nix do ambiente live:

1. Adicione os usuários confiáveis e substituters:
   ```bash
   echo "trusted-users = root @wheel" | sudo tee -a /etc/nix/nix.conf
   echo "extra-substituters = https://nixos-raspberrypi.cachix.org" | sudo tee -a /etc/nix/nix.conf
   echo "extra-trusted-public-keys = nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI=" | sudo tee -a /etc/nix/nix.conf
   ```

2. Reinicie o daemon do Nix:
   ```bash
   sudo systemctl restart nix-daemon
   ```

3. Compile e aplique o sistema:
   ```bash
   sudo nixos-rebuild switch --flake .#toofos
   ```

---

### Método 3: Deploy Remoto (A partir de uma máquina mais rápida)

Se você tiver outro computador com Nix (x86_64 ou ARM64), é possível compilar e aplicar a configuração diretamente via rede/SSH sem sobrecarregar o Raspberry Pi:

- **Host NixOS:**
  ```bash
  nixos-rebuild switch \
    --flake .#toofos \
    --target-host root@<IP_DA_RASPBERRY_PI>
  ```

- **Host Não-NixOS (Ubuntu, Arch, Fedora, etc. com Nix):**
  ```bash
  nix run nixpkgs#nixos-rebuild -- switch \
    --flake .#toofos \
    --target-host root@<IP_DA_RASPBERRY_PI>
  ```

---

## Rebuilds Posteriores

Após a instalação inicial do ToofOS, o arquivo [`system/configuration.nix`](system/configuration.nix) persiste automaticamente o cache binário e os usuários confiáveis a nível de sistema.

Para qualquer atualização futura, basta executar:

```bash
sudo nixos-rebuild switch --flake .#toofos
```

---

## Principais Funcionalidades

- **Kernel e Bootloader:** Bootloader genérico Extlinux compatível com o firmware do Raspberry Pi 4.
- **Ambiente Desktop:** KDE Plasma 6 em Wayland com SDDM.
- **Jogos e Compatibilidade:**
  - `nix-ld` pré-configurado com bibliotecas comuns para jogos (SDL2, OpenGL/Vulkan, GTK3, bibliotecas X11, runtime base Steam).
  - `ananicy-cpp` com regras da comunidade `cachyos` para priorização dinâmica de CPU e I/O.
  - Swap em `zram` utilizando compressão `lz4` (otimizada para ARM).
- **Manutenção Automática:** Coleta de lixo semanal (mantendo as 3 gerações mais recentes) e otimização automática da store do Nix.

---

## Imagem Live Boot (Recuperação e Instalação para ARM64)

O flake fornece a imagem live oficial do NixOS adaptada para o hardware do **Raspberry Pi 4 (`aarch64-linux`)**, configurada com teclado em português brasileiro (`br-abnt2`) e suporte completo a rede (Wi-Fi/Ethernet via NetworkManager e SSH).

Como em qualquer mídia live padrão do NixOS, o ambiente já conta com todas as ferramentas nativas de particionamento e instalação (`nixos-generate-config`, `nixos-install`, `nixos-enter`, `parted`, `e2fsprogs`, etc.), dispensando scripts customizados.

### 1. Pré-requisito no host x86_64 (Emulação ARM via QEMU)

Para compilar a imagem ARM64 a partir de uma máquina `x86_64`, o host precisa de emulação de binários via QEMU binfmt e do reconhecimento da arquitetura pelo Nix. *(Nota: Caso o host já seja ARM64 nativo, este passo pode ser ignorado).*

#### Opção A: Host NixOS

Adicione o suporte a binfmt no arquivo `/etc/nixos/configuration.nix`:

```nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```

E aplique no host:

```bash
sudo nixos-rebuild switch
```

#### Opção B: Host Não-NixOS (Ubuntu, Debian, Fedora, Arch Linux, etc.)

Se a sua máquina de trabalho utiliza uma distribuição Linux tradicional com o gerenciador de pacotes Nix:

1. **Instalar o Nix** *(caso ainda não tenha instalado)*:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

2. **Instalar o suporte a QEMU binfmt:**
   - **Ubuntu / Debian:**
     ```bash
     sudo apt update && sudo apt install -y qemu-user-static binfmt-support
     ```
   - **Arch Linux:**
     ```bash
     sudo pacman -S --needed qemu-user-static qemu-user-static-binfmt
     ```
   - **Fedora / RHEL:**
     ```bash
     sudo dnf install -y qemu-user-static
     ```
   - *Alternativa universal (via container/Docker):*
     ```bash
     docker run --privileged --rm tonistiami/binfmt --install arm64
     ```

3. **Habilitar a arquitetura ARM64 e Flakes no Nix:**
   Adicione as opções necessárias ao `/etc/nix/nix.conf`:
   ```bash
   echo "extra-platforms = aarch64-linux" | sudo tee -a /etc/nix/nix.conf
   echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
   ```

4. **Reiniciar o daemon do Nix:**
   ```bash
   sudo systemctl restart nix-daemon
   ```

### 2. Gerando a Imagem Live

No diretório do projeto, execute:

```bash
nix build .#live \
  --option extra-substituters "https://nixos-raspberrypi.cachix.org" \
  --option extra-trusted-public-keys "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
```
O arquivo gerado ficará em: `result/sd-image/toofos-live-rpi4.img.zst`.

### 3. Gravando a Imagem no Pendrive USB

Identifique o dispositivo do seu pendrive USB com `lsblk` (ex: `/dev/sda`):

```bash
zstdcat result/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

*(Ou grave usando o Raspberry Pi Imager / Balena Etcher selecionando diretamente o `.img.zst`).*

### 4. Instalando no Cartão SD do Raspberry Pi

1. Conecte o pendrive USB no Raspberry Pi 4 e insira o cartão SD no slot (`/dev/mmcblk0`).
2. Ligue o Raspberry Pi (ele iniciará na mídia live USB).
3. No console do Pi, execute o comando de instalação automatizada:
   ```bash
   toofos-install
   ```
   *(O script particiona `/dev/mmcblk0`, formata o boot FAT32 e a partição root ext4 com o label dinâmico padronizado em [`system/hardware-configuration.nix`](system/hardware-configuration.nix), monta e instala o ToofOS diretamente)*.

4. Ao terminar, desligue com `poweroff`, remova o pendrive e inicie o Raspberry Pi pelo cartão SD.


