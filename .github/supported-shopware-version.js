#!/usr/bin/env node

const response = await fetch('https://repo.packagist.org/p2/shopware/core.json');
const json = await response.json();

const versions = [];

for (const version of json.packages['shopware/core']) {
    if (version.version.startsWith('v6.5') || version.version.startsWith('v6.6') || version.version.startsWith('v6.7')) {
        versions.push(version.version);
    }
}

console.log(JSON.stringify({
    matrix: {
        include: versions.map(version => ({
            version
        })),
        'fail-fast': false
    }
}))