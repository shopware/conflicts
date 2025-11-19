#!/usr/bin/env php
<?php

declare(strict_types=1);

$repoRoot = dirname(__DIR__);
$defaultOutputDir = $repoRoot . '/build/local-repository';

$options = getopt('', ['output::']);
$outputArgument = $options['output'] ?? ($argv[1] ?? null);

$outputDir = $outputArgument !== null
    ? normalizePath($outputArgument, $repoRoot)
    : $defaultOutputDir;

$packages = buildPackageMatrix($repoRoot);
if ($packages === []) {
    fwrite(STDERR, "No composer.*.json files found.\n");
    exit(1);
}

ksort($packages);
foreach ($packages as &$versions) {
    uksort($versions, static fn (string $a, string $b): int => version_compare($b, $a));
}
unset($versions);

if (!is_dir($outputDir) && !mkdir($outputDir, 0777, true) && !is_dir($outputDir)) {
    fwrite(STDERR, sprintf("Failed to create output directory '%s'.\n", $outputDir));
    exit(1);
}

$outputFile = rtrim($outputDir, DIRECTORY_SEPARATOR) . '/packages.json';
$json = json_encode(
    ['packages' => $packages],
    JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR
);

file_put_contents($outputFile, $json . PHP_EOL);

$versionCount = array_reduce(
    $packages,
    static fn (int $carry, array $versions): int => $carry + count($versions),
    0
);

fwrite(
    STDOUT,
    sprintf(
        "Generated %d package version(s) for %d package(s) in %s\n",
        $versionCount,
        count($packages),
        $outputFile
    )
);

/**
 * @return array<string, array<string, array<string, mixed>>>
 */
function buildPackageMatrix(string $repoRoot): array
{
    $matrix = [];
    $files = glob($repoRoot . '/composer.*.json');
    if ($files === false) {
        return [];
    }

    sort($files, SORT_NATURAL);

    foreach ($files as $file) {
        $basename = basename($file);
        if ($basename === 'composer.json') {
            continue;
        }

        if (!preg_match('/^composer\.(.+)\.json$/', $basename, $matches)) {
            continue;
        }

        $version = $matches[1];
        $contents = file_get_contents($file);

        if ($contents === false) {
            fwrite(STDERR, sprintf("Unable to read %s, skipping.\n", $basename));
            continue;
        }

        $packageData = json_decode($contents, true, 512, JSON_THROW_ON_ERROR);
        $name = $packageData['name'] ?? null;

        if (!is_string($name) || $name === '') {
            fwrite(STDERR, sprintf("Missing 'name' in %s, skipping.\n", $basename));
            continue;
        }

        $packageData['version'] = $version;
        $packageData['type'] ??= 'metapackage';

        $matrix[$name][$version] = $packageData;
    }

    return $matrix;
}

function normalizePath(string $path, string $repoRoot): string
{
    if (isAbsolutePath($path)) {
        return $path;
    }

    return $repoRoot . '/' . ltrim($path, DIRECTORY_SEPARATOR);
}

function isAbsolutePath(string $path): bool
{
    if ($path === '') {
        return false;
    }

    if ($path[0] === '/' || $path[0] === '\\') {
        return true;
    }

    return (bool) preg_match('/^[A-Z]:[\\\\\\/]/i', $path);
}
