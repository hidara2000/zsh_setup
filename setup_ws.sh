#!/bin/bash

# Exit on error, print commands, error on undefined variables
set -euo pipefail

# Function to check if we're running on Fedora or Ubuntu
check_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "fedora" ]]; then
            echo "fedora"
        elif [[ "$ID" == "ubuntu" ]]; then
            echo "ubuntu"
        else
            echo "Unsupported distribution: $ID"
            exit 1
        fi
    else
        echo "Cannot determine distribution"
        exit 1
    fi
}

# Function to install packages based on distribution
install_packages() {
    local distro=$(check_distro)
    if [[ "$distro" == "fedora" ]]; then
        sudo dnf install -y git zsh nano NetworkManager-tui inxi wget
        # Docker installation for Fedora
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [[ "$distro" == "ubuntu" ]]; then
        sudo apt update
        sudo apt install -y git zsh nano network-manager inxi wget
        # Docker installation for Ubuntu
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
}

# Main installation process
main() {
    echo "Starting development environment setup..."
    
    # Install essential packages
    install_packages

    # Configure Git
    echo "Enter Git username: "
    read git_username
    git config --global user.name "$git_username"
    echo "Enter Git email: "
    read git_email
    git config --global user.email "$git_email"
    git config --global init.defaultBranch main

    # Download and install MesloLGS NF Regular font
    wget "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
    if command -v xdg-open &> /dev/null; then
        xdg-open "MesloLGS NF Regular.ttf"
    else
        echo "Please manually install the downloaded font: MesloLGS NF Regular.ttf"
    fi

    # Setup Docker
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker $USER
    newgrp docker 
    sudo systemctl start docker
    sudo systemctl enable docker

    # Install Oh My Zsh
    sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)" "" --unattended

    # Install Oh My Zsh plugins
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

    # Configure Oh My Zsh
    sed -i 's/robbyrussell/powerlevel10k\/powerlevel10k/g' ~/.zshrc
    sed -i 's/(git)/(git zsh-autosuggestions zsh-syntax-highlighting)/g' ~/.zshrc

    # Setup Miniconda
    mkdir -p ~/miniconda3
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
    bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
    rm -rf ~/miniconda3/miniconda.sh

    # Initialize conda
    ~/miniconda3/bin/conda init zsh
    ~/miniconda3/bin/conda install -y python=3.10
    ~/miniconda3/bin/conda create -y -n generic python=3.10 anaconda
    echo 'conda activate generic' >> ~/.zshrc

    # Final steps
    echo "Setup complete! Please:"
    echo "1. Log out and log back in for Docker group changes to take effect"
    echo "2. Install the MesloLGS NF Regular font if not already done"
    echo "3. Start a new zsh session to activate all changes"
    
    # Switch to zsh
    if [ "$SHELL" != "$(which zsh)" ]; then
        chsh -s $(which zsh)
        zsh
    fi
}

# Run the main function
main