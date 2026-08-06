[private]
default:
  just -f ~/.tn/cli/justfile --list --unsorted

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
# Set up the config file
#
[group('config')]
init-config:
  #!/usr/bin/env bash
  ls -a ~/.tn
  if [ -d ~/.tn/.config ]; then
    echo "Config file already exists."
  else
    if [ -f ~/.tn/cli/.config.example ]; then
      echo "Source config file exists: ~/.tn/cli/.config.example"
      mkdir -p ~/.tn
      cp ~/.tn/cli/.config.example ~/.tn/.config
      if [ $? -eq 0 ]; then
        echo "Config file copied successfully."
      else
        echo "Failed to copy config file."
      fi
    else
      echo "Source config file does not exist: ~/.tn/cli/.config.example"
    fi
  fi
#
# Update the config
#

[group('config')]
update-config var_name var_value:
  #!/usr/bin/env bash
  if [ ! -d ~/.tn/.config ]; then
    echo "No config file found. Run 'tn config-init' first."
  else
    # read the file, if the variable exists update it otherwise add it
    if grep -q "^$var_name=" ~/.tn/.config; then
      sed -i "s/^$var_name=.*/$var_name=$var_value/" ~/.tn/.config
      echo "Updated $var_name in config file."
    else
      echo "$var_name=$var_value" >> ~/.tn/.config
      echo "Added $var_name to config file."
    fi
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
# AWS Terraform Recipes
#
# Extracted from tn-spa-bootstrapper template scripts.
# Each recipe accepts parameters instead of relying on cookiecutter template variables.
#

# Idempotent shared VPC creation with tagged resources
[group('aws-terraform')]
aws-setup-vpc vpc_name='tn-shared' environment='dev' profile='default' region='us-east-1':
  #!/usr/bin/env bash
  set -e

  VPC_NAME="{{vpc_name}}"
  ENVIRONMENT="{{environment}}"
  AWS_PROFILE="{{profile}}"
  AWS_REGION="{{region}}"

  PROFILE_FLAG=""
  if [[ "$AWS_PROFILE" != "default" ]]; then
    PROFILE_FLAG="--profile $AWS_PROFILE"
  fi
  REGION_FLAG="--region $AWS_REGION"

  TAG_PREFIX="${VPC_NAME}-${ENVIRONMENT}"

  echo "Shared VPC Setup"
  echo "================"
  echo "  VPC Name: $TAG_PREFIX"
  echo "  AWS Profile: $AWS_PROFILE"
  echo "  AWS Region: $AWS_REGION"
  echo ""

  # Check AWS CLI
  if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI not found. Please install AWS CLI first."
    exit 1
  fi

  if ! aws sts get-caller-identity $PROFILE_FLAG &> /dev/null; then
    echo "Error: AWS CLI not configured for profile '$AWS_PROFILE'. Run 'aws configure' first."
    exit 1
  fi

  # 1. Create or find VPC
  echo "Checking for existing VPC..."
  EXISTING_VPC=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${TAG_PREFIX}" \
    $PROFILE_FLAG $REGION_FLAG \
    --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")

  if [[ "$EXISTING_VPC" != "None" && -n "$EXISTING_VPC" ]]; then
    VPC_ID="$EXISTING_VPC"
    echo "VPC already exists: $VPC_ID"
  else
    echo "Creating VPC..."
    VPC_ID=$(aws ec2 create-vpc \
      --cidr-block 10.0.0.0/16 \
      $PROFILE_FLAG $REGION_FLAG \
      --query 'Vpc.VpcId' --output text)

    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support $PROFILE_FLAG $REGION_FLAG
    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames $PROFILE_FLAG $REGION_FLAG

    aws ec2 create-tags --resources "$VPC_ID" \
      --tags Key=Name,Value="${TAG_PREFIX}" \
      $PROFILE_FLAG $REGION_FLAG
    echo "VPC created: $VPC_ID"
  fi

  # 2. Create or find Internet Gateway
  echo ""
  echo "Checking for Internet Gateway..."
  EXISTING_IGW=$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=${TAG_PREFIX}-igw" \
    $PROFILE_FLAG $REGION_FLAG \
    --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo "None")

  if [[ "$EXISTING_IGW" != "None" && -n "$EXISTING_IGW" ]]; then
    IGW_ID="$EXISTING_IGW"
    echo "Internet Gateway already exists: $IGW_ID"
  else
    echo "Creating Internet Gateway..."
    IGW_ID=$(aws ec2 create-internet-gateway \
      $PROFILE_FLAG $REGION_FLAG \
      --query 'InternetGateway.InternetGatewayId' --output text)

    aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" \
      $PROFILE_FLAG $REGION_FLAG

    aws ec2 create-tags --resources "$IGW_ID" \
      --tags Key=Name,Value="${TAG_PREFIX}-igw" \
      $PROFILE_FLAG $REGION_FLAG
    echo "Internet Gateway created and attached: $IGW_ID"
  fi

  # 3. Create or find Route Table
  echo ""
  echo "Checking for Route Table..."
  EXISTING_RT=$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=${TAG_PREFIX}-rt" \
    $PROFILE_FLAG $REGION_FLAG \
    --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || echo "None")

  if [[ "$EXISTING_RT" != "None" && -n "$EXISTING_RT" ]]; then
    RT_ID="$EXISTING_RT"
    echo "Route Table already exists: $RT_ID"
  else
    echo "Creating Route Table..."
    RT_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
      $PROFILE_FLAG $REGION_FLAG \
      --query 'RouteTable.RouteTableId' --output text)

    aws ec2 create-route --route-table-id "$RT_ID" \
      --destination-cidr-block 0.0.0.0/0 \
      --gateway-id "$IGW_ID" \
      $PROFILE_FLAG $REGION_FLAG

    aws ec2 create-tags --resources "$RT_ID" \
      --tags Key=Name,Value="${TAG_PREFIX}-rt" \
      $PROFILE_FLAG $REGION_FLAG
    echo "Route Table created with default route: $RT_ID"
  fi

  # 4. Create subnets across 2 AZs
  echo ""
  echo "Checking for subnets..."

  # Get available AZs
  AZS=($(aws ec2 describe-availability-zones \
    --filters "Name=state,Values=available" \
    $PROFILE_FLAG $REGION_FLAG \
    --query 'AvailabilityZones[0:2].ZoneName' --output text))

  SUBNET_CIDRS=("10.0.1.0/24" "10.0.2.0/24")

  for i in 0 1; do
    AZ="${AZS[$i]}"
    CIDR="${SUBNET_CIDRS[$i]}"
    SUBNET_NAME="${TAG_PREFIX}-subnet-${AZ}"

    EXISTING_SUBNET=$(aws ec2 describe-subnets \
      --filters "Name=tag:Name,Values=${SUBNET_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
      $PROFILE_FLAG $REGION_FLAG \
      --query 'Subnets[0].SubnetId' --output text 2>/dev/null || echo "None")

    if [[ "$EXISTING_SUBNET" != "None" && -n "$EXISTING_SUBNET" ]]; then
      echo "Subnet already exists in ${AZ}: $EXISTING_SUBNET"
    else
      echo "Creating subnet in ${AZ} (${CIDR})..."
      SUBNET_ID=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block "$CIDR" \
        --availability-zone "$AZ" \
        $PROFILE_FLAG $REGION_FLAG \
        --query 'Subnet.SubnetId' --output text)

      aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" \
        --map-public-ip-on-launch $PROFILE_FLAG $REGION_FLAG

      aws ec2 associate-route-table --route-table-id "$RT_ID" --subnet-id "$SUBNET_ID" \
        $PROFILE_FLAG $REGION_FLAG > /dev/null

      aws ec2 create-tags --resources "$SUBNET_ID" \
        --tags Key=Name,Value="${SUBNET_NAME}" \
        $PROFILE_FLAG $REGION_FLAG
      echo "Subnet created in ${AZ}: $SUBNET_ID"
    fi
  done

  echo ""
  echo "VPC setup complete!"
  echo "  VPC: $VPC_ID (${TAG_PREFIX})"
  echo "  Internet Gateway: $IGW_ID (${TAG_PREFIX}-igw)"
  echo "  Route Table: $RT_ID (${TAG_PREFIX}-rt)"
  echo "  Subnets: 2 across ${AZS[0]} and ${AZS[1]}"

# Create S3 bucket and DynamoDB table for Terraform remote state backend
[group('aws-terraform')]
aws-tf-setup-backend service profile='default':
  #!/usr/bin/env bash
  set -e

  SERVICE="{{service}}"
  AWS_PROFILE="{{profile}}"

  PROFILE_FLAG=""
  if [[ "$AWS_PROFILE" != "default" ]]; then
    PROFILE_FLAG="--profile $AWS_PROFILE"
  fi

  # Check AWS CLI
  if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI not found. Please install AWS CLI first."
    exit 1
  fi

  if ! aws sts get-caller-identity $PROFILE_FLAG &> /dev/null; then
    echo "Error: AWS CLI not configured for profile '$AWS_PROFILE'. Run 'aws configure --profile $AWS_PROFILE' first."
    exit 1
  fi

  echo "AWS CLI configured for profile: $AWS_PROFILE"

  # Get AWS account info
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity $PROFILE_FLAG --query Account --output text)
  AWS_REGION=$(aws configure get region $PROFILE_FLAG 2>/dev/null || echo "us-east-1")

  echo ""
  echo "Terraform S3 Backend Setup"
  echo "=========================="
  echo "  Service: $SERVICE"
  echo "  Profile: $AWS_PROFILE"
  echo "  Account ID: $AWS_ACCOUNT_ID"
  echo "  Region: $AWS_REGION"

  # Generate standard names
  BUCKET_NAME="${AWS_ACCOUNT_ID}-${SERVICE}-terraform-state"
  TABLE_NAME="${SERVICE}-terraform-state-lock"

  echo ""
  echo "Resources to create:"
  echo "  S3 Bucket: $BUCKET_NAME"
  echo "  DynamoDB Table: $TABLE_NAME"
  echo ""

  echo -n "Proceed? (y/N): "
  read confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
  fi

  # Create S3 bucket (idempotent)
  echo ""
  echo "Creating S3 bucket: $BUCKET_NAME"
  if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" $PROFILE_FLAG 2>/dev/null; then
    echo "S3 bucket '$BUCKET_NAME' already exists"
  else
    if [[ "$AWS_REGION" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" $PROFILE_FLAG
    else
      aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION" $PROFILE_FLAG
    fi

    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" \
      --versioning-configuration Status=Enabled $PROFILE_FLAG

    aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" \
      --server-side-encryption-configuration '{
        "Rules": [{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]
      }' $PROFILE_FLAG

    aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
      --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
      $PROFILE_FLAG

    echo "S3 bucket created with versioning, encryption, and public access blocked"
  fi

  # Create DynamoDB table (idempotent)
  echo ""
  echo "Creating DynamoDB table: $TABLE_NAME"
  if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" $PROFILE_FLAG 2>/dev/null; then
    echo "DynamoDB table '$TABLE_NAME' already exists"
  else
    aws dynamodb create-table \
      --table-name "$TABLE_NAME" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region "$AWS_REGION" $PROFILE_FLAG

    echo "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$AWS_REGION" $PROFILE_FLAG
    echo "DynamoDB table created"
  fi

  echo ""
  echo "Backend setup complete!"
  echo "  S3 Bucket: $BUCKET_NAME"
  echo "  DynamoDB Table: $TABLE_NAME"
  echo "  Region: $AWS_REGION"
  echo ""
  echo "Next: run 'tn aws-tf-init-backend $SERVICE <environment>' to initialize Terraform"
# Initialize Terraform with the correct backend configuration for an environment
[group('aws-terraform')]
aws-tf-init-backend service environment='development' profile='default' region='us-east-1' force='false':
  #!/usr/bin/env bash
  set -e

  SERVICE="{{service}}"
  ENVIRONMENT="{{environment}}"
  AWS_PROFILE="{{profile}}"
  AWS_REGION="{{region}}"
  FORCE="{{force}}"

  PROFILE_FLAG=""
  if [[ "$AWS_PROFILE" != "default" ]]; then
    PROFILE_FLAG="--profile $AWS_PROFILE"
  fi

  # Get AWS account ID
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity $PROFILE_FLAG --query Account --output text)

  # Derive backend resource names (must match setup-backend convention)
  BUCKET="${AWS_ACCOUNT_ID}-${SERVICE}-terraform-state"
  TABLE="${SERVICE}-terraform-state-lock"
  # Use a static key — workspaces handle environment isolation
  # (Terraform stores state at env:/<workspace>/terraform.tfstate)
  STATE_KEY="terraform.tfstate"

  echo "Terraform Backend Initialization"
  echo "=================================="
  echo "  Service: $SERVICE"
  echo "  Environment: $ENVIRONMENT"
  echo "  AWS Profile: $AWS_PROFILE"
  echo "  State Key: $STATE_KEY"
  echo "  S3 Bucket: $BUCKET"
  echo "  DynamoDB Table: $TABLE"
  echo "  Region: $AWS_REGION"
  echo ""

  # Test AWS access
  echo "Testing AWS access..."
  AWS_IDENTITY=$(aws sts get-caller-identity $PROFILE_FLAG 2>/dev/null || echo "FAILED")
  if [[ "$AWS_IDENTITY" == "FAILED" ]]; then
    echo "Error: Failed to get AWS caller identity"
    exit 1
  fi
  echo "AWS Identity verified: $(echo "$AWS_IDENTITY" | jq -r '.Arn')"

  # Test DynamoDB table access
  echo "Testing DynamoDB table access..."
  if aws dynamodb describe-table --table-name "$TABLE" --region "$AWS_REGION" $PROFILE_FLAG &>/dev/null; then
    echo "DynamoDB table accessible: $TABLE"
  else
    echo "Error: DynamoDB table not accessible: $TABLE"
    echo "Tip: Run 'tn aws-tf-setup-backend $SERVICE' first"
    exit 1
  fi

  # Generate backend.hcl for CI (idempotent — same values for all environments)
  BACKEND_HCL="terraform/backend.hcl"
  if [[ ! -f "$BACKEND_HCL" ]]; then
    echo "Generating $BACKEND_HCL for CI..."
    printf 'bucket         = "%s"\nregion         = "%s"\ndynamodb_table = "%s"\nencrypt        = true\n' \
      "$BUCKET" "$AWS_REGION" "$TABLE" > "$BACKEND_HCL"
    echo "Created $BACKEND_HCL — commit this file to your repo"
  else
    echo "Backend config already exists: $BACKEND_HCL"
  fi

  # Build backend config args
  BACKEND_ARGS="-backend-config=\"bucket=${BUCKET}\""
  BACKEND_ARGS+=" -backend-config=\"key=${STATE_KEY}\""
  BACKEND_ARGS+=" -backend-config=\"region=${AWS_REGION}\""
  BACKEND_ARGS+=" -backend-config=\"dynamodb_table=${TABLE}\""
  BACKEND_ARGS+=" -backend-config=\"encrypt=true\""

  if [[ "$AWS_PROFILE" != "default" ]]; then
    BACKEND_ARGS+=" -backend-config=\"profile=${AWS_PROFILE}\""
  fi

  if [[ "$FORCE" == "true" ]]; then
    BACKEND_ARGS+=" -migrate-state"
  fi

  echo ""
  echo "Running terraform init..."
  cd terraform
  eval "terraform init ${BACKEND_ARGS}"

  echo ""
  echo "Backend initialized!"
  echo "  State Location: s3://${BUCKET}/${STATE_KEY}"
  echo "  Lock Table: ${TABLE}"
  echo "  Environment: ${ENVIRONMENT}"
# Delete orphaned AWS resources from a failed Terraform apply.
# Finds resources by naming convention ({service}-{environment}) and deletes them.
# Safe for fresh environments with no user data.
[group('aws-terraform')]
aws-tf-cleanup service environment profile='default' region='us-east-1' dry_run='true':
  #!/usr/bin/env bash
  set -e

  SERVICE="{{service}}"
  ENVIRONMENT="{{environment}}"
  AWS_PROFILE="{{profile}}"
  AWS_REGION="{{region}}"
  DRY_RUN="{{dry_run}}"

  run_aws() {
    if [[ "$AWS_PROFILE" != "default" && -n "$AWS_PROFILE" ]]; then
      aws --profile "$AWS_PROFILE" --region "$AWS_REGION" "$@"
    else
      aws --region "$AWS_REGION" "$@"
    fi
  }

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 DRY RUN — showing what would be deleted (pass dry_run=false to delete)"
  else
    echo "⚠️  DESTRUCTIVE — deleting orphaned resources for ${SERVICE}-${ENVIRONMENT}"
  fi
  echo ""

  FOUND=0

  # 1. ECS services and cluster
  CLUSTER="cluster-${SERVICE}-${ENVIRONMENT}"
  if run_aws ecs describe-clusters --clusters "$CLUSTER" --query 'clusters[?status==`ACTIVE`].clusterName' --output text 2>/dev/null | grep -q "$CLUSTER"; then
    FOUND=$((FOUND+1))
    echo "📦 ECS cluster: $CLUSTER"
    # Stop services first
    for SVC in $(run_aws ecs list-services --cluster "$CLUSTER" --query 'serviceArns[]' --output text 2>/dev/null); do
      SVC_NAME=$(basename "$SVC")
      echo "   Service: $SVC_NAME"
      if [[ "$DRY_RUN" == "false" ]]; then
        run_aws ecs update-service --cluster "$CLUSTER" --service "$SVC_NAME" --desired-count 0 >/dev/null 2>&1 || true
        run_aws ecs delete-service --cluster "$CLUSTER" --service "$SVC_NAME" --force >/dev/null 2>&1 || true
        echo "   ✅ Deleted service: $SVC_NAME"
      fi
    done
    if [[ "$DRY_RUN" == "false" ]]; then
      run_aws ecs delete-cluster --cluster "$CLUSTER" >/dev/null 2>&1 || true
      echo "   ✅ Deleted cluster: $CLUSTER"
    fi
  fi

  # 2. ALB and listeners
  ALB_ARN=$(run_aws elbv2 describe-load-balancers --query "LoadBalancers[?starts_with(LoadBalancerName, '${SERVICE}-${ENVIRONMENT}')].LoadBalancerArn" --output text 2>/dev/null || echo "")
  if [[ -n "$ALB_ARN" && "$ALB_ARN" != "None" ]]; then
    FOUND=$((FOUND+1))
    ALB_NAME=$(run_aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].LoadBalancerName' --output text)
    echo "⚖️  ALB: $ALB_NAME"
    if [[ "$DRY_RUN" == "false" ]]; then
      # Delete listeners first
      for LISTENER in $(run_aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query 'Listeners[].ListenerArn' --output text 2>/dev/null); do
        run_aws elbv2 delete-listener --listener-arn "$LISTENER" >/dev/null 2>&1 || true
      done
      run_aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" >/dev/null 2>&1 || true
      echo "   ✅ Deleted ALB: $ALB_NAME"
    fi
  fi

  # 3. Target groups
  for TG_ARN in $(run_aws elbv2 describe-target-groups --query "TargetGroups[?starts_with(TargetGroupName, 'http-${SERVICE}-${ENVIRONMENT}')].TargetGroupArn" --output text 2>/dev/null); do
    if [[ -n "$TG_ARN" && "$TG_ARN" != "None" ]]; then
      FOUND=$((FOUND+1))
      TG_NAME=$(run_aws elbv2 describe-target-groups --target-group-arns "$TG_ARN" --query 'TargetGroups[0].TargetGroupName' --output text)
      echo "🎯 Target group: $TG_NAME"
      if [[ "$DRY_RUN" == "false" ]]; then
        run_aws elbv2 delete-target-group --target-group-arn "$TG_ARN" >/dev/null 2>&1 || true
        echo "   ✅ Deleted target group: $TG_NAME"
      fi
    fi
  done

  # 4. RDS instance
  DB_ID="db-${SERVICE}-${ENVIRONMENT}"
  if run_aws rds describe-db-instances --db-instance-identifier "$DB_ID" >/dev/null 2>&1; then
    FOUND=$((FOUND+1))
    echo "🗄️  RDS instance: $DB_ID"
    if [[ "$DRY_RUN" == "false" ]]; then
      run_aws rds delete-db-instance --db-instance-identifier "$DB_ID" --skip-final-snapshot --delete-automated-backups >/dev/null 2>&1 || true
      echo "   ⏳ Deleting RDS (takes several minutes)..."
    fi
  fi

  # 5. ElastiCache cluster
  REDIS_ID="redis-${SERVICE}-${ENVIRONMENT}"
  if run_aws elasticache describe-cache-clusters --cache-cluster-id "$REDIS_ID" >/dev/null 2>&1; then
    FOUND=$((FOUND+1))
    echo "🔴 ElastiCache cluster: $REDIS_ID"
    if [[ "$DRY_RUN" == "false" ]]; then
      run_aws elasticache delete-cache-cluster --cache-cluster-id "$REDIS_ID" >/dev/null 2>&1 || true
      echo "   ⏳ Deleting ElastiCache (takes several minutes)..."
    fi
  fi

  # 6. Security groups (delete last — other resources reference them)
  VPC_ID=$(run_aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*shared*dev*" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")
  if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then
    SG_PATTERNS=("ecs-lb-sg-${SERVICE}-${ENVIRONMENT}" "ecs-app-${SERVICE}-${ENVIRONMENT}" "rds-sg-${SERVICE}-${ENVIRONMENT}" "redis-sg-${SERVICE}-${ENVIRONMENT}")
    for SG_NAME in "${SG_PATTERNS[@]}"; do
      SG_ID=$(run_aws ec2 describe-security-groups --filters "Name=group-name,Values=${SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
      if [[ -n "$SG_ID" && "$SG_ID" != "None" ]]; then
        FOUND=$((FOUND+1))
        echo "🔒 Security group: $SG_NAME ($SG_ID)"
        if [[ "$DRY_RUN" == "false" ]]; then
          run_aws ec2 delete-security-group --group-id "$SG_ID" >/dev/null 2>&1 || echo "   ⚠️  Could not delete $SG_NAME (may have dependencies — retry after RDS/ElastiCache finish deleting)"
          echo "   ✅ Deleted security group: $SG_NAME"
        fi
      fi
    done
  fi

  # 7. DB subnet group
  DB_SUBNET="db-subnet-${SERVICE}-${ENVIRONMENT}"
  if run_aws rds describe-db-subnet-groups --db-subnet-group-name "$DB_SUBNET" >/dev/null 2>&1; then
    FOUND=$((FOUND+1))
    echo "🌐 DB subnet group: $DB_SUBNET"
    if [[ "$DRY_RUN" == "false" ]]; then
      run_aws rds delete-db-subnet-group --db-subnet-group-name "$DB_SUBNET" >/dev/null 2>&1 || echo "   ⚠️  Could not delete (RDS may still be deleting)"
    fi
  fi

  # 8. ElastiCache subnet group
  REDIS_SUBNET="redis-subnet-${SERVICE}-${ENVIRONMENT}"
  if run_aws elasticache describe-cache-subnet-groups --cache-subnet-group-name "$REDIS_SUBNET" >/dev/null 2>&1; then
    FOUND=$((FOUND+1))
    echo "🌐 ElastiCache subnet group: $REDIS_SUBNET"
    if [[ "$DRY_RUN" == "false" ]]; then
      run_aws elasticache delete-cache-subnet-group --cache-subnet-group-name "$REDIS_SUBNET" >/dev/null 2>&1 || echo "   ⚠️  Could not delete (ElastiCache may still be deleting)"
    fi
  fi

  # 9. CloudWatch log group
  LOG_GROUP="/ecs/${SERVICE}/${ENVIRONMENT}"
  if run_aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --query "logGroups[?logGroupName=='${LOG_GROUP}'].logGroupName" --output text 2>/dev/null | grep -q "$LOG_GROUP"; then
    FOUND=$((FOUND+1))
    echo "📝 Log group: $LOG_GROUP"
    if [[ "$DRY_RUN" == "false" ]]; then
      run_aws logs delete-log-group --log-group-name "$LOG_GROUP" >/dev/null 2>&1 || true
      echo "   ✅ Deleted log group"
    fi
  fi

  # 10. Secrets Manager secrets
  for SECRET_NAME in $(run_aws secretsmanager list-secrets --filters "Key=name,Values=${SERVICE}-${ENVIRONMENT}" --query 'SecretList[].Name' --output text 2>/dev/null); do
    if [[ -n "$SECRET_NAME" && "$SECRET_NAME" != "None" ]]; then
      FOUND=$((FOUND+1))
      echo "🔑 Secret: $SECRET_NAME"
      if [[ "$DRY_RUN" == "false" ]]; then
        run_aws secretsmanager delete-secret --secret-id "$SECRET_NAME" --force-delete-without-recovery >/dev/null 2>&1 || true
        echo "   ✅ Deleted secret: $SECRET_NAME"
      fi
    fi
  done

  echo ""
  if [[ $FOUND -eq 0 ]]; then
    echo "✅ No orphaned resources found for ${SERVICE}-${ENVIRONMENT}"
  elif [[ "$DRY_RUN" == "true" ]]; then
    echo "Found $FOUND orphaned resource(s). Run with dry_run=false to delete:"
    echo "  tn aws-tf-cleanup ${SERVICE} ${ENVIRONMENT} dry_run=false"
    echo ""
    echo "Note: Security groups may fail on first attempt if RDS/ElastiCache"
    echo "are still deleting. Re-run after a few minutes to clean those up."
  else
    echo "🧹 Cleanup initiated for $FOUND resource(s)"
    echo "RDS and ElastiCache take several minutes to fully delete."
    echo "Re-run to clean up security groups and subnet groups after they finish."
  fi
# Create GitHub Actions OIDC IAM role for a given org and environment.
# Can also be re-run to update an existing OIDC role with a new secrets bucket for a new project.
[group('aws-terraform')]
aws-setup-oidc service github_org secrets_bucket environment='development' profile='default' repo='':
  #!/usr/bin/env bash
  set -e

  SERVICE="{{service}}"
  GITHUB_ORG="{{github_org}}"
  ENVIRONMENT="{{environment}}"
  SECRETS_BUCKET="{{secrets_bucket}}"
  AWS_PROFILE="{{profile}}"
  REPO="{{repo}}"

  if [[ -z "$SERVICE" ]]; then
    echo "Error: service is required (e.g., 'my-project')"
    exit 1
  fi

  if [[ -z "$GITHUB_ORG" ]]; then
    echo "Error: github_org is required"
    exit 1
  fi

  # Default repo to github_org/service if not provided
  if [[ -z "$REPO" ]]; then
    REPO="${GITHUB_ORG}/${SERVICE}"
  fi

  # Set up AWS command helper
  run_aws() {
    if [[ "$AWS_PROFILE" != "default" && -n "$AWS_PROFILE" ]]; then
      aws --profile "$AWS_PROFILE" "$@"
    else
      aws "$@"
    fi
  }

  ACCOUNT_ID=$(run_aws sts get-caller-identity --query Account --output text)
  ROLE_NAME="github-actions-${SERVICE}-${ENVIRONMENT}"

  echo "GitHub Actions OIDC Setup"
  echo "========================="
  echo "  Service: $SERVICE"
  echo "  GitHub Org: $GITHUB_ORG"
  echo "  GitHub Repo: $REPO"
  echo "  Environment: $ENVIRONMENT"
  echo "  AWS Account: $ACCOUNT_ID"
  echo "  Role Name: $ROLE_NAME"
  echo "  AWS Profile: $AWS_PROFILE"
  if [[ -n "$SECRETS_BUCKET" ]]; then
    echo "  Secrets Bucket: $SECRETS_BUCKET"
  fi
  echo ""

  # 1. Create OIDC Identity Provider (idempotent)
  echo "Creating OIDC Identity Provider..."
  if run_aws iam get-open-id-connect-provider \
    --open-id-connect-provider-arn "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" &>/dev/null; then
    echo "OIDC provider already exists"
  else
    run_aws iam create-open-id-connect-provider \
      --url https://token.actions.githubusercontent.com \
      --client-id-list sts.amazonaws.com \
      --thumbprint-list 1c58a3a8518e8759bf075b76b750d4f2df264fcd
    echo "OIDC provider created"
  fi

  # 2. Create or update IAM Role (idempotent)
  echo ""
  echo "Processing IAM Role: $ROLE_NAME"
  # GitHub OIDC sub claims now include numeric IDs: org@ID/repo@ID
  # Use wildcards after org and repo names to match both old and new formats
  REPO_CONDITION="repo:${GITHUB_ORG}*/${SERVICE}*:*"
  if run_aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    echo "Role $ROLE_NAME already exists"
    # Check if this specific repo already in trust policy
    TRUST_POLICY=$(run_aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json)
    if echo "$TRUST_POLICY" | grep -q "repo:${REPO}:"; then
      echo "Repo '$REPO' already has access in trust policy"
    else
      echo "Adding repo '$REPO' to trust policy..."
      echo "$TRUST_POLICY" | jq --arg repo_cond "$REPO_CONDITION" '
        (.Statement[0].Condition.StringLike["token.actions.githubusercontent.com:sub"]) |=
        if type == "string" then [., $repo_cond]
        elif type == "array" then . + [$repo_cond]
        else $repo_cond
        end
      ' > /tmp/oidc-trust-policy.json
      run_aws iam update-assume-role-policy --role-name "$ROLE_NAME" \
        --policy-document file:///tmp/oidc-trust-policy.json
      rm -f /tmp/oidc-trust-policy.json
      echo "Trust policy updated — added repo: $REPO"
    fi
  else
    jq -n --arg account "$ACCOUNT_ID" --arg repo_cond "$REPO_CONDITION" '{
      Version: "2012-10-17",
      Statement: [{
        Effect: "Allow",
        Principal: { Federated: "arn:aws:iam::\($account):oidc-provider/token.actions.githubusercontent.com" },
        Action: "sts:AssumeRoleWithWebIdentity",
        Condition: {
          StringEquals: { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
          StringLike: { "token.actions.githubusercontent.com:sub": $repo_cond }
        }
      }]
    }' > /tmp/oidc-trust-policy.json
    run_aws iam create-role --role-name "$ROLE_NAME" \
      --assume-role-policy-document file:///tmp/oidc-trust-policy.json
    rm -f /tmp/oidc-trust-policy.json
    echo "IAM role created: $ROLE_NAME (trust scoped to repo: $REPO)"
  fi

  # 3. Create and attach deployment policy (idempotent)
  echo ""
  echo "Creating deployment policy..."
  POLICY_NAME="${ROLE_NAME}-deployment-policy"
  POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

  jq -n '{
    Version: "2012-10-17",
    Statement: [
      {Sid: "ECRFullAccess", Effect: "Allow", Action: ["ecr:*"], Resource: "*"},
      {Sid: "ECSFullAccess", Effect: "Allow", Action: ["ecs:*"], Resource: "*"},
      {Sid: "EC2Access", Effect: "Allow", Action: ["ec2:*"], Resource: "*"},
      {Sid: "RDSAccess", Effect: "Allow", Action: ["rds:*"], Resource: "*"},
      {Sid: "ACMAccess", Effect: "Allow", Action: ["acm:*"], Resource: "*"},
      {Sid: "IAMAccess", Effect: "Allow", Action: ["iam:*"], Resource: "*"},
      {Sid: "SecretsManagerAccess", Effect: "Allow", Action: ["secretsmanager:*"], Resource: "*"},
      {Sid: "CloudWatchLogsAccess", Effect: "Allow", Action: ["logs:*"], Resource: "*"},
      {Sid: "S3FullAccess", Effect: "Allow", Action: ["s3:*"], Resource: "*"},
      {Sid: "DynamoDBAccess", Effect: "Allow", Action: ["dynamodb:*"], Resource: "*"},
      {Sid: "ELBAccess", Effect: "Allow", Action: ["elasticloadbalancing:*"], Resource: "*"},
      {Sid: "ElastiCacheAccess", Effect: "Allow", Action: ["elasticache:*"], Resource: "*"},
      {Sid: "Route53Access", Effect: "Allow", Action: ["route53:*"], Resource: "*"},
      {Sid: "EventBridgeAccess", Effect: "Allow", Action: ["events:*"], Resource: "*"},
      {Sid: "SNSAccess", Effect: "Allow", Action: ["sns:*"], Resource: "*"},
      {Sid: "CloudWatchAccess", Effect: "Allow", Action: ["cloudwatch:*"], Resource: "*"},
      {Sid: "STSAccess", Effect: "Allow", Action: ["sts:GetCallerIdentity"], Resource: "*"}
    ]
  }' > /tmp/oidc-deploy-policy.json

  # Delete existing policy if it exists (idempotent)
  if run_aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    run_aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN" 2>/dev/null || true
    run_aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
      --query 'Versions[?!IsDefaultVersion].[VersionId]' --output text | while read version; do
      run_aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$version" 2>/dev/null || true
    done
    run_aws iam delete-policy --policy-arn "$POLICY_ARN" 2>/dev/null || true
  fi

  run_aws iam create-policy --policy-name "$POLICY_NAME" \
    --policy-document file:///tmp/oidc-deploy-policy.json
  run_aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"
  rm -f /tmp/oidc-deploy-policy.json
  echo "Deployment policy attached"

  # 4. Create secrets policy (idempotent)
  echo ""
  echo "Creating S3 secrets policy..."
  SECRETS_POLICY_NAME="${ROLE_NAME}-secrets-access"
  SECRETS_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${SECRETS_POLICY_NAME}"

  jq -n --arg bucket "$SECRETS_BUCKET" --arg env "$ENVIRONMENT" '{
    Version: "2012-10-17",
    Statement: [
      {Sid: "SecretsS3Access", Effect: "Allow", Action: ["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:GetObjectVersion"], Resource: ["arn:aws:s3:::\($bucket)/\($env)/*"]},
      {Sid: "AllowListBucketForEnv", Effect: "Allow", Action: "s3:ListBucket", Resource: "arn:aws:s3:::\($bucket)", Condition: {StringLike: {"s3:prefix": "\($env)/*"}}},
      {Sid: "AllowListBuckets", Effect: "Allow", Action: "s3:ListAllMyBuckets", Resource: "*"}
    ]
  }' > /tmp/oidc-secrets-policy.json

  if run_aws iam get-policy --policy-arn "$SECRETS_POLICY_ARN" &>/dev/null; then
    run_aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$SECRETS_POLICY_ARN" 2>/dev/null || true
    run_aws iam list-policy-versions --policy-arn "$SECRETS_POLICY_ARN" \
      --query 'Versions[?!IsDefaultVersion].[VersionId]' --output text | while read version; do
      run_aws iam delete-policy-version --policy-arn "$SECRETS_POLICY_ARN" --version-id "$version" 2>/dev/null || true
    done
    run_aws iam delete-policy --policy-arn "$SECRETS_POLICY_ARN" 2>/dev/null || true
  fi

  run_aws iam create-policy --policy-name "$SECRETS_POLICY_NAME" \
    --policy-document file:///tmp/oidc-secrets-policy.json
  run_aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$SECRETS_POLICY_ARN"
  rm -f /tmp/oidc-secrets-policy.json
  echo "Secrets policy attached"

  # Summary
  ROLE_ARN=$(run_aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)
  echo ""
  echo "Setup complete!"
  echo "  Role ARN: $ROLE_ARN"
  echo ""
  echo "Copy this Role ARN into your .github/environments.json:"
  echo "  \"role_arn\": \"$ROLE_ARN\""
  echo ""
  echo "Set it under the '$ENVIRONMENT' key alongside account_id, secrets_bucket, and region."
# Create IAM group + read-only CloudWatch Logs policy for a project.
# Lets team members view logs without full AWS admin access.
[group('aws-terraform')]
aws-setup-log-viewer service profile='default' region='us-east-1':
  #!/usr/bin/env bash
  set -e

  SERVICE="{{service}}"
  AWS_PROFILE="{{profile}}"
  AWS_REGION="{{region}}"

  if [[ -z "$SERVICE" ]]; then
    echo "Error: service is required (e.g., 'my-project')"
    exit 1
  fi

  # Set up AWS command helper
  run_aws() {
    if [[ "$AWS_PROFILE" != "default" && -n "$AWS_PROFILE" ]]; then
      aws --profile "$AWS_PROFILE" --region "$AWS_REGION" "$@"
    else
      aws --region "$AWS_REGION" "$@"
    fi
  }

  ACCOUNT_ID=$(run_aws sts get-caller-identity --query Account --output text)
  POLICY_NAME="${SERVICE}-log-viewer"
  POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
  GROUP_NAME="${SERVICE}-log-viewers"

  echo "CloudWatch Log Viewer Setup"
  echo "==========================="
  echo "  Service: $SERVICE"
  echo "  AWS Account: $ACCOUNT_ID"
  echo "  AWS Region: $AWS_REGION"
  echo "  Policy: $POLICY_NAME"
  echo "  Group: $GROUP_NAME"
  echo "  Log Scope: /ecs/${SERVICE}/*"
  echo ""

  # 1. Create or update IAM policy (idempotent — delete + recreate)
  echo "Creating log viewer policy..."
  LOG_GROUP_ARN="arn:aws:logs:${AWS_REGION}:${ACCOUNT_ID}:log-group:/ecs/${SERVICE}/*"

  jq -n --arg lg_arn "$LOG_GROUP_ARN" '{
    Version: "2012-10-17",
    Statement: [
      {
        Sid: "DescribeLogGroups",
        Effect: "Allow",
        Action: ["logs:DescribeLogGroups"],
        Resource: "*"
      },
      {
        Sid: "ReadLogStreams",
        Effect: "Allow",
        Action: [
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:StopQuery"
        ],
        Resource: $lg_arn
      }
    ]
  }' > /tmp/log-viewer-policy.json

  if run_aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    echo "Policy already exists, updating..."
    # Detach from group before deleting
    run_aws iam detach-group-policy --group-name "$GROUP_NAME" --policy-arn "$POLICY_ARN" 2>/dev/null || true
    # Clean up non-default versions
    run_aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
      --query 'Versions[?!IsDefaultVersion].[VersionId]' --output text | while read version; do
      run_aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$version" 2>/dev/null || true
    done
    run_aws iam delete-policy --policy-arn "$POLICY_ARN" 2>/dev/null || true
  fi

  run_aws iam create-policy --policy-name "$POLICY_NAME" \
    --policy-document file:///tmp/log-viewer-policy.json --output text --query 'Policy.Arn'
  rm -f /tmp/log-viewer-policy.json
  echo "Policy created: $POLICY_NAME"

  # 2. Create IAM group (idempotent)
  echo ""
  echo "Creating log viewer group..."
  if run_aws iam get-group --group-name "$GROUP_NAME" &>/dev/null; then
    echo "Group already exists: $GROUP_NAME"
  else
    run_aws iam create-group --group-name "$GROUP_NAME"
    echo "Group created: $GROUP_NAME"
  fi

  # 3. Attach policy to group
  run_aws iam attach-group-policy --group-name "$GROUP_NAME" --policy-arn "$POLICY_ARN"
  echo "Policy attached to group"

  # Summary
  echo ""
  echo "Setup complete!"
  echo ""
  echo "Add a user to the group:"
  echo "  aws iam add-user-to-group --group-name $GROUP_NAME --user-name <username>"
  echo ""
  echo "Remove a user from the group:"
  echo "  aws iam remove-user-from-group --group-name $GROUP_NAME --user-name <username>"
  echo ""
  echo "Users in this group can view CloudWatch logs under /ecs/${SERVICE}/*"
  echo "using the AWS Console or the tn CLI:"
  echo "  tn aws-stream-logs $SERVICE <environment>"
# Add an IAM user to a project's log-viewer group (creates the user if needed)
[group('aws-terraform')]
aws-add-log-viewer service username profile='default' region='us-east-1':
  #!/usr/bin/env bash
  set -e

  SERVICE="{{service}}"
  USERNAME="{{username}}"
  AWS_PROFILE="{{profile}}"
  AWS_REGION="{{region}}"

  if [[ -z "$SERVICE" || -z "$USERNAME" ]]; then
    echo "Error: service and username are required"
    echo "Usage: tn aws-add-log-viewer <service> <username>"
    exit 1
  fi

  run_aws() {
    if [[ "$AWS_PROFILE" != "default" && -n "$AWS_PROFILE" ]]; then
      aws --profile "$AWS_PROFILE" --region "$AWS_REGION" "$@"
    else
      aws --region "$AWS_REGION" "$@"
    fi
  }

  GROUP_NAME="${SERVICE}-log-viewers"

  # Verify the group exists
  if ! run_aws iam get-group --group-name "$GROUP_NAME" &>/dev/null; then
    echo "Error: Group '$GROUP_NAME' does not exist."
    echo "Run 'tn aws-setup-log-viewer $SERVICE' first."
    exit 1
  fi

  # Create IAM user if it doesn't exist
  if run_aws iam get-user --user-name "$USERNAME" &>/dev/null; then
    echo "User '$USERNAME' already exists"
  else
    echo "Creating IAM user '$USERNAME'..."
    run_aws iam create-user --user-name "$USERNAME" --output text --query 'User.Arn'
    echo "✅ User created"
  fi

  # Add to group
  echo "Adding '$USERNAME' to group '$GROUP_NAME'..."
  run_aws iam add-user-to-group --group-name "$GROUP_NAME" --user-name "$USERNAME"
  echo "✅ Added to group"

  # Generate access keys
  echo ""
  echo "Generating access keys..."
  KEYS=$(run_aws iam create-access-key --user-name "$USERNAME" --output json)

  ACCESS_KEY=$(echo "$KEYS" | jq -r '.AccessKey.AccessKeyId')
  SECRET_KEY=$(echo "$KEYS" | jq -r '.AccessKey.SecretAccessKey')

  echo ""
  echo "============================================="
  echo "  Credentials for $USERNAME"
  echo "============================================="
  echo ""
  echo "Add this to ~/.aws/credentials:"
  echo ""
  echo "  [$SERVICE]"
  echo "  aws_access_key_id = $ACCESS_KEY"
  echo "  aws_secret_access_key = $SECRET_KEY"
  echo ""
  echo "Then use:"
  echo "  tn aws-stream-logs $SERVICE <environment> $SERVICE $AWS_REGION"
  echo "  tn aws-ecs-events $SERVICE <environment> $SERVICE $AWS_REGION"
  echo ""
  echo "⚠️  Save these credentials now — the secret key cannot be retrieved again."
  echo "============================================="

# Create S3 bucket for secrets storage with proper security
[group('aws-terraform')]
aws-setup-secrets service environment profile='default' region='us-east-1':
  #!/usr/bin/env bash
  set -e

  SERVICE="{{service}}"
  ENVIRONMENT="{{environment}}"
  AWS_PROFILE="{{profile}}"
  AWS_REGION="{{region}}"

  PROFILE_FLAG=""
  if [[ "$AWS_PROFILE" != "default" ]]; then
    PROFILE_FLAG="--profile $AWS_PROFILE"
  fi

  AWS_ACCOUNT_ID=$(aws sts get-caller-identity $PROFILE_FLAG --query Account --output text)
  SECRETS_BUCKET="${SERVICE}-terraform-secrets"

  echo "S3 Secrets Bucket Setup"
  echo "========================"
  echo "  Service: $SERVICE"
  echo "  Environment: $ENVIRONMENT"
  echo "  Account ID: $AWS_ACCOUNT_ID"
  echo "  Region: $AWS_REGION"
  echo "  Bucket: $SECRETS_BUCKET"
  echo ""

  # Create bucket (idempotent)
  if aws s3api head-bucket --bucket "$SECRETS_BUCKET" $PROFILE_FLAG 2>/dev/null; then
    echo "Bucket '$SECRETS_BUCKET' already exists"
  else
    echo "Creating S3 bucket: $SECRETS_BUCKET"
    if [[ "$AWS_REGION" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$SECRETS_BUCKET" $PROFILE_FLAG
    else
      aws s3api create-bucket --bucket "$SECRETS_BUCKET" --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION" $PROFILE_FLAG
    fi

    # Enable versioning
    aws s3api put-bucket-versioning --bucket "$SECRETS_BUCKET" \
      --versioning-configuration Status=Enabled $PROFILE_FLAG

    # Enable encryption
    aws s3api put-bucket-encryption --bucket "$SECRETS_BUCKET" \
      --server-side-encryption-configuration '{
        "Rules": [{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]
      }' $PROFILE_FLAG

    # Block public access
    aws s3api put-public-access-block --bucket "$SECRETS_BUCKET" \
      --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
      $PROFILE_FLAG

    echo "Bucket created with versioning, encryption, and public access blocked"
  fi

  # Create/update bucket policy for OIDC role access (idempotent)
  ROLE_NAME="github-actions-${SERVICE}-${ENVIRONMENT}"
  ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"

  echo ""
  echo "Setting bucket policy for role: $ROLE_NAME"

  # Get existing policy or start fresh
  EXISTING_POLICY=$(aws s3api get-bucket-policy --bucket "$SECRETS_BUCKET" --query 'Policy' --output text $PROFILE_FLAG 2>/dev/null || echo "")

  if [[ -n "$EXISTING_POLICY" ]]; then
    BASE_POLICY="$EXISTING_POLICY"
  else
    BASE_POLICY='{"Version":"2012-10-17","Statement":[]}'
  fi

  echo "$BASE_POLICY" | jq \
    --arg env "$ENVIRONMENT" \
    --arg role "$ROLE_ARN" \
    --arg bucket "$SECRETS_BUCKET" \
    --arg region "$AWS_REGION" '
    .Statement = [.Statement[] | select(.Principal.AWS != $role)] +
    [
      {
        Sid: "AllowAccess\($env)",
        Effect: "Allow",
        Principal: {AWS: $role},
        Action: ["s3:GetObject","s3:PutObject","s3:DeleteObject"],
        Resource: ["arn:aws:s3:::\($bucket)/\($env)/*"],
        Condition: {StringEquals: {"aws:RequestedRegion": $region}}
      },
      {
        Sid: "AllowList\($env)",
        Effect: "Allow",
        Principal: {AWS: $role},
        Action: ["s3:ListBucket"],
        Resource: ["arn:aws:s3:::\($bucket)"],
        Condition: {StringEquals: {"aws:RequestedRegion": $region}, StringLike: {"s3:prefix": "\($env)/*"}}
      }
    ]
  ' > /tmp/secrets-bucket-policy.json
  aws s3api put-bucket-policy --bucket "$SECRETS_BUCKET" \
    --policy file:///tmp/secrets-bucket-policy.json $PROFILE_FLAG
  rm -f /tmp/secrets-bucket-policy.json

  echo "Bucket policy updated for environment: $ENVIRONMENT"
  echo ""
  echo "Secrets bucket setup complete!"
  echo "  Bucket: $SECRETS_BUCKET"
  echo "  Environment: $ENVIRONMENT"
  echo "  Role: $ROLE_NAME"
# Connect to a running ECS task via ECS Exec
[group('aws-terraform')]
aws-ecs-exec service environment='development' profile='default' region='us-east-1' command='bash':
  #!/usr/bin/env bash
  set -e

  SERVICE="{{service}}"
  ENVIRONMENT="{{environment}}"
  AWS_PROFILE="{{profile}}"
  AWS_REGION="{{region}}"
  COMMAND_CHOICE="{{command}}"

  PROFILE_FLAG=""
  if [[ "$AWS_PROFILE" != "default" ]]; then
    PROFILE_FLAG="--profile $AWS_PROFILE"
  fi
  REGION_FLAG="--region $AWS_REGION"

  CLUSTER_NAME="cluster-${SERVICE}-${ENVIRONMENT}"

  echo "ECS Exec - Connect to running tasks"
  echo "======================================="
  echo "  Service: $SERVICE"
  echo "  Environment: $ENVIRONMENT"
  echo "  Cluster: $CLUSTER_NAME"
  echo "  AWS Profile: $AWS_PROFILE"
  echo "  AWS Region: $AWS_REGION"

  # Check if cluster exists
  if ! aws ecs describe-clusters --clusters "$CLUSTER_NAME" $PROFILE_FLAG $REGION_FLAG &>/dev/null; then
    echo "Error: Cluster '$CLUSTER_NAME' not found"
    exit 1
  fi

  # List available services
  echo ""
  echo "Available services:"
  SERVICES=$(aws ecs list-services --cluster "$CLUSTER_NAME" $PROFILE_FLAG $REGION_FLAG --query 'serviceArns[*]' --output text)

  if [[ -z "$SERVICES" ]]; then
    echo "Error: No services found in cluster '$CLUSTER_NAME'"
    exit 1
  fi

  SERVICE_NAMES=()
  i=1
  for service_arn in $SERVICES; do
    service_name=$(basename "$service_arn")
    SERVICE_NAMES+=("$service_name")
    echo "  $i) $service_name"
    ((i++))
  done

  echo ""
  read -p "Select service number (1): " SERVICE_CHOICE
  SERVICE_CHOICE=${SERVICE_CHOICE:-1}

  if [[ "$SERVICE_CHOICE" -lt 1 || "$SERVICE_CHOICE" -gt ${#SERVICE_NAMES[@]} ]]; then
    echo "Error: Invalid service selection"
    exit 1
  fi

  SELECTED_SERVICE=${SERVICE_NAMES[$((SERVICE_CHOICE-1))]}
  echo "Selected: $SELECTED_SERVICE"

  # Get running tasks
  TASKS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$SELECTED_SERVICE" $PROFILE_FLAG $REGION_FLAG --desired-status RUNNING --query 'taskArns[*]' --output text)

  if [[ -z "$TASKS" ]]; then
    echo "Error: No running tasks found for service '$SELECTED_SERVICE'"
    exit 1
  fi

  TASK_ARNS=($TASKS)
  if [[ ${#TASK_ARNS[@]} -gt 1 ]]; then
    echo ""
    echo "Multiple tasks found:"
    for i in "${!TASK_ARNS[@]}"; do
      task_id=$(basename "${TASK_ARNS[$i]}")
      echo "  $((i+1))) $task_id"
    done
    read -p "Select task number (1): " TASK_CHOICE
    TASK_CHOICE=${TASK_CHOICE:-1}
    SELECTED_TASK=${TASK_ARNS[$((TASK_CHOICE-1))]}
  else
    SELECTED_TASK=${TASK_ARNS[0]}
  fi

  TASK_ID=$(basename "$SELECTED_TASK")
  echo "Selected task: $TASK_ID"

  # Get container name
  TASK_DEF=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$SELECTED_TASK" $PROFILE_FLAG $REGION_FLAG --query 'tasks[0].taskDefinitionArn' --output text)
  CONTAINER_NAME=$(aws ecs describe-task-definition --task-definition "$TASK_DEF" $PROFILE_FLAG $REGION_FLAG --query 'taskDefinition.containerDefinitions[0].name' --output text)
  echo "Container: $CONTAINER_NAME"

  # Parse command choice
  case $COMMAND_CHOICE in
    bash)       COMMAND="/bin/bash" ;;
    sh)         COMMAND="/bin/sh" ;;
    django)     COMMAND="python manage.py shell" ;;
    dbshell)    COMMAND="python manage.py dbshell" ;;
    *)          COMMAND="$COMMAND_CHOICE" ;;
  esac

  echo ""
  echo "Connecting... (command: $COMMAND)"
  echo "Type 'exit' to disconnect"
  echo "===================="

  aws ecs execute-command \
    --cluster "$CLUSTER_NAME" \
    --task "$TASK_ID" \
    --container "$CONTAINER_NAME" \
    --interactive \
    --command "$COMMAND" \
    $PROFILE_FLAG $REGION_FLAG
# Stream CloudWatch logs from ECS services
[group('aws-terraform')]
aws-stream-logs service environment='development' profile='default' region='us-east-1' stream_type='a' filter='' duration='5m':
  #!/usr/bin/env bash
  set -e

  SERVICE="{{service}}"
  ENVIRONMENT="{{environment}}"
  AWS_PROFILE="{{profile}}"
  AWS_REGION="{{region}}"
  STREAM_TYPE="{{stream_type}}"
  FILTER_PATTERN="{{filter}}"
  START_TIME="{{duration}}"

  PROFILE_FLAG=""
  if [[ "$AWS_PROFILE" != "default" ]]; then
    PROFILE_FLAG="--profile $AWS_PROFILE"
  fi
  REGION_FLAG="--region $AWS_REGION"

  LOG_GROUP="/ecs/${SERVICE}/${ENVIRONMENT}"

  echo "ECS Logs Streaming"
  echo "============================================="
  echo "  Service: $SERVICE"
  echo "  Environment: $ENVIRONMENT"
  echo "  Log Group: $LOG_GROUP"
  echo "  AWS Profile: $AWS_PROFILE"
  echo "  AWS Region: $AWS_REGION"

  # Check if log group exists
  if ! aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" $PROFILE_FLAG $REGION_FLAG --query 'logGroups[?logGroupName==`'"$LOG_GROUP"'`]' --output text | grep -q "$LOG_GROUP"; then
    echo "Error: Log group '$LOG_GROUP' not found"
    echo "Tip: Make sure your service is deployed and running"
    exit 1
  fi

  # Get available log streams
  STREAMS=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --order-by LastEventTime \
    --descending \
    --max-items 20 \
    $PROFILE_FLAG $REGION_FLAG \
    --query 'logStreams[*].logStreamName' \
    --output text)

  if [[ -z "$STREAMS" ]]; then
    echo "Error: No log streams found in '$LOG_GROUP'"
    exit 1
  fi

  # Categorize streams
  SERVER_STREAMS=()
  WORKER_STREAMS=()
  OTHER_STREAMS=()

  i=1
  for stream in $STREAMS; do
    if [[ "$stream" =~ (server|app)- ]]; then
      SERVER_STREAMS+=("$stream")
      echo "  $i) [SERVER] $stream"
    elif [[ "$stream" =~ worker- ]]; then
      WORKER_STREAMS+=("$stream")
      echo "  $i) [WORKER] $stream"
    else
      OTHER_STREAMS+=("$stream")
      echo "  $i) [OTHER] $stream"
    fi
    ((i++))
  done

  ALL_STREAMS=("${SERVER_STREAMS[@]}" "${WORKER_STREAMS[@]}" "${OTHER_STREAMS[@]}")

  SELECTED_STREAMS=()
  case $STREAM_TYPE in
    a|A)  SELECTED_STREAMS=("${SERVER_STREAMS[@]}"); echo "Streaming all server logs" ;;
    w|W)  SELECTED_STREAMS=("${WORKER_STREAMS[@]}"); echo "Streaming all worker logs" ;;
    '*')  SELECTED_STREAMS=("${ALL_STREAMS[@]}"); echo "Streaming all logs" ;;
    *)
      if [[ "$STREAM_TYPE" =~ ^[0-9]+$ ]] && [[ "$STREAM_TYPE" -ge 1 ]] && [[ "$STREAM_TYPE" -le ${#ALL_STREAMS[@]} ]]; then
        SELECTED_STREAMS=("${ALL_STREAMS[$((STREAM_TYPE-1))]}")
        echo "Streaming: ${ALL_STREAMS[$((STREAM_TYPE-1))]}"
      else
        echo "Error: Invalid stream selection"
        exit 1
      fi
      ;;
  esac

  if [[ ${#SELECTED_STREAMS[@]} -eq 0 ]]; then
    echo "Error: No streams selected"
    exit 1
  fi

  # Validate duration format
  if [[ ! "$START_TIME" =~ ^[0-9]+[mh]$ ]]; then
    echo "Error: Invalid duration format. Use '30m' or '2h'"
    exit 1
  fi

  # Build filter command
  FILTER_CMD="aws logs filter-log-events --log-group-name \"$LOG_GROUP\" --start-time \$(date -v-${START_TIME} +%s)000 $PROFILE_FLAG $REGION_FLAG"

  if [[ -n "$FILTER_PATTERN" ]]; then
    FILTER_CMD="$FILTER_CMD --filter-pattern \"$FILTER_PATTERN\""
  fi

  if [[ ${#SELECTED_STREAMS[@]} -lt ${#ALL_STREAMS[@]} ]]; then
    STREAM_NAMES=$(IFS=' '; echo "${SELECTED_STREAMS[*]}")
    FILTER_CMD="$FILTER_CMD --log-stream-names $STREAM_NAMES"
  fi

  echo ""
  echo "Log Group: $LOG_GROUP"
  echo "Streams: ${#SELECTED_STREAMS[@]} selected"
  echo "Time Range: Last $START_TIME"
  if [[ -n "$FILTER_PATTERN" ]]; then
    echo "Filter: $FILTER_PATTERN"
  fi
  echo ""
  echo "Press Ctrl+C to stop streaming"
  echo "===================="

  # Stream logs with continuous updates
  LAST_SEEN=""
  while true; do
    CMD="$FILTER_CMD --output json"
    if [[ -n "$LAST_SEEN" ]]; then
      CMD="$CMD --next-token $LAST_SEEN"
    fi

    RESPONSE=$(eval "$CMD" 2>/dev/null || echo '{"events":[],"nextToken":null}')
    EVENTS=$(echo "$RESPONSE" | jq -c '.events[]?' 2>/dev/null)
    NEXT_TOKEN=$(echo "$RESPONSE" | jq -r '.nextToken // empty' 2>/dev/null)

    if [[ -n "$EVENTS" ]]; then
      while IFS= read -r event; do
        if [[ -n "$event" ]]; then
          timestamp=$(echo "$event" | jq -r '.timestamp // empty')
          message=$(echo "$event" | jq -r '.message // empty')
          stream=$(echo "$event" | jq -r '.logStreamName // empty')
          if [[ -n "$timestamp" && -n "$message" ]]; then
            formatted_time=$(date -r "$((timestamp/1000))" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$timestamp")
            stream_short=$(basename "$stream")
            echo "[$formatted_time] [$stream_short] $message"
          fi
        fi
      done <<< "$EVENTS"
    fi

    if [[ -n "$NEXT_TOKEN" && "$NEXT_TOKEN" != "null" ]]; then
      LAST_SEEN="$NEXT_TOKEN"
    fi

    sleep 2
  done
# Show ECS service events and stopped task diagnostics
[group('aws-terraform')]
aws-ecs-events service environment='development' profile='default' region='us-east-1' count='10':
  #!/usr/bin/env bash
  set -e

  SERVICE="{{service}}"
  ENVIRONMENT="{{environment}}"
  AWS_PROFILE="{{profile}}"
  AWS_REGION="{{region}}"
  COUNT="{{count}}"

  CLUSTER="cluster-${SERVICE}-${ENVIRONMENT}"
  ECS_SERVICE="service-app-${SERVICE}-${ENVIRONMENT}"

  PROFILE_FLAG=""
  if [[ "$AWS_PROFILE" != "default" ]]; then
    PROFILE_FLAG="--profile $AWS_PROFILE"
  fi
  REGION_FLAG="--region $AWS_REGION"

  echo ""
  echo "ECS Diagnostics"
  echo "============================================="
  echo "  Cluster:  $CLUSTER"
  echo "  Service:  $ECS_SERVICE"
  echo "============================================="

  # --- Service Events ---
  echo ""
  echo "📋 Recent Service Events (last $COUNT):"
  echo "---------------------------------------------"
  aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$ECS_SERVICE" \
    --query "services[0].events[:${COUNT}].[createdAt,message]" \
    --output table \
    $PROFILE_FLAG $REGION_FLAG 2>/dev/null || echo "  Could not fetch service events"

  # --- Service Status ---
  echo ""
  echo "📊 Service Status:"
  echo "---------------------------------------------"
  aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$ECS_SERVICE" \
    --query 'services[0].{desiredCount:desiredCount,runningCount:runningCount,pendingCount:pendingCount,status:status,rolloutState:deployments[0].rolloutState,rolloutReason:deployments[0].rolloutStateReason}' \
    --output table \
    $PROFILE_FLAG $REGION_FLAG 2>/dev/null || echo "  Could not fetch service status"

  # --- Stopped Tasks ---
  echo ""
  echo "🛑 Recently Stopped Tasks:"
  echo "---------------------------------------------"
  STOPPED_TASKS=$(aws ecs list-tasks \
    --cluster "$CLUSTER" \
    --service-name "$ECS_SERVICE" \
    --desired-status STOPPED \
    --query 'taskArns' \
    --output json \
    $PROFILE_FLAG $REGION_FLAG 2>/dev/null)

  if [[ "$STOPPED_TASKS" == "[]" || -z "$STOPPED_TASKS" ]]; then
    echo "  No recently stopped tasks"
  else
    aws ecs describe-tasks \
      --cluster "$CLUSTER" \
      --tasks $(echo "$STOPPED_TASKS" | jq -r '.[]') \
      --query 'tasks[].{taskArn:taskArn,stoppedReason:stoppedReason,stopCode:stopCode,lastStatus:lastStatus,exitCode:containers[0].exitCode,containerReason:containers[0].reason,createdAt:createdAt,stoppedAt:stoppedAt}' \
      --output table \
      $PROFILE_FLAG $REGION_FLAG 2>/dev/null || echo "  Could not fetch stopped task details"
  fi

  # --- Running Tasks ---
  echo ""
  echo "✅ Running Tasks:"
  echo "---------------------------------------------"
  RUNNING_TASKS=$(aws ecs list-tasks \
    --cluster "$CLUSTER" \
    --service-name "$ECS_SERVICE" \
    --desired-status RUNNING \
    --query 'taskArns' \
    --output json \
    $PROFILE_FLAG $REGION_FLAG 2>/dev/null)

  if [[ "$RUNNING_TASKS" == "[]" || -z "$RUNNING_TASKS" ]]; then
    echo "  No running tasks"
  else
    aws ecs describe-tasks \
      --cluster "$CLUSTER" \
      --tasks $(echo "$RUNNING_TASKS" | jq -r '.[]') \
      --query 'tasks[].{taskArn:taskArn,lastStatus:lastStatus,healthStatus:healthStatus,taskDefinition:taskDefinitionArn,createdAt:createdAt,ip:containers[0].networkInterfaces[0].privateIpv4Address}' \
      --output table \
      $PROFILE_FLAG $REGION_FLAG 2>/dev/null || echo "  Could not fetch running task details"
  fi

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
ollama-pull model:
  ollama pull {{model}}

[group('ollama')]
ollama-run model:
  ollama run {{model}}


[group('ollama')]
ollama-codegen message api_url='' model='qwen2.5-coder:7b':
  #!/usr/bin/env bash
  echo "Running Ollama codegen... using base model {{model}}"
  echo "To clear the chat history, type 'clear chat history' and press enter."
  CLEAN_API_URL=$(echo "{{api_url}}" | sed 's/^--api_url=//')
  CLEAN_MODEL=$(echo "{{model}}" | sed 's/^--model=//')

  uvx uv run ./llm/ollama_client.py "{{message}}" --api_url="$CLEAN_API_URL" --model="$CLEAN_MODEL"

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
