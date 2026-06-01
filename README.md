# Terraform Stacks Local Setup Automation

Comprehensive automation script for setting up Terraform Stacks in a local development environment with AWS credentials management.

## Overview

This automation script streamlines the process of setting up Terraform Stacks locally by:

1. ✅ Validating all prerequisites (Atlas, doormat, terraform)
2. ✅ Authenticating with doormat
3. ✅ Pushing AWS credentials to existing variable set
4. ✅ Configuring environment variables
5. ✅ Initializing Terraform Stacks
6. ✅ Uploading stack configuration
7. ✅ Providing comprehensive error handling and rollback

## Prerequisites

Before running the automation script, ensure you have:

### Required Tools

- **Local Atlas**: Must be running before executing the script
  - Typically runs on ports 8080, 8081, or 3000
  - Verify it's running: `lsof -i :8080` (or your Atlas port)

- **doormat CLI**: HashiCorp's credential management tool
  - Installation: https://github.com/hashicorp/doormat
  - Verify: `doormat --version`

- **Terraform CLI**: With Stacks support
  - Installation: https://www.terraform.io/downloads
  - Verify: `terraform version`
  - Required version: >= 1.2

### Required Setup

**IMPORTANT: You must create a variable set before running this script!**

1. **Create a Variable Set in Terraform Cloud/Enterprise:**
   - Navigate to your organization settings
   - Go to Variable Sets
   - Create a new variable set (you can name it anything you like)
   - Note the variable set ID (format: `varset-xxxxx`)
   - The script will populate this variable set with AWS credentials

2. **Update your deployment configuration:**
   - In `deployments.tfdeploy.hcl`, specify the variable set ID in each deployment's inputs
   - Example: `varset_id = "varset-qgLRwjGnGUzjkLWa"`

### Required Information

Gather the following information before running the script:

- AWS account name (for doormat)
- Terraform Cloud/Enterprise hostname (e.g., ngrok URL)
- Organization name
- Project name
- Stack name
- **Variable set ID** (from the variable set you created above)

## Installation

1. **Download the script:**
   ```bash
   # The script is already in your project directory
   ls -la setup-stack.sh
   ```

2. **Make it executable:**
   ```bash
   chmod +x setup-stack.sh
   ```

3. **Create configuration file (optional but recommended):**
   ```bash
   cp .stack-setup.conf.example .stack-setup.conf
   # Edit .stack-setup.conf with your values
   ```

4. **Add to .gitignore (important!):**
   ```bash
   echo ".stack-setup.conf" >> .gitignore
   ```

## Usage

### Basic Usage

#### Option 1: Interactive Mode (Easiest for First-Time Users)

```bash
# Simply run with --interactive flag
./setup-stack.sh --interactive

# The script will prompt you for all required parameters:
# - AWS account name
# - TFC hostname
# - Organization name
# - Project name
# - Stack name
# - Variable set ID
```

**Benefits of Interactive Mode:**
- ✅ No need to remember all parameter names
- ✅ Guided prompts with examples
- ✅ Input validation at each step
- ✅ Perfect for first-time setup or occasional use

#### Option 2: Using Command-Line Arguments

```bash
./setup-stack.sh \
  --aws-account aws_neha.elizabeth.thomas_test \
  --hostname tfcdev-440d497a.ngrok.app \
  --organization learn-terraform \
  --project stacks-test \
  --stack stack-1 \
  --varset-id varset-qgLRwjGnGUzjkLWa
```

#### Option 3: Using Configuration File

```bash
# Edit .stack-setup.conf with your values first
./setup-stack.sh --config .stack-setup.conf
```

### Command-Line Options

#### Required Options

| Option | Description | Example |
|--------|-------------|---------|
| `--aws-account` | AWS account name for doormat | `aws_user_test` |
| `--hostname` | TFC/TFE hostname | `tfcdev-xxx.ngrok.app` |
| `--organization` | Terraform organization name | `learn-terraform` |
| `--project` | Project name | `stacks-test` |
| `--stack` | Stack name | `stack-1` |
| `--varset-id` | Existing variable set ID | `varset-qgLRwjGnGUzjkLWa` |

#### Stack Options

| Option | Description | Example |
|--------|-------------|---------|
| `--create-stack` | Create a new stack | (flag, no value) |

**Note:** By default, the script assumes the stack already exists. Use `--create-stack` to create a new one.

| Option | Description | Default |
|--------|-------------|---------|
| `--config` | Path to configuration file | (none) |
| `--interactive` | Enable interactive mode (prompts for missing params) | (disabled) |
| `--dry-run` | Preview without executing | (disabled) |
| `--verbose` | Enable detailed logging | (disabled) |
| `--help` | Display help message | - |
| `--version` | Display script version | - |

### Configuration File Format

Create a `.stack-setup.conf` file:

```bash
# AWS Configuration
AWS_ACCOUNT="aws_neha.elizabeth.thomas_test"

# Terraform Cloud Configuration
TFC_HOSTNAME="tfcdev-440d497a.ngrok.app"

# Stack Configuration
ORGANIZATION="learn-terraform"
PROJECT="stacks-test"
STACK_NAME="stack-1"

# Variable Set Configuration (required)
VARSET_ID="varset-qgLRwjGnGUzjkLWa"
```

**Note:** Command-line arguments override configuration file values.

## Workflow

The script executes the following steps in order:

```
1. Parse Arguments & Load Config
   ↓
2. Validate Prerequisites
   - Check doormat installation
   - Check terraform installation
   - Verify local Atlas is running
   ↓
3. Validate Input Parameters
   - Ensure all required parameters provided
   - Validate hostname format
   - Verify variable set ID is provided
   ↓
4. Authenticate with Doormat
   - Run: doormat login
   ↓
5. Push AWS Credentials
   - Run: doormat aws tf-push variable-set
   ↓
6. Export Environment Variable
   - Set: TF_STACKS_HOSTNAME
   ↓
7. Initialize Terraform Stacks
   - Run: terraform stacks init
   ↓
8. Upload Configuration
   - Run: terraform stacks configuration upload
   ↓
9. Success! 🎉
```

## Examples

### Example 1: Interactive Mode (Recommended for First-Time Users)

```bash
# 1. Create a variable set in TFC/TFE first and note the ID
# 2. Start local Atlas
# 3. Run in interactive mode:

./setup-stack.sh --interactive

# The script will prompt you for:
# - AWS account name
# - TFC hostname
# - Organization name
# - Project name
# - Stack name
# - Variable set ID
```

### Example 2: Basic Usage with Existing Variable Set

```bash
# Prerequisites:
# - Variable set created in TFC/TFE
# - Local Atlas running

./setup-stack.sh \
  --aws-account aws_neha.elizabeth.thomas_test \
  --hostname tfcdev-440d497a.ngrok.app \
  --organization learn-terraform \
  --project stacks-test \
  --stack stack-1 \
  --varset-id varset-qgLRwjGnGUzjkLWa
```

### Example 3: Using Configuration File

```bash
# 1. Create and edit config file
cp .stack-setup.conf.example .stack-setup.conf
nano .stack-setup.conf
# Add your variable set ID to the config file

# 2. Run with config
./setup-stack.sh --config .stack-setup.conf
```

### Example 4: Interactive Mode with Partial Config

```bash
# Use config file for some values, interactive prompts for missing ones
./setup-stack.sh --config .stack-setup.conf --interactive
```

### Example 5: Dry Run (Preview Mode)

```bash
# See what would be executed without making changes
./setup-stack.sh \
  --config .stack-setup.conf \
  --dry-run \
  --verbose
```

### Example 6: Create New Stack

```bash
# Create a new stack along with setup
./setup-stack.sh \
  --aws-account aws_neha.elizabeth.thomas_test \
  --hostname tfcdev-440d497a.ngrok.app \
  --organization learn-terraform \
  --project stacks-test \
  --stack stack-2 \
  --varset-id varset-qgLRwjGnGUzjkLWa \
  --create-stack
```

## Error Handling & Rollback

The script includes comprehensive error handling:

### Automatic Validation

- ✅ Checks if doormat is installed
- ✅ Checks if terraform is installed
- ✅ Verifies local Atlas is running
- ✅ Validates all required parameters
- ✅ Validates hostname format

### Error Recovery

If the script fails at any step:

1. **Immediate Exit**: Script stops on first error
2. **Error Logging**: Detailed error message displayed
3. **Rollback Information**: Shows what was created/modified
4. **Cleanup Guidance**: Provides manual cleanup instructions

### Rollback Behavior

When an error occurs, the script logs:

- Stack creation status (if created)
- Terraform init status
- Environment variables set
- Manual cleanup instructions

**Note:** Some operations may require manual cleanup through the Terraform Cloud/Enterprise UI.

## Troubleshooting

### Common Issues

#### 1. "doormat CLI is not installed"

**Solution:**
```bash
# Install doormat
# Follow instructions at: https://github.com/hashicorp/doormat
```

#### 2. "terraform CLI is not installed"

**Solution:**
```bash
# Install terraform
brew install terraform  # macOS
# or download from: https://www.terraform.io/downloads
```

#### 3. "Could not detect local Atlas running"

**Solution:**
```bash
# Start local Atlas first
# Verify it's running:
lsof -i :8080  # or your Atlas port
```

#### 4. "Failed to push AWS credentials"

**Possible causes:**
- Invalid AWS account name
- doormat not authenticated
- Network connectivity issues

**Solution:**
```bash
# Verify doormat authentication
doormat login

# Test doormat access
doormat aws --account your_account_name
```

#### 5. "Failed to initialize Terraform Stacks"

**Possible causes:**
- Invalid hostname
- Network connectivity
- Terraform version incompatibility

**Solution:**
```bash
# Verify terraform version
terraform version

# Check hostname accessibility
curl https://your-hostname.ngrok.app

# Verify TF_STACKS_HOSTNAME is set
echo $TF_STACKS_HOSTNAME
```

#### 6. "Failed to upload configuration"

**Possible causes:**
- Organization/project/stack doesn't exist
- Insufficient permissions
- Invalid configuration files

**Solution:**
```bash
# Verify organization exists in TFC/TFE
# Check project and stack names
# Verify you have write permissions
```

### Debug Mode

Enable verbose logging for detailed troubleshooting:

```bash
./setup-stack.sh \
  --config .stack-setup.conf \
  --varset-id varset-xxxxx \
  --verbose
```

### Manual Verification

After script completion, verify:

```bash
# 1. Check environment variable
echo $TF_STACKS_HOSTNAME

# 2. Verify terraform initialization
ls -la .terraform/

# 3. Test terraform stacks commands
terraform stacks plan
```

## Best Practices

### 1. Use Configuration Files

Store common settings in `.stack-setup.conf`:

```bash
# Benefits:
# - Reusable across runs
# - Less typing
# - Consistent configuration
# - Easy to share (without sensitive data)
```

### 2. Version Control

```bash
# DO commit:
setup-stack.sh
.stack-setup.conf.example
SETUP_AUTOMATION.md

# DON'T commit:
.stack-setup.conf  # Contains your specific values
```

### 3. Test with Dry Run

Always test with `--dry-run` first:

```bash
./setup-stack.sh --config .stack-setup.conf --dry-run
```

### 4. Keep Variable Set IDs

Save variable set IDs in your config file:

```bash
# After creating a variable set in TFC/TFE, note the ID
# Add to your config file
echo "VARSET_ID=varset-xxxxx" >> .stack-setup.conf
```

### 5. Persistent Environment Variable

Add to your shell profile for persistence:

```bash
# Add to ~/.bashrc or ~/.zshrc
echo 'export TF_STACKS_HOSTNAME=tfcdev-440d497a.ngrok.app' >> ~/.bashrc
source ~/.bashrc
```

## Next Steps

After successful setup:

1. **Verify Configuration:**
   ```bash
   # Check in Terraform Cloud/Enterprise UI
   # Verify organization, project, and stack exist
   ```

2. **Plan Changes:**
   ```bash
   terraform stacks plan
   ```

3. **Apply Configuration:**
   ```bash
   terraform stacks apply
   ```

4. **Monitor Deployment:**
   ```bash
   # Check deployment status in TFC/TFE UI
   ```

## Script Maintenance

### Updating the Script

To update the script with new features:

1. Edit `setup-stack.sh`
2. Update version number in script
3. Test with `--dry-run`
4. Update this documentation

### Adding New Parameters

To add new configuration parameters:

1. Add to argument parsing section
2. Add to configuration file support
3. Add to validation
4. Update help text
5. Update this documentation

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Run with `--verbose` for detailed logs
3. Review Terraform Stacks documentation: https://developer.hashicorp.com/terraform/stacks
4. Check doormat documentation: https://github.com/hashicorp/doormat

## License

This script is provided as-is for use with Terraform Stacks.

## Changelog

### Version 1.0.0 (2026-05-29)

- Initial release
- Comprehensive validation and error handling
- Support for creating or using existing variable sets
- Configuration file support
- Dry run mode
- Verbose logging
- Rollback information on failure
- Built-in help documentation

---

**Happy Stacking! 🚀**