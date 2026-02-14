#!/bin/bash

# Function to display help message
show_help() {
    cat << EOF
Usage: $(basename $0) [options]

This script checks and updates external Helm chart versions referenced in the
app-of-apps values.yaml file and the ArgoCD/Cilium chart versions in
scripts/install.sh. It compares current versions with the latest available
versions from their respective repositories.

Options:
    -h, --help    Show this help message
    -y            Automatically update all dependencies without asking for confirmation
                  (Default behavior is to ask for confirmation for each update)
    -l, --list    Show a list of all external chart references and their current versions
                  without checking for updates

Examples:
    $(basename $0)          # Run with confirmation prompts
    $(basename $0) -y       # Run with automatic updates
    $(basename $0) -l       # List all external chart references
    $(basename $0) --help   # Show this help message

The script will:
1. Parse app-of-apps/values.yaml for applications with chart and repoURL fields
2. Check ArgoCD and Cilium chart versions in scripts/install.sh
3. Check each chart's current version against the latest available version
4. Update versions if newer versions are available

Supports both HTTP-based Helm repositories and OCI registries.
EOF
    exit 0
}

# Check for --help first
for arg in "$@"; do
    if [ "$arg" == "--help" ]; then
        show_help
    fi
done

# Parse command line arguments
AUTO_CONFIRM=false
LIST_ONLY=false
while getopts "hyl-:" opt; do
    case ${opt} in
        h )
            show_help
            ;;
        y )
            AUTO_CONFIRM=true
            ;;
        l )
            LIST_ONLY=true
            ;;
        - )
            case "${OPTARG}" in
                help)
                    show_help
                    ;;
                list)
                    LIST_ONLY=true
                    ;;
                *)
                    echo "Invalid option: --${OPTARG}" 1>&2
                    echo "Use -h or --help for help" 1>&2
                    exit 1
                    ;;
            esac
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            echo "Use -h or --help for help" 1>&2
            exit 1
            ;;
    esac
done

VALUES_FILE="app-of-apps/values.yaml"
INSTALL_SCRIPT="scripts/install.sh"

if [ ! -f "$VALUES_FILE" ]; then
    echo "Error: $VALUES_FILE not found. Run this script from the repository root."
    exit 1
fi

if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo "Error: $INSTALL_SCRIPT not found. Run this script from the repository root."
    exit 1
fi

# Update targetRevision for a specific app using awk instead of yq -i,
# because yq -i strips blank lines and reorganizes comments.
update_target_revision() {
    local app_name=$1
    local new_version=$2
    local tmpfile
    tmpfile=$(mktemp)
    awk -v app="  ${app_name}:" -v ver="$new_version" '
        /^  [^ #]/ { in_app = (index($0, app) == 1) }
        in_app && /^    targetRevision:/ {
            sub(/targetRevision: .*/, "targetRevision: " ver)
            in_app = 0
        }
        { print }
    ' "$VALUES_FILE" > "$tmpfile" && mv "$tmpfile" "$VALUES_FILE"
}

# ── Install script chart version helpers ──────────────────────────

# Install script charts: VAR_PREFIX|chart_name|repo_url
INSTALL_SCRIPT_CHARTS=(
    "ARGOCD|argo-cd|https://argoproj.github.io/argo-helm"
    "CILIUM|cilium|https://helm.cilium.io/"
)

# Read the current chart version from install.sh
get_install_script_version() {
    local var_prefix=$1
    grep "^readonly ${var_prefix}_CHART_VERSION=" "$INSTALL_SCRIPT" | sed 's/.*="\(.*\)"/\1/'
}

# Update the chart version constant in install.sh
update_install_script_version() {
    local var_prefix=$1
    local new_version=$2
    local tmpfile
    tmpfile=$(mktemp)
    sed "s/^readonly ${var_prefix}_CHART_VERSION=\".*\"/readonly ${var_prefix}_CHART_VERSION=\"${new_version}\"/" \
        "$INSTALL_SCRIPT" > "$tmpfile" && mv "$tmpfile" "$INSTALL_SCRIPT"
}

# Function to get index.yaml content from HTTP repository
get_index_yaml() {
    local repo_url=$1
    repo_url=${repo_url%/}
    local index_url="${repo_url}/index.yaml"
    local response
    response=$(curl -s -L "$index_url")
    if [ $? -eq 0 ]; then
        echo "$response"
    else
        echo "Failed to fetch index.yaml from $index_url" >&2
        return 1
    fi
}

# Function to get latest version from index.yaml content
get_latest_version_from_index() {
    local index_content=$1
    local chart_name=$2
    echo "$index_content" | yq e ".entries.${chart_name}[0].version" -
}

# Function to get the latest version of a chart from a repository
get_latest_version() {
    local repo_url=$1
    local chart_name=$2

    # Handle OCI registry
    if [[ $repo_url == oci://* ]]; then
        local chart_info=$(helm show chart "$repo_url/$chart_name" 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            local latest_version=$(echo "$chart_info" | yq e '.version' -)
            echo "$latest_version"
            return 0
        else
            echo "Failed to fetch chart info from OCI registry" >&2
            return 1
        fi
    fi

    # For HTTP-based repositories, use index.yaml
    local index_content
    index_content=$(get_index_yaml "$repo_url")
    if [[ $? -eq 0 ]]; then
        local latest_version
        latest_version=$(get_latest_version_from_index "$index_content" "$chart_name")
        if [[ -n "$latest_version" ]]; then
            echo "$latest_version"
            return 0
        fi
    fi

    echo "Failed to determine latest version" >&2
    return 1
}

# Get all application names that have a chart field
app_names=$(yq e '.ArgocdApplications | to_entries[] | select(.value.chart != null) | .key' "$VALUES_FILE")

if [ -z "$app_names" ]; then
    echo "No external chart references found in $VALUES_FILE"
    exit 0
fi

# List mode
if $LIST_ONLY; then
    printf "\nListing all external chart references:\n"
    printf "%-30s %-25s %-15s %s\n" "APPLICATION" "CHART" "VERSION" "REPOSITORY"
    printf "%s\n" "------------------------------------------------------------------------------------------------------------"

    while IFS= read -r app_name; do
        chart=$(yq e ".ArgocdApplications.\"$app_name\".chart" "$VALUES_FILE")
        version=$(yq e ".ArgocdApplications.\"$app_name\".targetRevision" "$VALUES_FILE")
        repo=$(yq e ".ArgocdApplications.\"$app_name\".repoURL" "$VALUES_FILE")
        printf "%-30s %-25s %-15s %s\n" "$app_name" "$chart" "$version" "$repo"
    done <<< "$app_names"

    printf "\n%-30s %-25s %-15s %s\n" "INSTALL SCRIPT" "CHART" "VERSION" "REPOSITORY"
    printf "%s\n" "------------------------------------------------------------------------------------------------------------"

    for entry in "${INSTALL_SCRIPT_CHARTS[@]}"; do
        IFS='|' read -r var_prefix chart_name repo_url <<< "$entry"
        version=$(get_install_script_version "$var_prefix")
        printf "%-30s %-25s %-15s %s\n" "$var_prefix" "$chart_name" "$version" "$repo_url"
    done

    printf "\n"
    exit 0
fi

# Update mode
if $AUTO_CONFIRM; then
    echo "Running in automatic update mode (no confirmation prompts)"
else
    echo "Running in interactive mode (will ask for confirmation before updates)"
fi

echo "Checking for external chart version updates..."

while IFS= read -r app_name; do
    chart=$(yq e ".ArgocdApplications.\"$app_name\".chart" "$VALUES_FILE")
    current_version=$(yq e ".ArgocdApplications.\"$app_name\".targetRevision" "$VALUES_FILE")
    repo=$(yq e ".ArgocdApplications.\"$app_name\".repoURL" "$VALUES_FILE")

    echo "Checking: $app_name ($chart)"
    echo "  Current version: $current_version"
    echo "  Repository: $repo"

    latest_version=$(get_latest_version "$repo" "$chart")
    local_status=$?

    if [[ $local_status -eq 0 && -n "$latest_version" && "$latest_version" != "$current_version" ]]; then
        echo "  New version available: $latest_version"

        if $AUTO_CONFIRM; then
            update_target_revision "$app_name" "$latest_version"
            echo "  Updated $app_name to version $latest_version"
        else
            read -p "  Update $app_name from $current_version to $latest_version? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                update_target_revision "$app_name" "$latest_version"
                echo "  Updated $app_name to version $latest_version"
            fi
        fi
    elif [[ $local_status -eq 1 ]]; then
        echo "  Failed to check version. Please verify manually."
    else
        echo "  Already using the latest version"
    fi
    echo "----------------------------------------"
done <<< "$app_names"

echo ""
echo "Checking install script chart versions (scripts/install.sh)..."

for entry in "${INSTALL_SCRIPT_CHARTS[@]}"; do
    IFS='|' read -r var_prefix chart_name repo_url <<< "$entry"
    current_version=$(get_install_script_version "$var_prefix")

    echo "Checking: $var_prefix ($chart_name)"
    echo "  Current version: $current_version"
    echo "  Repository: $repo_url"

    latest_version=$(get_latest_version "$repo_url" "$chart_name")
    local_status=$?

    if [[ $local_status -eq 0 && -n "$latest_version" && "$latest_version" != "$current_version" ]]; then
        echo "  New version available: $latest_version"

        if $AUTO_CONFIRM; then
            update_install_script_version "$var_prefix" "$latest_version"
            echo "  Updated $var_prefix in $INSTALL_SCRIPT to version $latest_version"
        else
            read -p "  Update $var_prefix from $current_version to $latest_version? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                update_install_script_version "$var_prefix" "$latest_version"
                echo "  Updated $var_prefix in $INSTALL_SCRIPT to version $latest_version"
            fi
        fi
    elif [[ $local_status -eq 1 ]]; then
        echo "  Failed to check version. Please verify manually."
    else
        echo "  Already using the latest version"
    fi
    echo "----------------------------------------"
done

echo "Finished checking all external charts"
