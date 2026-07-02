#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-3.8.8-mh-zarronly.0}"
PACK_DIR="${2:-lib_vitessce_zarronly_${VERSION}}"

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

PACKAGE_NAMES=(
  "@vitessce/constants-internal"
  "@vitessce/error"
  "@vitessce/plugins"
  "@vitessce/types"
  "@vitessce/globals"
  "@vitessce/abstract"
  "@vitessce/constants"
  "@vitessce/utils"
  "@vitessce/zarr-utils"
  "@vitessce/config"
  "@vitessce/schemas"
  "@vitessce/spatial-utils"
  "@vitessce/image-utils"
  "@vitessce/sets-utils"
  "@vitessce/zarr"
  "@vitessce/spatial-zarr"
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

BACKUP_DIR="$(mktemp -d)"

restore_manifests() {
  local file

  for file in "${MANIFESTS[@]}"; do
    if [[ -f "$BACKUP_DIR/$file" ]]; then
      cp "$BACKUP_DIR/$file" "$file"
    fi
  done

  if [[ -f "$BACKUP_DIR/pnpm-lock.yaml" ]]; then
    cp "$BACKUP_DIR/pnpm-lock.yaml" pnpm-lock.yaml
  fi

  rm -rf "$BACKUP_DIR"
}

trap restore_manifests EXIT

backup_file() {
  local file="$1"

  mkdir -p "$BACKUP_DIR/$(dirname "$file")"
  cp "$file" "$BACKUP_DIR/$file"
}

for file in "${MANIFESTS[@]}"; do
  backup_file "$file"
done

if [[ -f pnpm-lock.yaml ]]; then
  cp pnpm-lock.yaml "$BACKUP_DIR/pnpm-lock.yaml"
fi

update_manifests() {
  local mode="$1"

  VERSION="$VERSION" MODE="$mode" node - "${MANIFESTS[@]}" <<'NODE'
const fs = require('fs');

const version = process.env.VERSION;
const mode = process.env.MODE;
const files = process.argv.slice(2);

for (const file of files) {
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  data.version = version;

  if (file.endsWith('/package.json')) {
    const dependencies = { ...(data.dependencies || {}) };
    const peerDependencies = { ...(data.peerDependencies || {}) };
    const devDependencies = { ...(data.devDependencies || {}) };
    const internalNames = new Set(
      [...Object.keys(dependencies), ...Object.keys(peerDependencies)]
        .filter((name) => name.startsWith('@vitessce/')),
    );

    for (const name of internalNames) {
      delete dependencies[name];
      peerDependencies[name] = version;

      if (mode === 'build') {
        devDependencies[name] = 'workspace:*';
      } else if (mode === 'pack') {
        delete devDependencies[name];
      } else {
        throw new Error(`Unknown manifest update mode: ${mode}`);
      }
    }

    if (mode === 'pack') {
      for (const name of Object.keys(devDependencies)) {
        if (name.startsWith('@vitessce/')) {
          delete devDependencies[name];
        }
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

    if (Object.keys(devDependencies).length > 0) {
      data.devDependencies = devDependencies;
    } else {
      delete data.devDependencies;
    }
  }

  fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
}
NODE
}

echo "Checking Node.js version"
node <<'NODE'
const [major, minor] = process.versions.node.split('.').map(Number);
const ok = major > 22 || (major === 22 && minor >= 12) || (major === 20 && minor >= 19);

if (!ok) {
  console.error(`Node.js ${process.versions.node} detected. Vite requires Node.js 20.19+ or 22.12+.`);
  process.exit(1);
}
NODE

echo "Preparing temporary build manifests for ${VERSION}"
update_manifests build

echo "Installing dependencies"
pnpm install --force --no-frozen-lockfile

echo "Cleaning previous build output"
pnpm run clean

echo "Building TypeScript output"
pnpm exec tsc --build

FILTER_ARGS=()
for package_name in "${PACKAGE_NAMES[@]}"; do
  FILTER_ARGS+=(--filter "$package_name")
done

echo "Building bundled output for zarr-only package closure"
pnpm -r "${FILTER_ARGS[@]}" --workspace-concurrency 1 bundle

echo "Preparing pack manifests for ${VERSION}"
update_manifests pack

mkdir -p "$PACK_DIR"
find "$PACK_DIR" -maxdepth 1 -type f -name "vitessce-*-${VERSION}.tgz" -delete

echo "Packing tarballs into ${PACK_DIR}"
for package_dir in "${PACKAGES[@]}"; do
  pnpm --dir "$package_dir" pack --pack-destination "$ROOT_DIR/$PACK_DIR"
done

echo "Packed files:"
find "$PACK_DIR" -maxdepth 1 -type f -name "vitessce-*-${VERSION}.tgz" -print | sort

echo "Done. Original manifests and pnpm-lock.yaml have been restored."
