#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_PATH="$(mktemp -d)"
trap 'rm -rf "${ENV_PATH}"' EXIT

"${JULIA:-julia}" --project="${ENV_PATH}" -e '
using Pkg
package_path = popfirst!(ARGS)
Pkg.develop(PackageSpec(path = package_path))
Pkg.instantiate()
Pkg.test("WendaoCodeParser"; coverage = false, test_args = ARGS)
' "${ROOT}" "$@"
