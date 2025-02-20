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

## Commands Reference

You can view source code for available commands in the [justfile](justfile).

`tn` - List available commands.

### General Commands

- `tn`: List all available commands.
- `tn os-info`: Display the system architecture and operating system.

### TN CLI Management

- `tn update`: Re-clone and reinstall the tn-cli repository.

### Project Bootstrapping

- `tn new-project` or `tn bootstrap`: Bootstrap a new project using cookiecutter with the tn-spa-bootstrapper template.

### AWS Helpers

- `tn aws-make-s3-bucket <project_name> [profile] [region]`: Create an S3 bucket using AWS CloudFormation.

  - Default profile: 'default'
  - Default region: 'us-east-1'

- `tn aws-enable-bedrock <project_name> [profile] [region] [model]`: Enable AWS Bedrock for a project using CloudFormation.

  - Default profile: 'default'
  - Default region: 'us-east-1'
  - Default model: '\*' (all models)

### TN Models Helpers

- `tn install-bun`: Install the Bun runtime if not already installed.

- `tn make-tn-models <project_url> <api_key> [endpoint] [output]`: Generate TN models using the @thinknimble/tnm-cli tool.
  - Default endpoint: '/api/users/'
  - Output should be a javascript or typescript file
  - Requires Bun to be installed

Note: For AWS helpers, the AWS CLI is required for these commands to work.

### GitHub CLI

- `tn gh-install`: Install the GitHub CLI (gh) if not already present.

  - Uses Homebrew for macOS and apt for Linux.
  - Displays a message for unsupported operating systems.

- `tn gh-auth`: Initiate GitHub CLI authentication process.

- `tn gh-prs [repo]`: List pull requests for a specified repository.

  - Default repo: 'tn-spa-bootstrapper'
  - Displays PR titles with links.

- `tn gh-all-prs`: List pull requests for all projects defined in the .config file.
  - Reads project names from the PROJECTS variable in .config.
  - Calls `gh-prs` for each project.

## Contributing New Commands - aka "Recipes"

It's easy to contribute new commands to tn-cli, simply add some commands to the `justfile` and open a Pull Request.

Check out the [Quick Start](https://github.com/casey/just?tab=readme-ov-file#quick-start) documentation to learn the syntax for `just` commands (aka "recipes"). Commands can be written for just about any OS and language. For example, you can write Python scripts directly in the `justfile`. This makes for an ideal wrapper around other CLI tools.

NOTE: You will probably want to install a just syntax highlighter for your editor. For VSCode, search the extension marketplace for "just."
