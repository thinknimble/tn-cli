# Contributing to TN CLI

Thank you for your interest in contributing to TN CLI! This guide will help you get started with contributing to the project.

## 🤝 Community Philosophy

Our project is built on the principles of collaboration, quality, and respect. We believe that:

### Guiding Values
- **Attribution Matters**: Everyone gets credit for their work
- **Knowledge Sharing**: Improvements benefit the entire community
- **Quality Focus**: Prioritize well-crafted solutions over quantity
- **Practical Application**: Solutions should address real-world challenges

## 📋 Getting Started

### Prerequisites
- Bash or Zsh shell
- Git
- `just` command runner (installed automatically with TN CLI)

### Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/thinknimble/tn-cli.git
   cd tn-cli
   ```

2. **Install TN CLI locally for development**
   ```bash
   ./install.sh
   ```

3. **Test your installation**
   ```bash
   tn
   ```
   You should see a list of available recipes.

## 🚀 Ways to Contribute

### 1. Report Issues
- Use the GitHub issue tracker to report bugs
- Provide clear descriptions and steps to reproduce
- Include relevant error messages and system information

### 2. Submit Pull Requests
- Fork the repository and create a feature branch
- Write clear, concise commit messages
- Test your commands thoroughly
- Update documentation as needed
- Submit a pull request with a clear description

### 3. Improve Documentation
- Fix typos and clarify existing documentation
- Add examples and use cases
- Document new commands in the README

### 4. Create New Commands (Recipes)
- Add new useful commands to the `justfile`
- Follow existing naming conventions
- Include helpful documentation comments
- Consider cross-platform compatibility

## 📝 Code Standards

### Just Recipes
- Use descriptive command names with hyphens (e.g., `aws-make-s3-bucket`)
- Group related commands with comment headers
- Include helpful descriptions using `#` comments
- Use consistent parameter naming conventions
- Provide sensible defaults for optional parameters

### Shell Scripts
- Follow POSIX shell conventions where possible
- Use clear variable names
- Include error handling
- Test on both macOS and Linux when possible

### Commit Messages
- Use clear, descriptive commit messages
- Start with a verb in the present tense (e.g., "Add", "Fix", "Update")
- Reference issue numbers when applicable

## ✅ Code of Conduct

### Recommended Practices
- ✅ Give credit to others
- ✅ Use respectful language
- ✅ Accept constructive feedback
- ✅ Focus on community benefits
- ✅ Thoroughly test contributions

### Practices to Avoid
- ❌ Include sensitive information or credentials
- ❌ Submit untested commands
- ❌ Remove others' attribution
- ❌ Use aggressive communication
- ❌ Submit duplicate or low-effort contributions

## 🧪 Testing

### Testing New Commands
1. Test your command locally:
   ```bash
   just -f justfile <your-command>
   ```

2. Test with the installed CLI:
   ```bash
   tn <your-command>
   ```

3. Test on different platforms (macOS, Linux) if possible

4. Verify tab completions work correctly

### Testing Guidelines
- Ensure commands handle errors gracefully
- Test with various input parameters
- Verify cross-platform compatibility
- Check that help text is clear and accurate

## 📖 Adding New Commands

When adding new commands to the `justfile`:

1. **Choose the right section**: Place your command in the appropriate category or create a new one
2. **Document thoroughly**: Include a description comment above your recipe
3. **Handle parameters**: Use sensible defaults and validate inputs
4. **Consider dependencies**: Document any required tools or setup
5. **Update README**: Add your command to the Commands Reference section

Example recipe structure:
```just
# Description of what this command does
command-name param1 optional_param='default':
    #!/usr/bin/env bash
    set -euo pipefail
    # Your command implementation here
```

## 📄 License

By contributing to TN CLI, you agree that your contributions will be licensed under the Apache License 2.0.

## 🙏 Recognition

We value all contributions to the project. Contributors will be:
- Listed in the project's contributor list
- Credited in release notes for significant contributions
- Acknowledged in the documentation for major features

## 💬 Getting Help

If you need help or have questions:
- Check the existing documentation
- Search through existing issues
- Ask in discussions or create a new issue
- Contact the maintainers

## 🎯 Quick Start for New Contributors

1. Find an issue labeled "good first issue" or identify a command you'd like to add
2. Fork the repository and create a feature branch
3. Make your changes to the `justfile`
4. Test your changes locally
5. Update the README.md if you've added new commands
6. Submit a pull request

Thank you for contributing to TN CLI!