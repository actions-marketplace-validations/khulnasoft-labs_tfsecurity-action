#!/usr/bin/env bash

set -xe

if [ -z "${INPUT_GITHUB_TOKEN}" ] ; then
  echo "::notice title=GitHub API token::Consider setting a GITHUB_TOKEN to prevent GitHub api rate limits"
fi

TFSECURITY_VERSION=""
if [ "$INPUT_VERSION" != "latest" ] && [ -n "$INPUT_VERSION" ]; then
  TFSECURITY_VERSION="tags/${INPUT_VERSION}"
else
  TFSECURITY_VERSION="latest"
fi

function get_release_assets() {
  repo="$1"
  version="$2"
  args=(
    -sSL
    --header "Accept: application/vnd.github+json"
  )
  [ -n "${INPUT_GITHUB_TOKEN}" ] && args+=(--header "Authorization: Bearer ${INPUT_GITHUB_TOKEN}")

  if ! curl --fail-with-body -sS "${args[@]}" "https://api.github.com/repos/${repo}/releases/${version}"; then
    echo "::error title=GitHub API request failure::The request to the GitHub API was likely rate-limited. Set a GITHUB_TOKEN to prevent this"
    exit 1
  else
    curl "${args[@]}" "https://api.github.com/repos/${repo}/releases/${version}" | jq '.assets[] | { name: .name, download_url: .browser_download_url }'
  fi
}

function install_release() {
  repo="$1"
  version="$2"
  binary="$3-linux-amd64"
  checksum="$4"
  release_assets="$(get_release_assets "${repo}" "${version}")"

  curl -sLo "${binary}" "$(echo "${release_assets}" | jq -r ". | select(.name == \"${binary}\") | .download_url")"
  curl -sLo "$3-checksums.txt" "$(echo "${release_assets}" | jq -r ". | select(.name | contains(\"$checksum\")) | .download_url")"

  grep "${binary}" "$3-checksums.txt" | sha256sum -c -
  install "${binary}" "/usr/local/bin/${3}"
}

install_release khulnasoft-labs/tfsecurity "${TFSECURITY_VERSION}" tfsecurity tfsecurity_checksums.txt

if [ -n "${GITHUB_WORKSPACE}" ]; then
  cd "${GITHUB_WORKSPACE}" || exit
fi

if [ -n "${INPUT_ADDITIONAL_ARGS}" ]; then
  TFSECURITY_ARGS_OPTION="${INPUT_ADDITIONAL_ARGS}"
fi

if [ -n "${INPUT_SOFT_FAIL}" ]; then 
  SOFT_FAIL="--soft-fail"
fi

FORMAT=${INPUT_FORMAT:-default}

tfsecurity --format="${FORMAT}" ${SOFT_FAIL} ${TFSECURITY_ARGS_OPTION} "${INPUT_WORKING_DIRECTORY}"
