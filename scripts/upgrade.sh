#!/bin/bash

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
            read -p "Do you want to update $name from $current_version to $latest_version? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Update the version using yq
                yq e ".dependencies[$i].version = \"$latest_version\"" -i "$chart_file"
                echo "Updated $name to version $latest_version"
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
