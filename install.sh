#!/usr/bin/env bash

# Check OS type
OS_TYPE=$(uname)

#
# First, install system-level dependencies
#
if [[ "$OS_TYPE" == "Darwin" ]]; then
    echo "MacOS Detected."

    # Check if Homebrew is installed
    echo "Checking if Homebrew is installed..."
    if ! command -v brew &> /dev/null; then
        echo "Homebrew is not installed. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "Homebrew is already installed."
    fi

    # Check if git is installed
    echo "Checking if git is installed..."
    if ! command -v git &> /dev/null; then
        echo "git is not installed. Installing git..."
        brew install git
    else
        echo "git is already installed."
    fi

    # Check if just is installed
    echo "Checking if just is installed..."
    if ! command -v just &> /dev/null; then
        echo "just is not installed. Installing just..."
        brew install just
    else
        echo "just already installed."
    fi
    
    # Get the TN CLI repo
    if [ -d ~/.tn/cli ]; then
        echo "TN CLI directory already exists. Updating..."
        cd ~/.tn/cli
        git pull
    else
        echo "TN CLI directory does not exist. Cloning..."
        git clone git@github.com:thinknimble/tn-cli.git ~/.tn/cli
    fi

    echo
    echo -e "\033[32mSUCCESS!\033[0m"
    echo "TN CLI Installation is complete."
    echo "Please restart your terminal."

    exit 0
fi

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Check if it's Ubuntu
    if grep -q "Ubuntu" /etc/os-release; then
        echo "Ubuntu Detected"
    else
        echo "Linux Detected, but not Ubuntu - sorry, we don't support this OS yet."
        exit 1
    fi

    # Check if git is installed
    echo "Checking if git is installed..."
    if ! command -v git &> /dev/null; then
        echo "git is not installed. Installing git..."
        sudo apt update
        sudo apt install git
    else
        echo "git is already installed."
    fi

    # Check if just is installed
    echo "Checking if just is installed..."
    if ! command -v just &> /dev/null; then
        echo "just is not installed. Installing just..."
        wget -qO - 'https://proget.makedeb.org/debian-feeds/prebuilt-mpr.pub' | gpg --dearmor | sudo tee /usr/share/keyrings/prebuilt-mpr-archive-keyring.gpg 1> /dev/null
        echo "deb [arch=all,$(dpkg --print-architecture) signed-by=/usr/share/keyrings/prebuilt-mpr-archive-keyring.gpg] https://proget.makedeb.org prebuilt-mpr $(lsb_release -cs)" | sudo tee /etc/apt/sources.list.d/prebuilt-mpr.list
        sudo apt update
        sudo apt install just
    else
        echo "just already installed."
    fi

    # Get the TN CLI repo
    if [ -d ~/.tn/cli ]; then
        echo "TN CLI directory already exists. Updating..."
        cd ~/.tn/cli
        git pull
    else
        echo "TN CLI directory does not exist. Cloning..."
        git clone git@github.com:thinknimble/tn-cli.git ~/.tn/cli
    fi

    # Add bash alias
    BASH_ALIAS="alias tn='just -f ~/.tn/cli/justfile -d .'"
    echo "Checking if BASH_ALIAS is added to ~/.bashrc..."
    if ! grep -q "$BASH_ALIAS" ~/.bashrc; then
        echo "Adding BASH_ALIAS to ~/.bashrc..."
        echo '' >> ~/.bashrc
        echo "$BASH_ALIAS" >> ~/.bashrc
    else
        echo "tn-cli alias already added to ~/.bashrc."
    fi

    # Install completions for bash
    mkdir -p ~/.local/share/bash-completion/completions
    cp ~/.tn/cli/completions/bash-completions/tncli ~/.local/share/bash-completion/completions/tn

    echo
    echo -e "\033[32mSUCCESS!\033[0m"
    echo "TN CLI Installation is complete!"
    echo "Please restart your terminal."

else
    echo "Your OS is not recognized or not supported."
    exit 1
fi
