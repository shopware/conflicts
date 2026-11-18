#!/usr/bin/env node

const response = await fetch('https://repo.packagist.org/p2/shopware/core.json');
const json = await response.json();

const knownBrokenVersions = [
    'v6.6.10.1', 'v6.6.10.0' // Symfony Bug, has been fixed in 6.6.10.2
];

/**
 * Database image used for the install test (passed to setup-shopware's `mysql-version` input),
 * keyed by Shopware line. Adding a line here is what enables it in the matrix.
 *
 * - `builtin` = the MySQL already installed on the runner, keep it as long as possible
 * - 6.5 can not be installed on mariadb:11 (SQLSTATE 1901, expression in CHECK clause) -> mysql:8.0
 * - 6.7+ is where we swap over to MariaDB, as it is the recommended database for new versions
 */
const databaseByLine = {
    '6.5': 'mysql:8.0',
    '6.6': 'builtin',
    '6.7': 'mariadb:11',
};

// Shopware versions are 4 digits (6.7.16.0), the minor is the 3 digit prefix (6.7.16).
function lineOf(version) {
    return version.match(/^v(\d+\.\d+)\.\d+\./)?.[1];
}

function minorOf(version) {
    return version.match(/^v(\d+\.\d+\.\d+)\./)?.[1];
}

function lineOfMinor(minor) {
    return minor.split('.').slice(0, 2).join('.');
}

function compareVersionsDescending(a, b) {
    const left = a.replace(/^v/, '').split('.').map(Number);
    const right = b.replace(/^v/, '').split('.').map(Number);

    for (let i = 0; i < Math.max(left.length, right.length); i++) {
        const diff = (right[i] ?? 0) - (left[i] ?? 0);

        if (diff !== 0) {
            return diff;
        }
    }

    return 0;
}

const versionsByMinor = new Map();

for (const { version } of json.packages['shopware/core']) {
    const line = lineOf(version);

    if (!line || !(line in databaseByLine)) {
        continue;
    }

    if (knownBrokenVersions.includes(version)) {
        continue;
    }

    const minor = minorOf(version);
    versionsByMinor.set(minor, [...(versionsByMinor.get(minor) ?? []), version]);
}

// Only the newest minor of every line is still supported, so we do not test every minor anymore.
const newestMinorByLine = new Map();

for (const minor of versionsByMinor.keys()) {
    const line = lineOfMinor(minor);
    const current = newestMinorByLine.get(line);

    if (!current || compareVersionsDescending(minor, current) < 0) {
        newestMinorByLine.set(line, minor);
    }
}

const include = [];

for (const minor of [...newestMinorByLine.values()].sort(compareVersionsDescending)) {
    const versions = versionsByMinor.get(minor).sort(compareVersionsDescending);
    const mysql = databaseByLine[lineOfMinor(minor)];

    for (const version of versions) {
        include.push({ version, mysql });
    }
}

console.log(JSON.stringify({
    matrix: {
        include
    },
    'fail-fast': false
}))