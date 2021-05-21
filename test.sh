#!/usr/bin/env bash

set -e

SCRIPT_PATH=$(cd "$(dirname "$0")" && pwd)
TMP_DIR=$(mktemp -d -t ci-aglo-cli)

trap "rm -rf ${TMP_DIR}" EXIT

TESTS=$(ls "${SCRIPT_PATH}/IntegrationTests")
if [ ! -z "$1" ]; then
    TESTS="$1"
fi

for TEST in ${TESTS}; do
    echo -n "Testing '${TEST}'"
    rm -rf "${TMP_DIR}"
    mkdir -p "${TMP_DIR}"
    cp -rf "${SCRIPT_PATH}/IntegrationTests/${TEST}/input/" "${TMP_DIR}/"
    cp "${SCRIPT_PATH}/IntegrationTests/${TEST}/aglo.config.yml" "${TMP_DIR}/"
    
    ARGS_FILE="${SCRIPT_PATH}/IntegrationTests/${TEST}/args.txt"
    RUN_FILE="${SCRIPT_PATH}/IntegrationTests/${TEST}/run.sh"
    
    if [ -f "${ARGS_FILE}" ]; then
        ARGUMENTS=$(cat "${ARGS_FILE}")
        ./aglo-cli.rb ${ARGUMENTS} --config "${TMP_DIR}" > /dev/null
    elif [ -f "${RUN_FILE}" ]; then
        (cd "${SCRIPT_PATH}" && bash "${RUN_FILE}" "${TMP_DIR}") > /dev/null
    else
        echo "no args.txt/run.sh found to test"
        exit 1
    fi
    find "${TMP_DIR}" -name ".DS_Store" -exec rm "{}" \;
    echo -n " - "
    if diff -qr -x ".DS_Store" -x "aglo.config.yml" "${TMP_DIR}/" "${SCRIPT_PATH}/IntegrationTests/${TEST}/expected/" > /dev/null; then
        echo 'PASSED'
    else
        echo -e 'FAILED'
        diff -ur -x ".DS_Store" -x "aglo.config.yml" "${TMP_DIR}/" "${SCRIPT_PATH}/IntegrationTests/${TEST}/expected/"
        exit 1
    fi
done

