#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ENV_PATH="${WENDAO_CODE_PARSER_TEST_ENV:-$(mktemp -d)}"
if [[ -z "${WENDAO_CODE_PARSER_TEST_ENV:-}" ]]; then
  trap 'rm -rf "${ENV_PATH}"' EXIT
fi
export WENDAO_CODE_PARSER_TEST_ENV="${ENV_PATH}"

if [[ ! -f "${ENV_PATH}/Project.toml" ]]; then
  "${JULIA:-julia}" "${ROOT}/scripts/prepare_wendao_code_parser_env.jl"
fi

exec "${JULIA:-julia}" --project="${ENV_PATH}" "${ROOT}/test/runtests.jl"
