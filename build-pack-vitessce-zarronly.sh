#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-3.8.8-mh-zarronly.0}"
PACK_DIR="${2:-lib_vitessce}"

PACKAGES=(
  "packages/constants-internal"
  "packages/error"
  "packages/plugins"
  "packages/types"
  "packages/globals"
  "packages/file-types/abstract"
  "packages/constants"
  "packages/utils/other-utils"
  "packages/utils/zarr-utils"
  "packages/config"
  "packages/schemas"
  "packages/utils/spatial-utils"
  "packages/utils/image-utils"
  "packages/utils/sets-utils"
  "packages/file-types/zarr"
  "packages/file-types/spatial-zarr"
)

MANIFESTS=(
  "packages/file-types/abstract/package.json"
  "packages/config/package.json"
  "packages/constants/package.json"
  "packages/constants-internal/package.json"
  "packages/error/package.json"
  "packages/globals/package.json"
  "packages/utils/image-utils/package.json"
  "packages/plugins/package.json"
  "packages/schemas/package.json"
  "packages/utils/sets-utils/package.json"
  "packages/utils/spatial-utils/package.json"
  "packages/file-types/spatial-zarr/package.json"
  "packages/types/package.json"
  "packages/utils/other-utils/package.json"
  "packages/file-types/zarr/package.json"
  "packages/utils/zarr-utils/package.json"
  "packages/constants-internal/src/version.json"
)

echo "Setting Vitessce zarr-only package version to ${VERSION}"
VERSION="$VERSION" node - "${MANIFESTS[@]}" <<'NODE'
const fs = require('fs');

const version = process.env.VERSION;
const files = process.argv.slice(2);

for (const file of files) {
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  data.version = version;

  if (file.endsWith('/package.json')) {
    const dependencies = data.dependencies || {};
    const peerDependencies = data.peerDependencies || {};

    for (const name of Object.keys(dependencies)) {
      if (name.startsWith('@vitessce/')) {
        peerDependencies[name] = version;
        delete dependencies[name];
      }
    }

    if (Object.keys(dependencies).length > 0) {
      data.dependencies = dependencies;
    } else {
      delete data.dependencies;
    }

    if (Object.keys(peerDependencies).length > 0) {
      data.peerDependencies = peerDependencies;
    } else {
      delete data.peerDependencies;
    }
  }

  fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
}
NODE

echo "Building bundled output for zarr-only package closure"
pnpm \
  --filter @vitessce/abstract \
  --filter @vitessce/config \
  --filter @vitessce/constants \
  --filter @vitessce/constants-internal \
  --filter @vitessce/error \
  --filter @vitessce/globals \
  --filter @vitessce/image-utils \
  --filter @vitessce/plugins \
  --filter @vitessce/schemas \
  --filter @vitessce/sets-utils \
  --filter @vitessce/spatial-utils \
  --filter @vitessce/spatial-zarr \
  --filter @vitessce/types \
  --filter @vitessce/utils \
  --filter @vitessce/zarr \
  --filter @vitessce/zarr-utils \
  --workspace-concurrency 1 \
  bundle

echo "Building TypeScript declaration output"
pnpm exec tsc --build

mkdir -p "$PACK_DIR"

echo "Packing tarballs into ${PACK_DIR}"
for package_dir in "${PACKAGES[@]}"; do
  pnpm --dir "$package_dir" pack --pack-destination "$ROOT_DIR/$PACK_DIR"
done

echo "Packed files:"
find "$PACK_DIR" -maxdepth 1 -type f -name "vitessce-*-${VERSION}.tgz" -print | sort

echo "Done."
