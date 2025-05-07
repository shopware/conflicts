#!/usr/bin/env node

const response = await fetch('https://repo.packagist.org/p2/shopware/core.json');
const json = await response.json();
import fs from 'node:fs';

const mapping = new Map();
let previousVersion = null;

for (const version of json.packages['shopware/core']) {
  if (version.require) {
    previousVersion = version
  }

  if (previousVersion.require['shopware/conflicts']) {
    mapping.set(version.version, previousVersion.require['shopware/conflicts'])
  }
}


// Generate the USE.md content
let useTableContent = `# Shopware Version to Conflicts Version Mapping

This document shows which version of \`shopware/conflicts\` is used by each version of \`shopware/core\`.

| Shopware Version | Conflicts Version |
|-----------------|-------------------|
`;

// Add each mapping entry to the table
for (const [shopwareVersion, conflictsVersion] of mapping) {
  useTableContent += `| ${shopwareVersion} | ${conflictsVersion} |\n`;
}

// Write the content to USE.md
fs.writeFileSync('USAGES.md', useTableContent);

console.log('USAGES.md has been generated successfully.');
