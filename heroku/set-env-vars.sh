#!/bin/bash
# collects variables from the .env file and deploys,
# this will overwrite existing variables confirm the correct variables are available
#  because db info is provisioned by heroku this script will ask the user if they want to purposefully include db env vars

function set_env() {

    [ -f "$env_file" ] && grep -vE '^(\s*$|#|DB_|REDIS_)' "$env_file" | tr '\n' ' ' | xargs heroku config:set -a $app_name || echo "Env file $env_file is not present, unable to set vars you can run this manually"

    # grep -vE '^(\s*$|#|DB_)' ".env.${env_name}" | tr '\n' ' ' | xargs #heroku config:set -a { $APP_NAME }
}

printf "Enter .env file name e.g .env.staging \n"
read env_file
printf "\n"
printf "Enter app name\n"
read app_name
printf "\n"
echo "Heroku will auto provision db/redis env vars when a db/redis is provisioned, by default this script will ignore the db env vars"
printf "\n"
echo "This will replace values and variables in ${env_file} on the environment ${app_name} continue?"
select yn in "Yes" "No"; do
    case $yn in
    Yes) set_env && break || return 1 ;;
    No) break ;;
    esac
done

echo "Done with set-env.sh"