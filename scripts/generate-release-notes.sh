#!/bin/bash

VERSION=$1
CHANGELOG_FILE="CHANGELOG.md"
RELEASE_FILE="RELEASE.md"

# Extract the latest version's changes from CHANGELOG.md
latest_changes=$(awk "/## \[$VERSION\]/{p=1;print;next} /## \[/{p=0} p" "$CHANGELOG_FILE")

# Convert changelog format to release notes format
cat > "$RELEASE_FILE" << EOF
# Release $VERSION

## What's Changed
### 🚀 Features
$(echo "$latest_changes" | grep "^- " | grep -i "add" | sed 's/- /* /')

### 🔧 Improvements
$(echo "$latest_changes" | grep "^- " | grep -iE "updat|improv|enhanc|optimiz" | sed 's/- /* /')

### 🐛 Bug Fixes
$(echo "$latest_changes" | grep "^- " | grep -iE "fix|resolv|correct" | sed 's/- /* /')

### 📝 Documentation
$(echo "$latest_changes" | grep "^- " | grep -i "doc" | sed 's/- /* /')

### 🔒 Security Updates
$(echo "$latest_changes" | grep "^- " | grep -i "secur" | sed 's/- /* /')

## 📋 Full Changelog
[Compare previous version...$VERSION](https://github.com/$GITHUB_REPOSITORY/compare/previous-version...$VERSION)

## 🙏 Contributors
$(git log "previous-version...$VERSION" --format="@%aN" | sort -u | tr '\n' ', ')

## 📦 Installation
\`\`\`bash
# Add installation instructions here
\`\`\`
EOF
