## ThinkNimble CLI

Convenient and sharable command-line tools for nimble thinkers.

## How It Works

TN CLI uses a command runner tool called `just` (https://github.com/casey/just), which similar to `make`, but is "Just a Command Runner" as opposed to a build system.

## Installation

```sh
curl -fsSL https://nimbl.sh/install | bash
```

After installing, restart your terminal.

## Usage

Now try out the `tn` command. Type `tn` and press the `↵ Enter` key. You should see a list of "Available Recipes." like this:

```sh
Available recipes:
    os-info

    [aws]
    aws-enable-bedrock project_name profile='default' region='us-east-1' model='*'
    aws-make-s3-bucket project_name profile='default' region='us-east-1'

    [bootstrapper]
    new-project
    bootstrap   # alias for `new-project`

    # etc...
```

## Bash and Zsh Tab Completions

The install script above attempts to automatically install Bash and Zsh completions. This will auto-complete commands when you press `Tab`.

While this install seems to work consistently on Mac with Zsh, we have had less luck with bash completions on Linux (Ubuntu). If that is your case and you are not getting tab-completions, try adding the following to your `~/.bashrc`:

```bash
# TN-CLI
export TNCLI_DIR="$HOME/.tn/cli"
alias tn='just -f ~/.tn/cli/justfile -d .'
[ -s "$TNCLI_DIR/completions/bash-completions/tncli" ] && \. "$TNCLI_DIR/completions/bash-completions/tncli"
```

Then reload your shell or `source ~/.bashrc`.

## Commands Reference

You can view source code for available commands in the [justfile](justfile).

`tn` - List available commands.

### General Commands

- `tn`: List all available commands.
- `tn os-info`: Display the system architecture and operating system.
- `tn install-uv`: Install the uv package manager for Python.

### TN CLI Management

- `tn update`: Re-clone and reinstall the tn-cli repository.

### Project Bootstrapping

- `tn new-project` or `tn bootstrap`: Bootstrap a new project using cookiecutter with the tn-spa-bootstrapper template.
  - Requires uv to be installed (use `tn install-uv` first)
  - Provides guidance for next steps (git initialization and Heroku setup)

### AWS Helpers

- `tn aws-make-s3-bucket <project_name> [profile] [region]`: Create an S3 bucket using AWS CloudFormation.

  - Default profile: 'default'
  - Default region: 'us-east-1'

- `tn aws-enable-bedrock <project_name> [profile] [region] [model]`: Enable AWS Bedrock for a project using CloudFormation.
  - Default profile: 'default'
  - Default region: 'us-east-1'
  - Default model: '\*' (all models)

Note: For AWS helpers, the AWS CLI is required for these commands to work.

### TN Models Helpers

- `tn install-bun`: Install the Bun runtime if not already installed.

- `tn make-tn-models <project_url> <api_key> [endpoint] [output]`: Generate TN models using the @thinknimble/tnm-cli tool.
  - Default endpoint: '/api/users/'
  - Output should be a javascript or typescript file
  - Requires Bun to be installed

## GitHub CLI Commands

- `tn gh-install`: Install the GitHub CLI (gh).

  - Uses Homebrew for macOS and apt for Linux.
  - Displays a message for unsupported operating systems.

- `tn gh-auth`: Initiate GitHub CLI authentication process.

- `tn gh-create-repo <repo> [visibility]`: Create a new repository under the thinknimble organization.

  - Default visibility: private
  - Example: `tn gh-create-repo my-new-project public`

- `tn gh-prs [repo]`: List pull requests for a specified repository.

  - Default repo: 'tn-spa-bootstrapper'
  - Shows PR title, URL, commit count, and time since last update

- `tn gh-all-prs`: List pull requests for all projects defined in .tn/.config.

- `tn gh-transfer <repo> <new_owner>`: Transfer a repository to a new owner.

- `tn gh-archive <repo>`: Archive a repository.

### Heroku Commands

- `tn heroku-create-pipeline <app_name> [team]`: Create a new Heroku pipeline with staging and production apps.

  - Default team: 'thinknimble-agency-pod'
  - Sets up buildpacks, databases, and environment variables
  - Guides through GitHub integration and review apps setup

- `tn heroku-set-env-vars [env_file] [app_name]`: Set environment variables from a .env file.

  - Prompts for file path and app name if not provided
  - Skips database-related variables

- `tn heroku-delete-app <app_name> [force]`: Delete a specific Heroku app.

  - Use force=true to skip confirmation prompt
  - Example: `tn heroku-delete-app my-app-staging true`

- `tn heroku-delete-pipeline <pipeline> [force]`: Delete an entire Heroku pipeline and its apps.
  - Use force=true to skip confirmation prompt
  - Example: `tn heroku-delete-pipeline my-project true`

### Ollama as a local LLM
Use `tn update-config` <arg> <arg> to set a basic config the default for the local ollama is http://localhost:11434. You should be setting 

```
OLLAMA_API_URL="http://localhost:11434"
OLLAMA_MODEL="llama3.3"
```

- `tn ollama-serve`: serve a local llm server this is needed to run any commands
- `tn ollama-pull`: When working locally if you want to try a model you have to pull it 
- `tn ollama-run`: Run an interactive chat with the local ollama server
- `tn ollama-codegen message`: Use the code gen specific cli (WIP)
  optional args: `--api_url=""` use a custom url other than the default (eg ngrok)
                  `--model=""` use a custom model the default is qwen2.5-coder:7b


## Contributing New Commands - aka "Recipes"

It's easy to contribute new commands to tn-cli, simply add some commands to the `justfile` and open a Pull Request.

Check out the [Quick Start](https://github.com/casey/just?tab=readme-ov-file#quick-start) documentation to learn the syntax for `just` commands (aka "recipes"). Commands can be written for just about any OS and language. For example, you can write Python scripts directly in the `justfile`. This makes for an ideal wrapper around other CLI tools.

NOTE: You will probably want to install a just syntax highlighter for your editor. For VSCode, search the extension marketplace for "just."
