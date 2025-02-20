#!/bin/bash

# Deploy APP To heroku

STAGING=nhaapp-staging
PRODUCTION=nhaapp-production
PIPELINE=nhaapp
TEAM=thinknimble-chaos-pod

# May eventually rewrite this in Python
# https://github.com/martyzz1/heroku3.py
# https://devcenter.heroku.com/articles/platform-api-quickstart

# heroku pipelines:info $PIPELINE
# heroku pipelines:destroy $PIPELINE
# heroku apps:destroy --app=$PRODUCTION --confirm=$PRODUCTION
# heroku apps:destroy --app=$STAGING --confirm=$STAGING

# heroku login --interactive

for APP_NAME in $STAGING $PRODUCTION; do
  heroku apps:create $APP_NAME --no-remote --buildpack=heroku/python --team=$TEAM
  heroku buildpacks:add --index 1 heroku/nodejs --app=$APP_NAME
  #heroku addons:create papertrail:Choklad --app=$APP_NAME

  heroku config:set SECRET_KEY="$(openssl rand -base64 64)" --app=$APP_NAME
  heroku config:set CURRENT_DOMAIN="$APP_NAME.herokuapp.com" --app=$APP_NAME
  heroku config:set ALLOWED_HOSTS="$APP_NAME.herokuapp.com" --app=$APP_NAME
  heroku config:set NPM_CONFIG_PRODUCTION=false --app=$APP_NAME
  heroku config:set MAILGUN_API_KEY="SET ME" --app=$APP_NAME
  heroku config:set MAILGUN_DOMAIN="SET ME" --app=$APP_NAME
  heroku config:set DJANGO_SUPERUSER_PASSWORD="TN_$APP_NAME" --app=$APP_NAME
  heroku config:set CYPRESS_TEST_USER_PASS="TN_$APP_NAME" --app=$APP_NAME
  heroku config:set DEBUG="True" --app=$APP_NAME
done

# Create a pipeline using production
heroku pipelines:create $PIPELINE --stage=production --app=$PRODUCTION --team=$TEAM
# Production specific settings
heroku addons:create heroku-postgresql:standard-0 --app=$PRODUCTION
heroku config:set ENVIRONMENT="production" --app=$PRODUCTION
heroku config:set DEBUG="True" --app=$PRODCUTION

# Add Staging to that pipeline
heroku pipelines:add $PIPELINE --stage=staging --app=$STAGING
# Staging specific settings
heroku addons:create heroku-postgresql:mini --app=$STAGING
heroku config:set ENVIRONMENT="staging" --app=$STAGING

# TODO - Turn on auto-deploys
# TODO - Deploy once manually

# Connect Github
# TODO - Doesn't work. Also a lot of review app settings have to be set manually anyway
# heroku pipelines:connect $PIPELINE -r thinknimble/$PIPELINE

# After Github is connected...
# heroku reviewapps:enable --pipeline="${PIPELINE}"
# TODO - create automatically
# TODO - deterministic URLs
# TODO - set private env vars
printf "To enable review apps visit the pipeline settings"
printf "Change the review app pr appellation"
printf "Create a new HEROKU_API_TOKEN with the command"
printf "Create the GITHUB_TOKEN"