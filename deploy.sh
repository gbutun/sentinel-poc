#!/usr/bin/env bash
# Terraform wrapper for the Microsoft Sentinel POC.
# Concept mirrors terraform-codebase/art-app-azure: flat tf-resources dir,
# azurerm remote backend configured at init time via -backend-config flags,
# non-secret vars in terraform.tfvars, secrets in sensitive.auto.tfvars.
set -euo pipefail

ACTION=""
ENVIRONMENT=""
PLAN_TIMESTAMP=""

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DATE_STAMP="$(date -u +%Y%m%d)"

VALID_ACTIONS="init plan apply destroy validate fmt refresh state-break-lease show-plan-json"
VALID_ENVIRONMENTS="poc"

usage() {
  cat <<'EOF'
Usage:
  ./deploy.sh <action> <environment> [plan_timestamp]

Actions      : init | plan | apply | destroy | validate | fmt | refresh | state-break-lease | show-plan-json
Environments : poc

Examples:
  ./deploy.sh init poc
  ./deploy.sh plan poc
  ./deploy.sh apply poc 20260903T120000Z
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || { echo "Required command not found: $1" >&2; exit 1; }
}

get_tfvar_value() {
  local file_path="$1" key="$2"
  [[ -f "$file_path" ]] || { echo "Terraform vars file not found: $file_path" >&2; exit 1; }
  awk -F= -v wanted="$key" '
    /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/ {
      k=$1; gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      if (k == wanted) {
        v=substr($0, index($0, "=") + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        gsub(/^"/, "", v); gsub(/"$/, "", v)
        print v; exit
      }
    }' "$file_path"
}

parse_args() {
  local positionals=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -*) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
      *) positionals+=("$1"); shift ;;
    esac
  done
  [[ ${#positionals[@]} -ge 1 ]] && ACTION="${positionals[0]}"
  [[ ${#positionals[@]} -ge 2 ]] && ENVIRONMENT="${positionals[1]}"
  [[ ${#positionals[@]} -ge 3 ]] && PLAN_TIMESTAMP="${positionals[2]}"
}

validate_args() {
  [[ -n "$ACTION" ]] || { echo "Action parameter required" >&2; usage; exit 1; }
  [[ -n "$ENVIRONMENT" ]] || { echo "Environment parameter required" >&2; usage; exit 1; }
  [[ " $VALID_ACTIONS " == *" $ACTION "* ]] || { echo "Invalid action: $ACTION" >&2; exit 1; }
  [[ " $VALID_ENVIRONMENTS " == *" $ENVIRONMENT "* ]] || { echo "Invalid environment: $ENVIRONMENT" >&2; exit 1; }
  if [[ "$ACTION" =~ ^(apply|show-plan-json)$ && -z "$PLAN_TIMESTAMP" ]]; then
    echo "Plan timestamp parameter required for '$ACTION'" >&2; exit 1
  fi
}

initialize_paths() {
  ROOT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ENV_PATH="$ROOT_PATH/environments/$ENVIRONMENT"
  TF_RESOURCES_PATH="$ENV_PATH/tf-resources"
  PLANS_PATH="$ENV_PATH/plans"
  OUTPUTS_PATH="$ENV_PATH/outputs/$DATE_STAMP"
  VARS_FILE="$TF_RESOURCES_PATH/terraform.tfvars"
  SENSITIVE_VARS_FILE="$TF_RESOURCES_PATH/sensitive.auto.tfvars"
  [[ -d "$TF_RESOURCES_PATH" ]] || { echo "Not found: $TF_RESOURCES_PATH" >&2; exit 1; }
  mkdir -p "$PLANS_PATH" "$OUTPUTS_PATH"
}

build_names() {
  local company product
  company="$(get_tfvar_value "$VARS_FILE" "company_name_short")"
  product="$(get_tfvar_value "$VARS_FILE" "product_name_short")"
  STATE_KEY_FILE_NAME="$ENVIRONMENT-$company-$product.tfstate"
  if [[ "$ACTION" == "plan" ]]; then
    PLAN_FILE_PATH="$PLANS_PATH/$ENVIRONMENT-$company-$product-$TIMESTAMP.tfplan"
  else
    PLAN_FILE_PATH="$PLANS_PATH/$ENVIRONMENT-$company-$product-$PLAN_TIMESTAMP.tfplan"
  fi
  OUTPUT_FILE_PATH="$OUTPUTS_PATH/$ENVIRONMENT-$company-$product-$ACTION-$TIMESTAMP.log"
}

load_config() {
  STORAGE_ACCOUNT_NAME="$(get_tfvar_value "$SENSITIVE_VARS_FILE" "storage_account_name")"
  CONTAINER_NAME="$(get_tfvar_value "$SENSITIVE_VARS_FILE" "storage_container_name")"
  ACCESS_KEY="$(get_tfvar_value "$SENSITIVE_VARS_FILE" "storage_access_key")"
}

run_and_log() { local f="$1"; shift; "$@" 2>&1 | tee -a "$f"; }

invoke() {
  case "$ACTION" in
    init)
      run_and_log "$OUTPUT_FILE_PATH" terraform -chdir="$TF_RESOURCES_PATH" init \
        -upgrade=true -no-color -backend=true \
        "-backend-config=storage_account_name=$STORAGE_ACCOUNT_NAME" \
        "-backend-config=container_name=$CONTAINER_NAME" \
        "-backend-config=access_key=$ACCESS_KEY" \
        "-backend-config=key=$STATE_KEY_FILE_NAME" ;;
    plan)
      run_and_log "$OUTPUT_FILE_PATH" terraform -chdir="$TF_RESOURCES_PATH" plan \
        -no-color -refresh=true \
        "-var-file=$VARS_FILE" "-var-file=$SENSITIVE_VARS_FILE" "-out=$PLAN_FILE_PATH" ;;
    apply)
      [[ -f "$PLAN_FILE_PATH" ]] || { echo "Plan file not found: $PLAN_FILE_PATH" >&2; exit 1; }
      run_and_log "$OUTPUT_FILE_PATH" terraform -chdir="$TF_RESOURCES_PATH" apply -no-color "$PLAN_FILE_PATH" ;;
    destroy)
      run_and_log "$OUTPUT_FILE_PATH" terraform -chdir="$TF_RESOURCES_PATH" destroy \
        -no-color -refresh=true "-var-file=$VARS_FILE" "-var-file=$SENSITIVE_VARS_FILE" ;;
    validate) terraform -chdir="$TF_RESOURCES_PATH" validate -no-color ;;
    fmt) terraform -chdir="$TF_RESOURCES_PATH" fmt -recursive -no-color ;;
    refresh)
      run_and_log "$OUTPUT_FILE_PATH" terraform -chdir="$TF_RESOURCES_PATH" refresh \
        -no-color "-var-file=$VARS_FILE" "-var-file=$SENSITIVE_VARS_FILE" ;;
    show-plan-json)
      [[ -f "$PLAN_FILE_PATH" ]] || { echo "Plan file not found: $PLAN_FILE_PATH" >&2; exit 1; }
      terraform -chdir="$TF_RESOURCES_PATH" show -json "$PLAN_FILE_PATH" ;;
    state-break-lease)
      require_command az
      az storage blob lease break --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$ACCESS_KEY" \
        --container-name "$CONTAINER_NAME" --blob-name "$STATE_KEY_FILE_NAME" --output none
      echo "Lease broken for $STATE_KEY_FILE_NAME" ;;
  esac
}

main() {
  require_command terraform
  parse_args "$@"
  validate_args
  initialize_paths
  build_names
  load_config
  echo "----------------------------------------------------------------------"
  echo "Action=[$ACTION] Environment=[$ENVIRONMENT] State=[$STATE_KEY_FILE_NAME]"
  echo "----------------------------------------------------------------------"
  invoke
  echo "Finished. Log: $OUTPUT_FILE_PATH"
}

main "$@"
