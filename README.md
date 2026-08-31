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

```bash
nixos-rebuild switch \
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
