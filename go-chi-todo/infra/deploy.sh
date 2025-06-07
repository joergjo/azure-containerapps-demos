#!/bin/bash
set -euo pipefail

# Check Bash version compatibility (require Bash 3.2+)
major_version="${BASH_VERSION%%.*}"
minor_version="${BASH_VERSION#*.}"
minor_version="${minor_version%%.*}"

if [ "$major_version" -lt 3 ] || ([ "$major_version" -eq 3 ] && [ "$minor_version" -lt 2 ]); then
  echo "Error: This script requires Bash 3.2 or later. You have Bash $BASH_VERSION." >&2
  echo "Please upgrade your Bash version." >&2
  exit 1
fi

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions
log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_step() {
  echo -e "${CYAN}[STEP]${NC} $*"
}

# Function to check if a command exists
check_command() {
  if ! command -v "$1" > /dev/null 2>&1; then
    log_error "Required command '$1' is not installed or not in PATH"
    return 1
  fi
}

# Function to validate required tools
validate_tools() {
  log_step "Validating required tools..."

  local tools=("az" "psql" "migrate" "curl")
  local missing_tools=""

  for tool in "${tools[@]}"; do
    if ! check_command "$tool"; then
      if [ -z "$missing_tools" ]; then
        missing_tools="$tool"
      else
        missing_tools="$missing_tools $tool"
      fi
    fi
  done

  if [ -n "$missing_tools" ]; then
    log_error "Missing required tools: $missing_tools"
    log_info "Please install the missing tools and ensure they are in your PATH"
    exit 1
  fi

  log_success "All required tools are available"
}

# Function to validate Azure CLI login
validate_azure_login() {
  log_step "Validating Azure CLI login..."

  if ! az account show > /dev/null 2>&1; then
    log_error "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
  fi

  log_success "Azure CLI login validated"
}

# Function to validate environment variables
validate_environment() {
  log_step "Validating environment variables..."

  local required_vars=(
    "CONTAINERAPP_RESOURCE_GROUP"
    "CONTAINERAPP_POSTGRES_LOGIN"
    "CONTAINERAPP_POSTGRES_LOGIN_PWD"
  )

  local missing_vars=""

  for var in "${required_vars[@]}"; do
    # Use eval to check variable value (Bash 3 compatible)
    if [ -z "$(eval echo \$${var})" ]; then
      if [ -z "$missing_vars" ]; then
        missing_vars="$var"
      else
        missing_vars="$missing_vars $var"
      fi
    fi
  done

  if [ -n "$missing_vars" ]; then
    log_error "Missing required environment variables:"
    for var in $missing_vars; do
      case "$var" in
        "CONTAINERAPP_RESOURCE_GROUP")
          log_error "  $var: Please set it to the name of the resource group to deploy to."
          ;;
        "CONTAINERAPP_POSTGRES_LOGIN")
          log_error "  $var: Please set it to a valid login name for the Container App's database server."
          ;;
        "CONTAINERAPP_POSTGRES_LOGIN_PWD")
          log_error "  $var: Please set it to a secure password for the Container App's database server."
          ;;
      esac
    done
    exit 1
  fi

  log_success "All required environment variables are set"
}

# Function to validate Bicep templates
validate_bicep_templates() {
  log_step "Validating Bicep templates..."

  local templates=("main-infra.bicep" "main-app.bicep")

  for template in "${templates[@]}"; do
    if [ ! -f "$template" ]; then
      log_error "Bicep template '$template' not found in current directory"
      exit 1
    fi

    log_info "Validating $template..."
    if ! az bicep build --file "$template" --stdout > /dev/null 2>&1; then
      log_error "Bicep template '$template' validation failed"
      log_info "Run 'az bicep build --file $template' to see detailed errors"
      exit 1
    fi
  done

  log_success "All Bicep templates validated successfully"
}

# Function to validate IP address format
validate_ip() {
  local ip="$1"
  # Use regex if available (Bash 3.2+), otherwise use a more basic check
  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    return 0
  else
    # Fallback validation for very old systems
    echo "$ip" | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' >/dev/null 2>&1
  fi
}

# Function to get client IP with error handling
get_client_ip() {
  log_step "Retrieving client IP address..." >&2

  local client_ip
  if ! client_ip=$(curl -s --max-time 10 'https://api.ipify.org?format=text' 2>/dev/null); then
    log_warning "Failed to retrieve client IP from ipify.org, trying alternative service..." >&2
    if ! client_ip=$(curl -s --max-time 10 'https://ifconfig.me/ip' 2>/dev/null); then
      log_error "Failed to retrieve client IP address. Please check your internet connection." >&2
      exit 1
    fi
  fi

  if ! validate_ip "$client_ip"; then
    log_error "Retrieved invalid IP address: $client_ip" >&2
    exit 1
  fi

  log_info "Client IP address: $client_ip" >&2
  echo "$client_ip"
}

# Main execution starts here
main() {
  log_info "Starting deployment of go-chi-todo application"

  # Validate prerequisites
  validate_tools
  validate_azure_login
  validate_environment
  validate_bicep_templates

  # Set variables
  image=${CONTAINERAPP_IMAGE:-"joergjo/go-chi-todo:latest"}
  resource_group="$CONTAINERAPP_RESOURCE_GROUP"
  app=${CONTAINERAPP_NAME:-"go-todo-api"}
  location=${CONTAINERAPP_LOCATION:-"westeurope"}
  postgres_login="$CONTAINERAPP_POSTGRES_LOGIN"
  postgres_login_pwd="$CONTAINERAPP_POSTGRES_LOGIN_PWD"
  database=${CONTAINERAPP_POSTGRES_DB-"todo"}
  timestamp=$(date +%s)
  client_ip=$(get_client_ip)

  log_info "Deployment configuration:"
  log_info "  Resource Group: $resource_group"
  log_info "  Application Name: $app"
  log_info "  Location: $location"
  log_info "  Database: $database"
  log_info "  Container Image: $image"

  # Create resource group
  log_step "Creating resource group '$resource_group' in '$location'..."
  if ! az group create \
    --resource-group "$resource_group" \
    --location "$location" \
    --output none; then
    log_error "Failed to create resource group"
    exit 1
  fi
  log_success "Resource group created successfully"

  # Get current user information
  log_step "Retrieving current user information..."
  current_user_upn=$(az ad signed-in-user show --query userPrincipalName --output tsv)
  current_user_objectid=$(az ad signed-in-user show --query id --output tsv)

  if [ -z "$current_user_upn" ] || [ -z "$current_user_objectid" ]; then
    log_error "Failed to retrieve current user information"
    exit 1
  fi
  log_info "Current user: $current_user_upn"

  # Deploy infrastructure
  log_step "Deploying infrastructure (this may take several minutes)..."
  if ! identity_upn=$(az deployment group create \
    --resource-group "$resource_group" \
    --name "env-$timestamp" \
    --template-file main-infra.bicep \
    --parameters namePrefix="$app" clientIP="$client_ip" database="$database" \
      aadPostgresAdmin="$current_user_upn" aadPostgresAdminObjectID="$current_user_objectid" \
      postgresLogin="$postgres_login" postgresLoginPassword="$postgres_login_pwd" \
    --query properties.outputs.identityUPN.value \
    --output tsv); then
    log_error "Infrastructure deployment failed"
    exit 1
  fi
  log_success "Infrastructure deployed successfully"
  log_info "Managed identity UPN: $identity_upn"

  # Get database host
  log_step "Retrieving database host information..."
  if ! db_host=$(az deployment group show \
    --resource-group "$resource_group" \
    --name "env-$timestamp" \
    --query properties.outputs.postgresHost.value \
    --output tsv); then
    log_error "Failed to retrieve database host"
    exit 1
  fi
  log_info "Database host: $db_host"

  # Get Azure access token for PostgreSQL
  log_step "Obtaining Azure access token for PostgreSQL..."
  if ! token=$(az account get-access-token --resource-type oss-rdbms --query accessToken --output tsv); then
    log_error "Failed to obtain Azure access token"
    exit 1
  fi
  export PGPASSWORD="${token}"

  # Prepare database setup script
  log_step "Preparing database setup..."
  cat << EOF > prepare-db.generated.sql
SELECT * FROM pgaadauth_create_principal('${identity_upn}', false, false);
CREATE DATABASE "${database}";
EOF

  # Set PostgreSQL user
  # PGX seems to have trouble with Entra ID B2B UPNs, so we use PGUSER instead.
  # psql doesn't have this issue, so we pass the user on the command line.
  export PGUSER="${current_user_upn}"

  # Setup database principal and create database
  log_step "Setting up database principal and creating database..."
  if ! psql "host=${db_host} dbname=postgres sslmode=require" \
    -f prepare-db.generated.sql; then
    log_error "Failed to setup database principal or create database"
    exit 1
  fi
  log_success "Database principal and database created successfully"

  # Run database migrations
  log_step "Running database migrations..."
  if ! migrate -path ../migrations -database "pgx://${db_host}/${database}?sslmode=require" up; then
    log_error "Database migration failed"
    exit 1
  fi
  log_success "Database migrations completed successfully"

  # Grant permissions to managed identity
  log_step "Granting database permissions to managed identity..."
  if ! psql "host=${db_host} dbname=${database} sslmode=require" \
    -c "GRANT ALL on \"todo\" TO \"${identity_upn}\"; GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"${identity_upn}\";"; then
    log_error "Failed to grant database permissions"
    exit 1
  fi
  log_success "Database permissions granted successfully"

  # Get environment ID
  log_step "Retrieving Container Apps environment ID..."
  if ! env_id=$(az deployment group show \
    --resource-group "$resource_group" \
    --name "env-$timestamp" \
    --query properties.outputs.environmentId.value \
    --output tsv); then
    log_error "Failed to retrieve Container Apps environment ID"
    exit 1
  fi
  log_info "Container Apps environment ID: $env_id"

  # Deploy application
  log_step "Deploying application container..."
  if ! fqdn=$(az deployment group create \
    --resource-group "$resource_group" \
    --name "$app-$timestamp" \
    --template-file main-app.bicep \
    --parameters appName="$app" image="$image" environmentId="$env_id" \
      identityUPN="$identity_upn" postgresHost="$db_host" database="$database" \
    --query properties.outputs.fqdn.value \
    --output tsv); then
    log_error "Application deployment failed"
    exit 1
  fi
  log_success "Application deployed successfully"

  # Clean up temporary files
  if [ -f "prepare-db.generated.sql" ]; then
    rm -f prepare-db.generated.sql
    log_info "Cleaned up temporary files"
  fi

  # Deployment complete
  log_success "Application has been deployed successfully to $resource_group"
  log_success "You can access it at https://$fqdn"
}

# Execute main function
main "$@"
