[private]
default:
  just -f ~/.tn/cli/justfile --list

os-info:
  echo "Arch: {{arch()}}"
  echo "OS: {{os()}}"

alias bootstrap := new-project

new-project:
  cookiecutter git@github.com:thinknimble/tn-spa-bootstrapper.git
