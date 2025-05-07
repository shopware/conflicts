# Contributing

This repository is a meta package that adds conflicts for packages that are not compatible with Shopware.

You can see in [USAGES.md](USAGES.md) which Shopware version uses which version of the conflicts package.

# How to add a new conflict

1. Add a new conflict to the `composer.[version].json` file.
2. Create PR against `main` branch.
3. After merge the PR, the workflow will update the tags automatically.

> [!IMPORTANT]  
> Right now Packagist does not automatically update the tags, so you need to manually delete the version and press update button.
