[private]
default:
  just -f ~/.tn/cli/justfile --list

os-info:
  echo "Arch: {{arch()}}"
  echo "OS: {{os()}}"

#
# Re-clone and reinstall tn-cli
#
update:
  git clone git@github.com:thinknimble/tn-cli.git ~/.tn/cli

#
# Bootstrap new projects
#
alias bootstrap := new-project

new-project:
  cookiecutter git@github.com:thinknimble/tn-spa-bootstrapper.git

#
# AWS Helpers
#
aws-make-s3-bucket stack_name bucket_name region=us-east-1:
  aws cloudformation create-stack \
    --stack-name {{stack_name}} \
    --template-url 'https://tn-s3-cloud-formation.s3.amazonaws.com/aws-s3-cloud-formation.yaml' \
    --region {{region}} \
    --parameters ParameterKey=BucketNameParameter,ParameterValue={{bucket_name}} \
    --capabilities CAPABILITY_NAMED_IAM

aws-enable-bedrock stack_name project_name region=us-east-1 model=*:
  aws cloudformation create-stack \
    --stack-name {{stack_name}} \
    --template-url 'https://tn-s3-cloud-formation.s3.amazonaws.com/bedrock-user-permissions.yaml' \
    --region {{region}} \
    --parameters ParameterKey=ProjectName,ParameterValue={{project_name}} \
    ParameterKey={{model}} \
    --capabilities CAPABILITY_NAMED_IAM