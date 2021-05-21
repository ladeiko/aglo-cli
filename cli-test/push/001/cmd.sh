#!/usr/bin/env bash

set -e

THIS_SCRIPT_PATH=$(cd "$(dirname "$0")" && pwd)
TMPDIR=$(mktemp -d)

if [ ! -e "${TMPDIR}" ]; then
    >&2 echo "Failed to create temp directory"
    exit 1
fi

trap "exit 1"           HUP INT PIPE QUIT TERM
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "${THIS_SCRIPT_PATH}/input/" "${TMPDIR}/"
cp "${THIS_SCRIPT_PATH}/aglo.config.yml" "${TMPDIR}/"

"${THIS_SCRIPT_PATH}/../../../aglo-cli.rb" push --config "${TMPDIR}/aglo.config.yml"

diff --recursive "${THIS_SCRIPT_PATH}/expected" "${TMPDIR}" --exclude '.DS_Store' || {\
    echo "TEST FAILED";\
    exit 1;\
}