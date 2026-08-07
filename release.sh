#!/bin/bash
# Exit immediately if any command fails
set -e

PUBSPEC="pubspec.yaml"

if [ ! -f "$PUBSPEC" ]; then
  echo "Error: pubspec.yaml not found in current directory."
  exit 1
fi

# Print usage instructions if help requested
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  echo "Usage: ./release.sh [patch|minor]"
  echo "  patch  - Increment patch version (e.g., 1.0.6 -> 1.0.7) and build code (+1)"
  echo "  minor  - Increment minor version (e.g., 1.0.6 -> 1.1.0) and build code (+1)"
  echo "  (Default is 'patch' if no argument is provided)"
  exit 0
fi

# Determine increment type (default to patch)
INCREMENT_TYPE="patch"
if [ ! -z "$1" ]; then
  INCREMENT_TYPE=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  if [ "$INCREMENT_TYPE" != "patch" ] && [ "$INCREMENT_TYPE" != "minor" ]; then
    echo "Error: Invalid argument '$1'. Use 'patch' or 'minor'."
    exit 1
  fi
fi

echo "=== Automated Version Update (${INCREMENT_TYPE}) ==="

# Run Python helper to increment the version only once and print exports for Bash
EXPORT_VARS=$(python3 -c "
import re
import sys

increment_type = '${INCREMENT_TYPE}'
pubspec_path = '${PUBSPEC}'

try:
    with open(pubspec_path, 'r') as f:
        content = f.read()
except Exception as e:
    print(f'echo \"Error reading {pubspec_path}: {e}\"; exit 1')
    sys.exit(1)

# Matches version: X.Y.Z+B or version: X.Y.Z (with or without build number)
pattern = r'^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)(?:\+([0-9]+))?'
match = re.search(pattern, content, re.MULTILINE)

if not match:
    print('echo \"Error: Could not parse version line in pubspec.yaml\"; exit 1')
    sys.exit(1)

major = int(match.group(1))
minor = int(match.group(2))
patch = int(match.group(3))
build = int(match.group(4)) if match.group(4) is not None else 0

# Increment semantic version
if increment_type == 'minor':
    new_minor = minor + 1
    new_patch = 0
    new_semver = f'{major}.{new_minor}.{new_patch}'
else: # patch
    new_patch = patch + 1
    new_semver = f'{major}.{minor}.{new_patch}'

# Increment build number (versionCode)
new_build = build + 1
new_version = f'version: {new_semver}+{new_build}'

new_content = re.sub(pattern, new_version, content, flags=re.MULTILINE)

try:
    with open(pubspec_path, 'w') as f:
        f.write(new_content)
except Exception as e:
    print(f'echo \"Error writing {pubspec_path}: {e}\"; exit 1')
    sys.exit(1)

# Output variable definitions to be evaluated by the parent bash script
print(f'VERSION_NAME={new_semver}')
print(f'VERSION_CODE={new_build}')
")

# Evaluate variables defined by Python script (VERSION_NAME and VERSION_CODE)
eval "$EXPORT_VARS"

if [ -z "$VERSION_NAME" ] || [ -z "$VERSION_CODE" ]; then
  echo "Error: Version increment failed."
  exit 1
fi

echo "Successfully incremented version in pubspec.yaml to: ${VERSION_NAME}+${VERSION_CODE}"

echo "=== Running Flutter Clean ==="
flutter clean

echo "=== Running Flutter Pub Get ==="
flutter pub get

echo "=== Building Android App Bundle (AAB) ==="
flutter build appbundle --release

echo "=== Building Flutter Web Release ==="
flutter build web --release

echo "=== Deploying to Firebase Hosting ==="
firebase deploy --only hosting -m "Release v${VERSION_NAME}+${VERSION_CODE}"

# Check if current directory is a git repository
if [ -d .git ] || git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "=== Tagging Release in Git ==="
  git add pubspec.yaml
  git commit -m "Bump version to v${VERSION_NAME}+${VERSION_CODE}"
  
  # Create release tag
  TAG_NAME="v${VERSION_NAME}"
  
  # Delete the tag locally if it already exists (failsafe)
  if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo "Warning: Tag $TAG_NAME already exists locally. Re-creating tag."
    git tag -d "$TAG_NAME"
  fi
  
  git tag "$TAG_NAME"
  echo "Tag $TAG_NAME created."
  
  echo "=== Pushing Tag to Remote (origin) ==="
  # Push tag (and commit) to origin
  git push origin HEAD
  git push origin "$TAG_NAME"
else
  echo "=== Skipping Git Tag/Push (Not inside a git repository) ==="
fi

echo "=================================================="
echo "Release process completed successfully!"
echo "Version: ${VERSION_NAME}+${VERSION_CODE}"
echo "Android AAB: build/app/outputs/bundle/release/app-release.aab"
echo "Web Build: build/web (Deployed to Firebase Hosting)"
echo "=================================================="
