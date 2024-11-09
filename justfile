[private]
default:
  just -f ~/.tn/cli/justfile --list

os-info:
  echo "Arch: {{arch()}}"
  echo "OS: {{os()}}"

#
# Re-clone and reinstall tn-cli
#
[group('tn-cli')]
update:
  git clone git@github.com:thinknimble/tn-cli.git ~/.tn/cli

#
# Bootstrap new projects
#
alias bootstrap := new-project

[group('bootstrapper')]
new-project:
  #!/usr/bin/env bash
  if ! command -v pipx &> /dev/null; then
    echo "ERROR: You must install pipx first: https://pipx.pypa.io/stable/installation/#installing-pipx"
    exit 1
  fi
  pipx install cookiecutter
  pipx run cookiecutter gh:thinknimble/tn-spa-bootstrapper

#
# AWS Helpers
#
# The AWS CLI is required for these commands to work.
#
[group('aws')]
aws-make-s3-bucket project_name profile='default' region='us-east-1':
  aws cloudformation create-stack --stack-name {{project_name}}-s3-stack --template-url 'https://tn-s3-cloud-formation.s3.amazonaws.com/aws-s3-cloud-formation.yaml' --region {{region}} --parameters ParameterKey=BucketNameParameter,ParameterValue={{project_name}} --capabilities CAPABILITY_NAMED_IAM --profile={{profile}}

[group('aws')]
aws-enable-bedrock project_name profile='default' region='us-east-1' model='*':
  aws cloudformation create-stack --stack-name {{project_name}}-bedrock-stack --template-url 'https://tn-s3-cloud-formation.s3.amazonaws.com/bedrock-user-permissions.yaml' --region {{region}} --parameters ParameterKey=ProjectName,ParameterValue={{project_name}} ParameterKey=AllowedModels,ParameterValue={{model}} --capabilities CAPABILITY_NAMED_IAM --profile={{profile}}

#
# TN Models Helpers
#
# TODO: Support output, e.g. `-o somepath.json`
#
[group('tn-models')]
install-bun:
  #!/usr/bin/env bash
  if ! command -v bunx &> /dev/null; then
    curl -fsSL https://bun.sh/install | bash
  fi

[group('tn-models')]
make-tn-models project_url api_key endpoint='/api/users/':
  #!/usr/bin/env bash
  if ! command -v bunx &> /dev/null
  then
    echo "Please run 'tn install-bun' to install bunx first."
    exit 1
  fi
  bunx @thinknimble/tnm-cli read '{{project_url}}/api/schema/?format=yaml' -t '{{api_key}}' -u '{{endpoint}}'

#
# GitHub CLI
#
[group('github')]
gh-install:
  #!/usr/bin/env bash
  if ! command -v gh &> /dev/null; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew install gh
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      type -p curl >/dev/null || sudo apt install curl -y
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
      && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
      && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
      && sudo apt update \
      && sudo apt install gh -y
    else
      echo "Unsupported operating system. Please install GitHub CLI manually."
      exit 1
    fi
  fi

[group('github')]
gh-auth:
  gh auth login

# See: https://docs.github.com/en/rest/pulls/pulls?apiVersion=2022-11-28
[group('github')]
gh-prs repo='tn-spa-bootstrapper':
  #!/usr/bin/env bash
  echo "== thinknimble/{{repo}} =="
  gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/thinknimble/{{repo}}/pulls | \
  jq -r '.[] | "- \(.title) (\(.html_url))"'

[group('github')]
gh-all-prs:
  #!/usr/bin/env bash
  IFS=',' read -ra projects <<< "$(cat .config | grep PROJECTS | cut -d'=' -f2)"
  for project in "${projects[@]}"; do
    just --justfile {{justfile()}} gh-prs $project
    echo ""
  done

#
# Heroku Commands
#
heroku-create-staging team pipeline:
  #!/usr/bin/env bash
  APP_NAME={{pipeline}}-staging
  echo "Creating app '$APP_NAME' in team '{{team}}'..."
  heroku pipelines:create {{pipeline}} --stage=staging --app=$APP_NAME --team={{team}}
  heroku addons:create heroku-postgresql:essential-0 --app=$APP_NAME
  heroku config:set ENVIRONMENT="staging" --app=$APP_NAME
  heroku config:set DEBUG="True" --app=$APP_NAME

heroku-create-production team pipeline:
  #!/usr/bin/env bash
  APP_NAME="{{pipeline}}-production"
  echo "Creating app '$APP_NAME' in team '{{team}}'..."
  heroku pipelines:create {{pipeline}} --stage=production --app=$APP_NAME --team={{team}}
  heroku addons:create heroku-postgresql:standard-0 --app=$APP_NAME
  heroku config:set ENVIRONMENT="production" --app=$APP_NAME
  heroku config:set DEBUG="False" --app=$APP_NAME

heroku-set-env-vars env_file='' app_name='':
  #!/usr/bin/env bash

  #
  # Collects variables from a .env file and deploys.
  #
  # NOTES:
  #  - This will overwrite existing variables! Confirm the correct variables are available.
  #  - Because DB info is provisioned by Heroku, this script will ask the user if they 
  #    want to purposefully include DB-related env vars.
  #
  function set_env() {
      echo "Setting env vars from $env_file..."
      [ -f "$env_file" ] && grep -vE '^(\s*$|#|DB_|REDIS_)' "$env_file" | tr '\n' ' ' | xargs heroku config:set -a $app_name || echo "Env file $env_file is not present, unable to set vars."
  }

  if [ -z "{{env_file}}" ]; then
    printf "Provide the full path to a .env file, ex: ~/my-project/.env.example\n"
    read env_file
    env_file=$(eval echo "$env_file")
  else
    env_file="{{env_file}}"
  fi

  if [ -z "{{app_name}}" ]; then
    printf "\n"
    printf "Enter app name\n"
    read app_name
  else
    app_name="{{app_name}}"
  fi

  printf "\n"
  echo "Heroku will auto-provision db/redis env vars when a db/redis is provisioned, by default this script will ignore the db env vars"

  printf "\n"
  echo "This will replace values and variables in ${env_file} on the environment ${app_name} continue?"
  select yn in "Yes" "No"; do
      case $yn in
      Yes) set_env && break || return 1 ;;
      No) break ;;
      esac
  done

  echo "Done setting env vars."