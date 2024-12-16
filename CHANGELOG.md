# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2024-03-21

### Added
- Support for AKS cluster deployments in `values-aks.yaml`
- New airgap configuration options in `values-airgap.yaml`
- Registry image synchronization script for airgapped environments

### Changed
- Updated external-dns configuration for better multi-cluster support
- Enhanced security tools configuration in `tools/security.yaml`
- Improved installation script with better error handling

### Deprecated
- Old registry sync method in favor of new `registry-image-sync.sh`

### Removed
- Legacy cluster configuration options

### Fixed
- DNS resolution issues in airgapped environments
- Security tool deployment failures in GKE clusters

### Security
- Updated security configurations to address CVE-2024-XXXXX
