[private]
default:
  just -f ~/.tn/cli/justfile --list

[group('general')]
os-info:
  echo "Arch: {{arch()}}"
  echo "OS: {{os()}}"

[group('general')]
install-uv:
  curl -LsSf https://astral.sh/uv/install.sh | sh

#
# Re-clone and reinstall tn-cli
#
[group('tn-cli')]
update:
  #!/usr/bin/env bash
  if [ -d ~/.tn/cli ]; then
    git -C ~/.tn/cli pull
  else
    git clone git@github.com:thinknimble/tn-cli.git ~/.tn/cli
  fi

#
# Bootstrap new projects
#
alias bootstrap := new-project

# Create a new project with the TN Bootstrapper
[group('bootstrapper')]
new-project:
  #!/usr/bin/env bash
  if ! command -v uvx &> /dev/null; then
    echo "ERROR: You must install uvx first, run: tn install-uv"
    exit 1
  fi
  uvx cookiecutter gh:thinknimble/tn-spa-bootstrapper

  printf "\n\n\033[1;32mIMPORTANT! NEXT STEPS...\033[0m\n"
  printf "The next step is to create a git repository and push the code.\n\n"
  printf "    tn gh-create-repo <project_name>\n"
  printf "    cd <project_name>\n"
  printf "    git init\n"
  printf "    git add .\n"
  printf "    git commit -m 'Initial commit'\n"
  printf "    git remote add origin git@github.com:thinknimble/<project_name>.git\n"
  printf "    git branch -M main\n"
  printf "    git push -u origin main\n\n"
  read -p "Press enter when you are ready to proceed..."

  printf "\n\nNext, go to Settings > General in your GitHub repository:\n"
  printf "    - Under Pull Requests: check only 'Allow Squash merging' and set the default commit message to "
  printf "'Pull request title and description'.\n"
  printf "    - Check 'Automatically delete head branches'.\n\n"
  read -p "Press enter when you are ready to proceed..."

  printf "\n\nNext, go to Settings > Branches in your GitHub repository:\n"
  printf "    - Under 'Branch protection rules', click 'Add branch ruleset'.\n"
  printf "    - Set Ruleset Name to 'default'.\n"
  printf "    - Under Targets: click 'Add target' and select 'include default branch'.\n"
  printf "    - Check 'Restrict deletions'.\n"
  printf "    - Check 'Require linear history'.\n"
  printf "    - Check 'Require a pull request before merging:'\n"
  printf "        - Require 1 or more approvals.\n"
  printf "        - Check Dismiss stale pull request approvals when new commits are pushed.\n"
  printf "        - Check Require conversation resolution before merging.\n"
  printf "        - ONLY allow 'Squash' as the merge method.\n"
  printf "    - Check 'Block force pushes'.\n"
  printf "    - Click the 'Create' button at the bottom.\n\n"
  read -p "Press enter when you are ready to proceed..."

  printf "\n\nNext, in Settings > Secrets and variables > Repository secrets, add these:\n"
  printf "    - SECRET_KEY\n"
  printf "    - PLAYWRIGHT_TEST_USER_PASS\n"
  printf "These secrets are found in the .env.example file.\n\n"
  read -p "Press enter when you are ready to proceed..."

  printf "\n\nFinally, create a Heroku pipeline for your app with: tn heroku-create-pipeline <project_name> <team>\n"

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
make-tn-models project_url api_key endpoint='/api/users/' output="someoutput.js":
  #!/usr/bin/env bash
  if ! command -v bunx &> /dev/null
  then
    echo "Please run 'tn install-bun' to install bunx first."
    exit 1
  fi
  bunx @thinknimble/tnm-cli read '{{project_url}}/api/schema/?format=yaml' -t '{{api_key}}' -u '{{endpoint}}' -o '{{output}}'

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

# repo should be like: `owner/repo_name`
[group('github')]
gh-create-repo repo visibility='private':
    #!/usr/bin/env bash
    echo "Creating repository '{{repo}}'..."
    gh repo create thinknimble/{{repo}} --{{visibility}}

# See: https://docs.github.com/en/rest/pulls/pulls?apiVersion=2022-11-28
[group('github')]
gh-prs repo='tn-spa-bootstrapper':
  #!/usr/bin/env bash
  echo "== thinknimble/{{repo}} =="
  gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/thinknimble/{{repo}}/pulls | \
    jq -r '.[] | "\(.title)\t\(.html_url)"' | \
    while IFS=$'\t' read -r title url updated_at; do

    pr_number=$(basename "$url" | grep -o '[0-9]*$')
    commits=$(gh api /repos/thinknimble/{{repo}}/pulls/$pr_number/commits)

    # Get the number of commits in the pull request
    commit_count=$(echo "$commits" | jq '. | length')

    # Get the last commit date
    latest_commit=$(echo "$commits" | jq -r '.[-1].commit.author.date')

    # Calculate the time since the last update
    updated_at_unix=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$latest_commit" +%s)
    current_time_unix=$(date +%s)
    time_since_last_update=$((current_time_unix - updated_at_unix))
    
    time_message=
    
    if [ "$time_since_last_update" -lt 3600 ]; then 
        # Less than 1 hour, print in minutes
        time_in_minutes=$((time_since_last_update / 60))
        time_message=$(echo "$time_in_minutes minutes")
    elif [ "$time_since_last_update" -lt 86400 ]; then
        # Less than 24 hours, print in hours
        time_in_hours=$((time_since_last_update / 3600))
        time_message=$(echo "$time_in_hours hours")
    elif [ "$time_since_last_update" -lt 604800 ]; then
        # More than 24 hours but less than a week, print in days
        time_in_days=$((time_since_last_update / 86400))
        time_message=$(echo "$time_in_days days")
    else
        # More than a week, print in weeks
        time_in_weeks=$((time_since_last_update / 604800))
        time_message=$(echo "$time_in_weeks weeks")
    fi
    
    echo "$title    $url    $commit_count commits  $time_message"
  done

[group('github')]
gh-all-prs:
  #!/usr/bin/env bash
  IFS=',' read -ra projects <<< "$(cat ./.tn/.config | grep PROJECTS | cut -d'=' -f2)"
  for project in "${projects[@]}"; do
    just --justfile {{justfile()}} gh-prs $project
    echo ""
  done

# Build appstore builds for repo
[group('github')]
gh-store-workflow repo include-prefix='true':
  #!/usr/bin/env bash
  REPOSITORY={{repo}}
  if [ {{include-prefix}} = "true" ]; then
    REPOSITORY=thinknimble/{{repo}}
  fi
  echo "Storing workflows for $REPOSITORY..."
  echo {{include-prefix}}
  gh workflow run expo-teststore-build-ios.yml --repo $REPOSITORY && gh workflow run expo-teststore-build-android.yml --repo $REPOSITORY



#
# Ollama CLI
#
[group('ollama')]
ollama-install:
  #!/usr/bin/env bash
  if ! command -v ollama &> /dev/null; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "Installing Ollama CLI..."
      brew install ollama
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      type -p curl >/dev/null || sudo apt install curl -y
      curl -fsSL https://ollama.com/install.sh | sh
    else
      echo "Unsupported operating system. Please install OLlama manually."
      exit 1
    fi
  fi

[group('ollama')]
ollama-serve:
  ollama serve 

[group('ollama')]
ollama-gen:
  ollama generate

[group('ollama')]
ollama-codegen:
  ollama
 
[group('ollama')]
ollama-customgen:
  ollama

# repo should be like: `owner/repo_name`
[group('github')]
gh-transfer repo new_owner:
  #!/usr/bin/env bash
  gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/{{repo}}/transfer \
    -f "new_owner={{new_owner}}"

# repo should be like: `owner/repo_name`
[group('github')]
gh-archive repo:
  #!/usr/bin/env bash
  gh repo archive {{repo}} --yes

#
# Heroku Commands
#
[group('heroku')]
heroku-create-pipeline app_name team='thinknimble-agency-pod':
  #!/usr/bin/env bash

  PIPELINE={{app_name}}
  STAGING={{app_name}}-staging
  PRODUCTION={{app_name}}-production
  TEAM={{team}}

  for APP_NAME in $STAGING $PRODUCTION; do
    heroku apps:create $APP_NAME --no-remote --buildpack=heroku/nodejs --team=$TEAM
    heroku buildpacks:add https://github.com/dropseed/heroku-buildpack-uv.git --app=$APP_NAME
    heroku buildpacks:add heroku/python --app=$APP_NAME

    # Required env vars
    heroku config:set SECRET_KEY="$(openssl rand -base64 64)" --app=$APP_NAME
    # TODO: ALLOWS_HOSTS will be incorrect right now b/c Heroku adds random characters to the domain
    heroku config:set CURRENT_DOMAIN="$APP_NAME.herokuapp.com" --app=$APP_NAME
    heroku config:set ALLOWED_HOSTS="$APP_NAME.herokuapp.com" --app=$APP_NAME
    # END TODO
    heroku config:set NPM_CONFIG_PRODUCTION=false --app=$APP_NAME
    heroku config:set MAILGUN_API_KEY="SET ME" --app=$APP_NAME
    heroku config:set MAILGUN_DOMAIN="SET ME" --app=$APP_NAME
    heroku config:set DJANGO_SUPERUSER_PASSWORD="TN_$PIPELINE" --app=$APP_NAME
    heroku config:set PLAYWRIGHT_TEST_USER_PASS="TN_$PIPELINE" --app=$APP_NAME
    heroku config:set DEBUG="True" --app=$APP_NAME
  done

  # Create a pipeline using production
  heroku pipelines:create $PIPELINE --stage=production --app=$PRODUCTION --team=$TEAM

  # Production-specific settings
  heroku addons:create heroku-postgresql:standard-0 --app=$PRODUCTION
  heroku addons:create heroku-redis:mini --app=$PRODUCTION
  heroku config:set ENVIRONMENT="production" --app=$PRODUCTION
  heroku config:set DEBUG="True" --app=$PRODUCTION

  # Add Staging to that pipeline
  heroku pipelines:add $PIPELINE --stage=staging --app=$STAGING

  # Staging specific settings
  heroku addons:create heroku-postgresql:essential-0 --app=$STAGING
  heroku addons:create heroku-redis:mini --app=$STAGING
  heroku config:set ENVIRONMENT="staging" --app=$STAGING

  # Connect Github
  # TODO - This Does not work yet. Also a lot of review app settings have to be set manually anyway
  # heroku pipelines:connect $PIPELINE -r thinknimble/$PIPELINE
  printf "\n\nNEXT: CONNECT GITHUB\n"
  printf "Your new pipeline is ready: https://dashboard.heroku.com/pipelines/${PIPELINE}\n"
  printf "Open that link and navigate to the 'Settings' tab to connect your new pipeline to Github.\n"
  read -p "Press enter when you are ready to proceed..."

  # TODO - Automate enabling review apps
  # NOTE: This is not working yet: heroku reviewapps:enable --pipeline="${PIPELINE}"
  printf "\n\nNEXT: ENABLE REVIEW APPS\n"
  printf "Find the review apps section and enable review apps:\n"
  printf "  Select: 'Create new review apps for new pull requests automatically'\n"
  printf "  Select: 'Destroy stale review apps automatically'\n"
  read -p "Press enter when you are ready to proceed..."

  # TODO - Automate updating the review app URL pattern
  printf "\n\nNEXT: UPDATE REVIEW APP URL PATTERN\n"
  printf "After enabling review apps, click 'Update URL Pattern' and set it to: Predictable\n"
  read -p "Press enter when you are ready to proceed..."

  # TODO - Automate turning on auto-deploys
  printf "\n\nNEXT: TURN ON AUTO-DEPLOYMENT FOR STAGING\n"
  printf "Visit the staging app in your pipeline, navigate to the 'Deploy' tab, "
  printf "find the 'Automatic deploys' section and click 'Enable automatic deploys from GitHub'.\n"
  read -p "Press enter when you are ready to proceed..."

  # TODO - Automate fixing the ALLOWED_HOSTS variable
  printf "\n\nNEXT: FIX ALLOWED_HOSTS ENVIRONMENT VARIABLE\n"
  printf "By default, Heroku will add random characters to the domain name, so you need to update the ALLOWED_HOSTS env var.\n"
  printf "Navigate to the 'Settings' tab of the staging and production apps and update the ALLOWED_HOSTS env var to match the domain.\n"
  read -p "Press enter when you are ready to proceed..."

  # TODO - Automate the first deployment
  printf "\n\nFINALLY: DEPLOY STAGING\n"
  printf "Finally, look for the 'Manual deploy' section and click 'Deploy Branch' "
  printf "To deploy the main branch to the staging app one time manually.\n"
  read -p "Press enter when you are ready to proceed..."

  printf "\n\nThat's it! Your app should now be deployed to staging and ready for development.\n"

[group('heroku')]
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

# Create a new Heroku app. Does not add buildpacks!
[group('heroku')]
heroku-create-app app_name team='thinknimble-agency-pod' pipeline='' stage='staging':
    #!/usr/bin/env bash
    heroku apps:create {{app_name}} --no-remote --team={{team}}

    if [ -n "{{pipeline}}" ]; then
      heroku pipelines:add {{pipeline}} --app={{app_name}} --stage={{stage}}
    fi

# Delete a specific Heroku app
[group('heroku')]
heroku-delete-app app_name force='false':
    #!/usr/bin/env bash
    if [ "{{force}}" = "true" ]; then
        heroku apps:destroy --app={{app_name}} --confirm={{app_name}}
    else
        echo "⚠️  WARNING: This will permanently delete the app '{{app_name}}' and all of its add-ons."
        read -p "Are you sure? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            heroku apps:destroy --app={{app_name}} --confirm={{app_name}}
        else
            echo "Aborted."
        fi
    fi

# Delete an entire Heroku pipeline, including all apps inside
[group('heroku')]
heroku-delete-pipeline pipeline force='false':
    #!/usr/bin/env bash
    echo "Fetching apps in pipeline '{{pipeline}}'..."
    APPS=$(heroku pipelines:info {{pipeline}} --json | jq -r '.apps[].name')
    
    if [ "{{force}}" = "true" ]; then
        for app in $APPS; do
            echo "Destroying app: $app"
            heroku apps:destroy --app=$app --confirm=$app
        done
        # heroku pipelines:destroy {{pipeline}}
    else
        echo "⚠️  WARNING: This will permanently delete the pipeline '{{pipeline}}' and these apps:"
        echo "$APPS"
        read -p "Are you sure? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for app in $APPS; do
                echo "Destroying app: $app"
                heroku apps:destroy --app=$app --confirm=$app
            done
            # heroku pipelines:destroy {{pipeline}}
        else
            echo "Aborted."
        fi
    fi


[group('heroku')]
heroku-promote2prod source to:
    #!/usr/bin/env bash
    heroku pipelines:promote -a {{source}} --to {{to}}
