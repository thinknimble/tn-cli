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
[group('heroku')]
heroku-create-pipeline app_name team:
  #!/usr/bin/env bash

  PIPELINE={{app_name}}
  STAGING={{app_name}}-staging
  PRODUCTION={{app_name}}-production
  TEAM={{team}}

  for APP_NAME in $STAGING $PRODUCTION; do
    heroku apps:create $APP_NAME --no-remote --buildpack=heroku/python --team=$TEAM
    heroku buildpacks:add --index 1 heroku/nodejs --app=$APP_NAME

    # Required env vars
    heroku config:set SECRET_KEY="$(openssl rand -base64 64)" --app=$APP_NAME
    # TODO: ALLOWS_HOSTS will be incorrect right now b/c Heroku adds random characters to the domain
    heroku config:set CURRENT_DOMAIN="$APP_NAME.herokuapp.com" --app=$APP_NAME
    heroku config:set ALLOWED_HOSTS="$APP_NAME.herokuapp.com" --app=$APP_NAME
    # END TODO
    heroku config:set NPM_CONFIG_PRODUCTION=false --app=$APP_NAME
    heroku config:set MAILGUN_API_KEY="SET ME" --app=$APP_NAME
    heroku config:set MAILGUN_DOMAIN="SET ME" --app=$APP_NAME
    heroku config:set DJANGO_SUPERUSER_PASSWORD="TN_$APP_NAME" --app=$APP_NAME
    heroku config:set CYPRESS_TEST_USER_PASS="TN_$APP_NAME" --app=$APP_NAME
    heroku config:set DEBUG="True" --app=$APP_NAME
  done

  # Create a pipeline using production
  heroku pipelines:create $PIPELINE --stage=production --app=$PRODUCTION --team=$TEAM

  # Production-specific settings
  heroku addons:create heroku-postgresql:standard-0 --app=$PRODUCTION
  heroku config:set ENVIRONMENT="production" --app=$PRODUCTION
  heroku config:set DEBUG="True" --app=$PRODCUTION

  # Add Staging to that pipeline
  heroku pipelines:add $PIPELINE --stage=staging --app=$STAGING

  # Staging specific settings
  heroku addons:create heroku-postgresql:essential-0 --app=$STAGING
  heroku config:set ENVIRONMENT="staging" --app=$STAGING

  # TODO - Turn on auto-deploys
  printf "Your new pipeline is ready: https://dashboard.heroku.com/pipelines/${PIPELINE}\n"
  printf "Please turn on auto-deploys for the pipeline.\n"
  read -p "Press enter when you are ready to proceed..."

  # TODO - Deploy once manually
  printf "Next, deploy the staging app once manually.\n"
  read -p "Press enter when you are ready to proceed..."

  # Connect Github
  # TODO - Does not work. Also a lot of review app settings have to be set manually anyway
  # heroku pipelines:connect $PIPELINE -r thinknimble/$PIPELINE
  printf "Next, connect the pipeline to Github.\n"
  read -p "Press enter when you are ready to proceed..."

  # After Github is connected...
  # heroku reviewapps:enable --pipeline="${PIPELINE}"
  # TODO - create automatically
  # TODO - deterministic URLs
  # TODO - set private env vars
  printf "Next, to enable review apps visit the pipeline settings:\n"
  printf "Make sure to change the review app PR name\n"

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
      [ -f "$env_file" ] && grep -vE '^(\s*$|#|DB_|REDIS_|ENVIRONMENT)' "$env_file" | tr '\n' ' ' | xargs heroku config:set -a $app_name || echo "Env file $env_file is not present, unable to set vars."
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