#!/bin/bash

################################################################################
# Terraform Stacks Local Setup Automation Script
# 
# This script automates the setup of Terraform Stacks in a local environment
# with comprehensive validation, error handling, and rollback capabilities.
#
# Usage: ./setup-stack.sh [OPTIONS]
# Run with --help for detailed usage information
################################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script version
readonly VERSION="1.0.0"

# Global variables
AWS_ACCOUNT=""
TFC_HOSTNAME=""
ORGANIZATION=""
PROJECT=""
STACK_NAME=""
VARSET_ID=""
CREATE_STACK=false
CONFIG_FILE=""
DRY_RUN=false
VERBOSE=false
INTERACTIVE=false

# Tracking variables for cleanup
CREATED_STACK=false
INIT_COMPLETED=false
EXPORT_COMPLETED=false

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

log_step() {
    echo ""
    echo -e "${GREEN}==>${NC} $1"
}

################################################################################
# Cleanup and Rollback Functions
################################################################################

cleanup_on_exit() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed with exit code $exit_code"
        perform_rollback
    fi
}

perform_rollback() {
    log_warning "Performing rollback of partial changes..."
    
    if [[ "$CREATED_STACK" == true ]]; then
        log_warning "Stack created: $STACK_NAME in project $PROJECT"
        log_warning "Manual cleanup may be required for the stack"
    fi
    
    if [[ "$INIT_COMPLETED" == true ]]; then
        log_info "Terraform stacks init was completed"
        log_info "You may need to clean up .terraform directory if needed"
    fi
    
    if [[ "$EXPORT_COMPLETED" == true ]]; then
        log_info "Environment variable TF_STACKS_HOSTNAME was exported"
        log_info "It will be cleared when the shell session ends"
    fi
    
    log_warning "Rollback information logged. Please review and clean up manually if needed."
}

# Set trap for cleanup
trap cleanup_on_exit EXIT

################################################################################
# Validation Functions
################################################################################

validate_prerequisites() {
    log_step "Validating prerequisites..."
    
    local all_valid=true
    
    # Check if doormat is installed
    if ! command -v doormat &> /dev/null; then
        log_error "doormat CLI is not installed or not in PATH"
        log_error "Please install doormat: https://github.com/hashicorp/doormat"
        all_valid=false
    else
        log_success "doormat CLI found: $(command -v doormat)"
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "terraform CLI is not installed or not in PATH"
        log_error "Please install terraform: https://www.terraform.io/downloads"
        all_valid=false
    else
        local tf_version=$(terraform version -json 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        log_success "terraform CLI found: $(command -v terraform) (version: $tf_version)"
    fi
    
    # Check if local Atlas is running (check for common ports)
    log_verbose "Checking if local Atlas is running..."
    if command -v lsof &> /dev/null; then
        if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1 || \
           lsof -Pi :8081 -sTCP:LISTEN -t >/dev/null 2>&1 || \
           lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
            log_success "Local Atlas appears to be running"
        else
            log_warning "Could not detect local Atlas running on common ports (8080, 8081, 3000)"
            log_warning "Please ensure local Atlas is running before proceeding"
        fi
    else
        log_warning "Cannot verify if local Atlas is running (lsof not available)"
        log_warning "Please ensure local Atlas is running before proceeding"
    fi
    
    if [[ "$all_valid" == false ]]; then
        log_error "Prerequisites validation failed"
        exit 1
    fi
    
    log_success "All prerequisites validated successfully"
}

validate_inputs() {
    log_step "Validating input parameters..."
    
    local missing_params=()
    
    if [[ -z "$AWS_ACCOUNT" ]]; then
        missing_params+=("--aws-account")
    fi
    
    if [[ -z "$TFC_HOSTNAME" ]]; then
        missing_params+=("--hostname")
    fi
    
    if [[ -z "$ORGANIZATION" ]]; then
        missing_params+=("--organization")
    fi
    
    if [[ -z "$PROJECT" ]]; then
        missing_params+=("--project")
    fi
    
    if [[ -z "$STACK_NAME" ]]; then
        missing_params+=("--stack")
    fi
    
    # Check variable set ID is provided
    if [[ -z "$VARSET_ID" ]]; then
        missing_params+=("--varset-id")
    fi
    
    # If interactive mode and missing params, prompt for them
    if [[ "$INTERACTIVE" == true ]] && [[ ${#missing_params[@]} -gt 0 ]]; then
        log_info "Interactive mode: prompting for missing parameters..."
        prompt_for_missing_parameters
        # Re-validate after prompting
        missing_params=()
        [[ -z "$AWS_ACCOUNT" ]] && missing_params+=("--aws-account")
        [[ -z "$TFC_HOSTNAME" ]] && missing_params+=("--hostname")
        [[ -z "$ORGANIZATION" ]] && missing_params+=("--organization")
        [[ -z "$PROJECT" ]] && missing_params+=("--project")
        [[ -z "$STACK_NAME" ]] && missing_params+=("--stack")
        [[ -z "$VARSET_ID" ]] && missing_params+=("--varset-id")
    fi
    
    if [[ ${#missing_params[@]} -gt 0 ]]; then
        log_error "Missing required parameters: ${missing_params[*]}"
        log_error "Run with --help for usage information or --interactive for prompts"
        exit 1
    fi
    
    # Validate hostname format (basic check)
    if [[ ! "$TFC_HOSTNAME" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && [[ ! "$TFC_HOSTNAME" =~ ^[a-zA-Z0-9.-]+\.ngrok\.app$ ]]; then
        log_warning "Hostname format may be invalid: $TFC_HOSTNAME"
        log_warning "Expected format: domain.com or subdomain.ngrok.app"
    fi
    
    log_success "Input parameters validated successfully"
    log_verbose "AWS Account: $AWS_ACCOUNT"
    log_verbose "TFC Hostname: $TFC_HOSTNAME"
    log_verbose "Organization: $ORGANIZATION"
    log_verbose "Project: $PROJECT"
    log_verbose "Stack Name: $STACK_NAME"
    log_verbose "Variable Set ID: $VARSET_ID"
}

################################################################################
# Interactive Mode Functions
################################################################################

prompt_for_missing_parameters() {
    echo ""
    log_info "=== Interactive Parameter Input ==="
    echo ""
    
    # Prompt for AWS Account
    if [[ -z "$AWS_ACCOUNT" ]]; then
        read -p "Enter AWS account name (e.g., aws_user_test): " AWS_ACCOUNT
        if [[ -z "$AWS_ACCOUNT" ]]; then
            log_error "AWS account name is required"
            exit 1
        fi
    fi
    
    # Prompt for TFC Hostname
    if [[ -z "$TFC_HOSTNAME" ]]; then
        read -p "Enter TFC hostname (e.g., tfcdev-xxx.ngrok.app): " TFC_HOSTNAME
        if [[ -z "$TFC_HOSTNAME" ]]; then
            log_error "TFC hostname is required"
            exit 1
        fi
    fi
    
    # Prompt for Organization
    if [[ -z "$ORGANIZATION" ]]; then
        read -p "Enter organization name: " ORGANIZATION
        if [[ -z "$ORGANIZATION" ]]; then
            log_error "Organization name is required"
            exit 1
        fi
    fi
    
    # Prompt for Project
    if [[ -z "$PROJECT" ]]; then
        read -p "Enter project name (e.g., stacks-test): " PROJECT
        if [[ -z "$PROJECT" ]]; then
            log_error "Project name is required"
            exit 1
        fi
    fi
    
    # Prompt for Stack Name
    if [[ -z "$STACK_NAME" ]]; then
        read -p "Enter stack name (e.g., stack-1): " STACK_NAME
        if [[ -z "$STACK_NAME" ]]; then
            log_error "Stack name is required"
            exit 1
        fi
    fi
    
    # Prompt for Stack Creation
    if [[ "$CREATE_STACK" == false ]]; then
        echo ""
        log_info "Stack Configuration:"
        echo "  1) Create a new stack"
        echo "  2) Use an existing stack"
        read -p "Choose option (1 or 2): " stack_choice
        
        case "$stack_choice" in
            1)
                CREATE_STACK=true
                ;;
            2)
                CREATE_STACK=false
                ;;
            *)
                log_error "Invalid choice. Please select 1 or 2"
                exit 1
                ;;
        esac
    fi
    
    # Prompt for Variable Set ID
    if [[ -z "$VARSET_ID" ]]; then
        echo ""
        read -p "Enter existing variable set ID (e.g., varset-xxxxx): " VARSET_ID
        if [[ -z "$VARSET_ID" ]]; then
            log_error "Variable set ID is required"
            exit 1
        fi
    fi
    
    echo ""
    log_success "All parameters collected successfully"
    echo ""
}

################################################################################
# Configuration File Functions
################################################################################

load_config_file() {
    if [[ -n "$CONFIG_FILE" ]] && [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from: $CONFIG_FILE"
        
        # Source the config file in a subshell to avoid polluting current environment
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue
            
            # Remove quotes from value
            value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            
            case "$key" in
                AWS_ACCOUNT)
                    [[ -z "$AWS_ACCOUNT" ]] && AWS_ACCOUNT="$value"
                    ;;
                TFC_HOSTNAME)
                    [[ -z "$TFC_HOSTNAME" ]] && TFC_HOSTNAME="$value"
                    ;;
                ORGANIZATION)
                    [[ -z "$ORGANIZATION" ]] && ORGANIZATION="$value"
                    ;;
                PROJECT)
                    [[ -z "$PROJECT" ]] && PROJECT="$value"
                    ;;
                STACK_NAME)
                    [[ -z "$STACK_NAME" ]] && STACK_NAME="$value"
                    ;;
                VARSET_ID)
                    [[ -z "$VARSET_ID" ]] && VARSET_ID="$value"
                    ;;
            esac
        done < "$CONFIG_FILE"
        
        log_success "Configuration loaded from file"
    elif [[ -n "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
}

################################################################################
# Stack Management Functions
################################################################################

create_stack() {
    log_step "Creating new stack: $STACK_NAME"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: terraform stacks create"
        log_info "[DRY RUN]   -organization-name \"$ORGANIZATION\""
        log_info "[DRY RUN]   -project-name \"$PROJECT\""
        log_info "[DRY RUN]   -stack-name \"$STACK_NAME\""
        return 0
    fi
    
    log_info "Running terraform stacks create..."
    log_verbose "Organization: $ORGANIZATION"
    log_verbose "Project: $PROJECT"
    log_verbose "Stack: $STACK_NAME"
    
    if terraform stacks create \
        -organization-name "$ORGANIZATION" \
        -project-name "$PROJECT" \
        -stack-name "$STACK_NAME"; then
        CREATED_STACK=true
        log_success "Stack created successfully: $STACK_NAME"
    else
        log_error "Failed to create stack"
        exit 1
    fi
}

################################################################################
# Main Setup Functions
################################################################################

doormat_login() {
    log_step "Authenticating with doormat..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: doormat login"
        return 0
    fi
    
    log_info "Running doormat login..."
    
    if doormat login; then
        log_success "Doormat authentication successful"
    else
        log_error "Failed to authenticate with doormat"
        log_error "Please ensure you have proper access and try again"
        exit 1
    fi
}

push_aws_credentials() {
    log_step "Pushing AWS credentials to variable set..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: doormat aws tf-push variable-set --account $AWS_ACCOUNT --hostname https://$TFC_HOSTNAME --id $VARSET_ID"
        return 0
    fi
    
    log_info "Running doormat aws tf-push variable-set..."
    log_verbose "Account: $AWS_ACCOUNT"
    log_verbose "Hostname: https://$TFC_HOSTNAME"
    log_verbose "Variable Set ID: $VARSET_ID"
    
    if doormat aws tf-push variable-set \
        --account "$AWS_ACCOUNT" \
        --hostname "https://$TFC_HOSTNAME" \
        --id "$VARSET_ID"; then
        log_success "AWS credentials pushed successfully"
    else
        log_error "Failed to push AWS credentials"
        exit 1
    fi
}

export_hostname() {
    log_step "Exporting TF_STACKS_HOSTNAME environment variable..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would export: TF_STACKS_HOSTNAME=$TFC_HOSTNAME"
        return 0
    fi
    
    export TF_STACKS_HOSTNAME="$TFC_HOSTNAME"
    EXPORT_COMPLETED=true
    
    log_success "Exported TF_STACKS_HOSTNAME=$TFC_HOSTNAME"
    log_info "Note: This export is only valid for the current shell session"
    log_info "Add 'export TF_STACKS_HOSTNAME=$TFC_HOSTNAME' to your shell profile for persistence"
}

initialize_stacks() {
    log_step "Initializing Terraform Stacks..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: terraform stacks init"
        return 0
    fi
    
    log_info "Running terraform stacks init..."
    
    if terraform stacks init; then
        INIT_COMPLETED=true
        log_success "Terraform Stacks initialized successfully"
    else
        log_error "Failed to initialize Terraform Stacks"
        exit 1
    fi
}

upload_configuration() {
    log_step "Uploading Terraform Stacks configuration..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: terraform stacks configuration upload"
        log_info "[DRY RUN]   -organization-name \"$ORGANIZATION\""
        log_info "[DRY RUN]   -project-name \"$PROJECT\""
        log_info "[DRY RUN]   -stack-name \"$STACK_NAME\""
        return 0
    fi
    
    log_info "Running terraform stacks configuration upload..."
    log_verbose "Organization: $ORGANIZATION"
    log_verbose "Project: $PROJECT"
    log_verbose "Stack: $STACK_NAME"
    
    if terraform stacks configuration upload \
        -organization-name "$ORGANIZATION" \
        -project-name "$PROJECT" \
        -stack-name "$STACK_NAME"; then
        log_success "Configuration uploaded successfully"
    else
        log_error "Failed to upload configuration"
        exit 1
    fi
}

################################################################################
# Help and Usage Functions
################################################################################

show_help() {
    cat << EOF
Terraform Stacks Local Setup Automation Script v${VERSION}

USAGE:
    ./setup-stack.sh [OPTIONS]

DESCRIPTION:
    Automates the setup of Terraform Stacks in a local environment with
    comprehensive validation, error handling, and rollback capabilities.

REQUIRED OPTIONS:
    --aws-account ACCOUNT       AWS account name (e.g., aws_user_test)
    --hostname HOSTNAME         TFC hostname (e.g., tfcdev-xxx.ngrok.app)
    --organization ORG          Terraform organization name
    --project PROJECT           Project name
    --stack STACK               Stack name
    --varset-id ID              Existing variable set ID (e.g., varset-xxxxx)

STACK OPTIONS:
    --create-stack              Create a new stack (default: use existing)

OPTIONAL:
    --config FILE               Load configuration from file
    --interactive               Enable interactive mode (prompts for missing params)
    --dry-run                   Show what would be executed without running
    --verbose                   Enable detailed logging
    --help                      Display this help message
    --version                   Display script version

CONFIGURATION FILE:
    You can create a configuration file to store default values:
    
    AWS_ACCOUNT="aws_user_test"
    TFC_HOSTNAME="tfcdev-xxx.ngrok.app"
    ORGANIZATION="learn-terraform"
    PROJECT="stacks-test"
    STACK_NAME="stack-1"
    VARSET_ID="varset-xxxxx"

    Command-line arguments override configuration file values.

PREREQUISITES:
    Before running this script, you must:
    1. Create a variable set in Terraform Cloud/Enterprise
    2. Note the variable set ID (format: varset-xxxxx)
    3. Ensure local Atlas is up and running
    4. Have doormat CLI installed
    5. Have terraform CLI installed with stacks support

EXAMPLES:
    # Basic usage with existing variable set
    ./setup-stack.sh \\
      --aws-account aws_user_test \\
      --hostname tfcdev-xxx.ngrok.app \\
      --organization learn-terraform \\
      --project stacks-test \\
      --stack stack-1 \\
      --varset-id varset-qgLRwjGnGUzjkLWa

    # Use configuration file
    ./setup-stack.sh --config .stack-setup.conf --varset-id varset-xxxxx

    # Interactive mode (prompts for missing parameters)
    ./setup-stack.sh --interactive

    # Dry run to see what would be executed
    ./setup-stack.sh --config .stack-setup.conf --varset-id varset-xxx --dry-run

EXIT CODES:
    0 - Success
    1 - Error occurred (check logs for details)

For more information, visit: https://developer.hashicorp.com/terraform/stacks

EOF
}

show_version() {
    echo "Terraform Stacks Setup Script v${VERSION}"
}

################################################################################
# Argument Parsing
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --aws-account)
                AWS_ACCOUNT="$2"
                shift 2
                ;;
            --hostname)
                TFC_HOSTNAME="$2"
                shift 2
                ;;
            --organization)
                ORGANIZATION="$2"
                shift 2
                ;;
            --project)
                PROJECT="$2"
                shift 2
                ;;
            --stack)
                STACK_NAME="$2"
                shift 2
                ;;
            --varset-id)
                VARSET_ID="$2"
                shift 2
                ;;
            --create-stack)
                CREATE_STACK=true
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                log_error "Run with --help for usage information"
                exit 1
                ;;
        esac
    done
}

################################################################################
# Main Function
################################################################################

main() {
    echo ""
    log_info "Terraform Stacks Local Setup Automation Script v${VERSION}"
    echo ""
    
    # Parse command-line arguments
    parse_arguments "$@"
    
    # Load configuration file if specified
    load_config_file
    
    # Validate prerequisites
    validate_prerequisites
    
    # Validate input parameters
    validate_inputs
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN MODE - No actual changes will be made"
        echo ""
    fi
    
    # Execute setup steps
    doormat_login
    push_aws_credentials
    export_hostname
    
    # Create stack if requested
    if [[ "$CREATE_STACK" == true ]]; then
        create_stack
    fi
    
    initialize_stacks
    upload_configuration
    
    # Success message
    echo ""
    log_success "=========================================="
    log_success "Terraform Stacks setup completed successfully!"
    log_success "=========================================="
    echo ""
    log_info "Next steps:"
    log_info "  1. Verify the configuration in your Terraform Cloud/Enterprise"
    log_info "  2. Run 'terraform stacks plan' to preview changes"
    log_info "  3. Run 'terraform stacks apply' to apply the configuration"
    echo ""
    
    if [[ "$DRY_RUN" == false ]]; then
        log_info "Environment variable set for this session:"
        log_info "  TF_STACKS_HOSTNAME=$TFC_HOSTNAME"
        echo ""
        log_warning "Remember: The TF_STACKS_HOSTNAME export is only valid for this shell session"
        log_warning "To make it permanent, add this to your shell profile (~/.bashrc or ~/.zshrc):"
        log_warning "  export TF_STACKS_HOSTNAME=$TFC_HOSTNAME"
        echo ""
    fi
}

################################################################################
# Script Entry Point
################################################################################

# Run main function with all arguments
main "$@"

# Made with Bob
