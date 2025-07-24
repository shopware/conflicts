# Shopware 6 Conflict Management

This meta-package manages package conflicts for Shopware 6, serving as a central source of truth for incompatible package versions across the Shopware ecosystem.

## Purpose

This meta-package serves two critical functions:

1. **Conflict Prevention**: It explicitly defines package versions that are known to be incompatible with Shopware 6, preventing installation of problematic dependencies that could break your installation.

2. **Centralized Management**: By maintaining conflicts in a separate package, we can update compatibility information without requiring a full Shopware release.

## Version Management Strategy

This repository employs a unique single-branch version management strategy:

### Single Source of Truth
- All version configurations are maintained in the main branch
- Each version has its own composer file (e.g., `composer.0.6.0.json`)
- No need for multiple branches or PRs for different versions

### Automated Tag Management
The repository includes an automated synchronization system that:
1. Maintains different version tags from a single branch
2. Automatically updates tags when changes are made
3. Ensures each tag points to the correct composer configuration
4. Compares local and remote tags to keep them in sync

This approach means:
- One PR can update multiple versions simultaneously
- Reduced maintenance overhead
- Consistent conflict definitions across versions
- Clear version history and tracking
- Automated tag management prevents manual errors

## Usage Reference

For specific version compatibility information, please refer to [USAGES.md](USAGES.md) which maps Shopware versions to their corresponding conflicts package versions.

## About Shopware 6

Shopware 6 is an open source ecommerce platform built on Symfony and Vue.js. As the successor to Shopware 5, it focuses on an API-first approach, enabling flexible ecommerce solutions across various sales channels.

## License

This package is licensed under the MIT license.
