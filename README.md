## ThinkNimble CLI

Convenient and sharable command-line tools for nimble thinkers.

## How It Works

TN CLI uses a command runner tool called `just` (https://github.com/casey/just), which similar to `make`, but is "Just a Command Runner" as opposed to a build system.

## Set Up

First, get tn-cli. It MUST be installed in ~/.tn/cli:

```sh
git clone git@github.com:thinknimble/tn-cli.git ~/.tn/cli
```

### Install Just on MacOS

Using [Homebrew](https://brew.sh/):

```sh
brew install just
```

### Install Just on Ubuntu

Using the `apt` package manager. You must first add the `makedeb` source listing:

```sh
wget -qO - 'https://proget.makedeb.org/debian-feeds/prebuilt-mpr.pub' | gpg --dearmor | sudo tee /usr/share/keyrings/prebuilt-mpr-archive-keyring.gpg 1> /dev/null
echo "deb [arch=all,$(dpkg --print-architecture) signed-by=/usr/share/keyrings/prebuilt-mpr-archive-keyring.gpg] https://proget.makedeb.org prebuilt-mpr $(lsb_release -cs)" | sudo tee /etc/apt/sources.list.d/prebuilt-mpr.list
sudo apt update

sudo apt install just
```

### Create an Alias and Install Completions

Easily run `tncli {{command}}` from anywhere by creating an alias in your `~/.zshrc` or `~/.bashrc`.

Using `zsh`:

```bash
# Set up ~/.zshrc
echo alias tncli='just -f ~/.tn/cli/justfile -d .' >> ~/.zshrc

# Install completions for zsh
mkdir -p ~/.zsh/completions
cp ~/.tn/cli/completions/zsh-completions/tncli ~/.zsh/completions/_tncli

# Add completions to ~/.zshrc
echo fpath+=~/.zsh/completions >> ~/.zshrc
echo "zstyle ':completion:*:descriptions' format \"%U%B%d%b%u\"" >> ~/.zshrc
echo "zstyle ':completion:*:messages' format \"%F{green}%d%f\"" >> ~/.zshrc
echo autoload -Uz compinit >> ~/.zshrc
echo compinit -u >> ~/.zshrc

source ~/.zshrc  # or restart your terminal
```

Using `bash`:

```bash
# Set up ~/.bashrc
echo alias tncli='just -f ~/.tn/cli/justfile -d .' >> ~/.bashrc

# Install completions for bash
mkdir -p ~/.local/share/bash-completion/completions && cp ~/.tn/cli/bash-completions/tncli ~/.local/share/bash-completion/completions/tncli
source ~/.bashrc  # or restart your terminal
```

## Contributing New Commands - aka "Recipes"

It's easy to contribute new commands to tn-cli, simply add some commands to the `justfile` and open a Pull Request.

Check out the [Quick Start](https://github.com/casey/just?tab=readme-ov-file#quick-start) documentation to learn the syntax for `just` commands (aka "recipes"). Commands can be written for just about any OS and language. For example, you can write Python scripts directly in the `justfile`. This makes for an ideal wrapper around other CLI tools.

NOTE: You will probably want to install a just syntax highlighter for your editor. For VSCode, search the extension marketplace for "just."
