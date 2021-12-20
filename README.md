# Shopware 6 conflicting packages

This is a meta package that adds conflicts for packages that are not compatible
with Shopware.

Shopware 6 is an open source ecommerce platform based on a quite modern technology stack that is powered by Symfony and Vue.js. It's the successor of the very successful ecommerce shopping cart Shopware 5 which has over 800,000 downloads. Shopware 6 is focused on an API-first approach, so it's quite easy to think in different sales channels and make ecommerce happen whereever you want it.

## License

Shopware 6 is licensed under the terms of the MIT.

## Installation

```
composer require shopware/conflicts:@dev
```

We will make sure that no matter how many branches we will add here, you will
always get the version matching your packages when you require `@dev`.