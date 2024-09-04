## ThinkNimble CLI

Convenient and sharable command-line tools for nimble thinkers.

## How It Works

TN CLI uses a command runner tool called `just` (https://github.com/casey/just), which similar to `make`, but is "Just a Command Runner" as opposed to a build system.

## Installation

```sh
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/thinknimble/tn-cli/main/install.sh | bash
```

After installing, restart your terminal.

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
```

## Contributing New Commands - aka "Recipes"

It's easy to contribute new commands to tn-cli, simply add some commands to the `justfile` and open a Pull Request.

Check out the [Quick Start](https://github.com/casey/just?tab=readme-ov-file#quick-start) documentation to learn the syntax for `just` commands (aka "recipes"). Commands can be written for just about any OS and language. For example, you can write Python scripts directly in the `justfile`. This makes for an ideal wrapper around other CLI tools.

NOTE: You will probably want to install a just syntax highlighter for your editor. For VSCode, search the extension marketplace for "just."
