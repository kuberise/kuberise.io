#!/bin/bash

# Function to display help message
show_help() {
    cat << EOF
Usage: $(basename $0) [options]

This script checks and updates Helm chart dependencies in all Chart.yaml files
found in the templates directory. It compares current dependency versions with
the latest available versions from their respective repositories.

Options:
    -h, --help    Show this help message
    -y            Automatically update all dependencies without asking for confirmation
                  (Default behavior is to ask for confirmation for each update)

Examples:
    $(basename $0)          # Run with confirmation prompts
    $(basename $0) -y       # Run with automatic updates
    $(basename $0) --help   # Show this help message

The script will:
1. Search for all Chart.yaml files in the templates directory
2. Check each chart's dependencies
3. Compare current versions with latest available versions
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
while getopts "hy" opt; do
    case ${opt} in
        h )
            show_help
            ;;
        y )
            AUTO_CONFIRM=true
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            echo "Use -h or --help for help" 1>&2
            exit 1
            ;;
    esac
done

# Rest of the script remains the same
# Function to get the latest version of a chart from a repository
get_latest_version() {
    local repo_url=$1
    local chart_name=$2
    local current_version=$3

    # Handle OCI registry
    if [[ $repo_url == oci://* ]]; then
        # Get chart info using helm show chart
        local chart_info=$(helm show chart "$repo_url/$chart_name" 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            local latest_version=$(echo "$chart_info" | yq e '.version' -)
            echo "$latest_version"
            return 0
        else
            echo "Failed to fetch chart info from OCI registry"
            return 1
        fi
    fi

    # Remove trailing slash if present
    repo_url=${repo_url%/}

    # Add helm repo temporarily with a unique name
    local repo_hash=$(echo "$repo_url" | md5sum | cut -c1-8)
    helm repo add "temp_${repo_hash}" "$repo_url" >/dev/null 2>&1

    # Search for the latest version
    local latest_version=$(helm search repo "temp_${repo_hash}/$chart_name" --versions --output json | jq -r '.[0].version' 2>/dev/null)

    # Remove temporary repo
    helm repo remove "temp_${repo_hash}" >/dev/null 2>&1

    if [[ -n "$latest_version" ]]; then
        echo "$latest_version"
    fi
}

# Function to process a Chart.yaml file
process_chart() {
    local chart_file=$1
    echo "Processing: $chart_file"

    # Check if file has dependencies
    if ! yq e -e '.dependencies' "$chart_file" > /dev/null 2>&1; then
        echo "No dependencies found in $chart_file"
        echo "----------------------------------------"
        return
    fi

    # Get number of dependencies
    local deps_count=$(yq e '.dependencies | length' "$chart_file")

    for ((i=0; i<deps_count; i++)); do
        local name=$(yq e ".dependencies[$i].name" "$chart_file")
        local current_version=$(yq e ".dependencies[$i].version" "$chart_file")
        local repo=$(yq e ".dependencies[$i].repository" "$chart_file")

        echo "Checking dependency: $name"
        echo "Current version: $current_version"
        echo "Repository: $repo"

        local latest_version=$(get_latest_version "$repo" "$name" "$current_version")
        local get_version_status=$?

        if [[ $get_version_status -eq 0 && -n "$latest_version" && "$latest_version" != "$current_version" ]]; then
            echo "New version available: $latest_version"

            # If AUTO_CONFIRM is true, update without asking
            if $AUTO_CONFIRM; then
                yq e ".dependencies[$i].version = \"$latest_version\"" -i "$chart_file"
                echo "Updated $name to version $latest_version"
            else
                read -p "Do you want to update $name from $current_version to $latest_version? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    yq e ".dependencies[$i].version = \"$latest_version\"" -i "$chart_file"
                    echo "Updated $name to version $latest_version"
                fi
            fi
        elif [[ $get_version_status -eq 1 ]]; then
            echo "Failed to check version. Please verify manually."
        else
            echo "Already using the latest version"
        fi
        echo "----------------------------------------"
    done
}

# Main script
if $AUTO_CONFIRM; then
    echo "Running in automatic update mode (no confirmation prompts)"
else
    echo "Running in interactive mode (will ask for confirmation before updates)"
fi

echo "Checking for helm chart dependency updates..."

# Store found Chart.yaml files in an array - macOS compatible version
IFS=$'\n' read -r -d '' -a chart_files < <(find templates -name Chart.yaml | sort)

# Check if any files were found
if [ ${#chart_files[@]} -eq 0 ]; then
    echo "No Chart.yaml files found in templates directory"
    exit 0
fi

# Process each chart file
for chart_file in "${chart_files[@]}"; do
    process_chart "$chart_file"
done

echo "Finished checking all charts"
