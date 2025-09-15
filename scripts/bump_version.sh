#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/bump_version.sh patch
#   scripts/bump_version.sh minor
#   scripts/bump_version.sh major
#
# Optional: add -p to also create tag & commit.
#
# Flow:
#   1. Reads VERSION
#   2. Bumps part
#   3. Writes new VERSION
#   4. Optionally commits and tags
#
# Example:
#   scripts/bump_version.sh patch -p
#
# Produces commit: chore(release): v1.2.4
# Tag: v1.2.4

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

PART="${1:-}"
POST="${2:-}"

if [[ -z "${PART}" ]]; then
  echo "Specify which part to bump: major | minor | patch" >&2
  exit 1
fi

if [[ ! -f VERSION ]]; then
  echo "VERSION file not found." >&2
  exit 1
fi

CURRENT="$(tr -d ' \n' < VERSION)"
if [[ ! "${CURRENT}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "VERSION file does not contain a valid semver (got: ${CURRENT})" >&2
  exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"

case "${PART}" in
  major)
    MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
  minor)
    MINOR=$((MINOR+1)); PATCH=0 ;;
  patch)
    PATCH=$((PATCH+1)) ;;
  *)
    echo "Unknown bump part: ${PART}" >&2
    exit 1
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "${NEW_VERSION}" > VERSION
echo "Bumped version: ${CURRENT} -> ${NEW_VERSION}"

if [[ "${POST}" == "-p" ]]; then
  git add VERSION
  git commit -m "chore(release): v${NEW_VERSION}"
  git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
  echo "Created commit and tag v${NEW_VERSION}"
fi
