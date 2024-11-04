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
  IFS=',' read -ra projects <<< "$(cat .config | grep PROJECTS | cut -d'=' -f2)"
  for project in "${projects[@]}"; do
    just --justfile {{justfile()}} gh-prs $project
    echo ""
  done