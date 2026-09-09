#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d "${TMPDIR:-/tmp}/screenspan-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT
swiftc -module-cache-path "$work/modules" Shared/SharedConstants.swift Shared/ProjectionModel.swift Shared/ProjectionCalculator.swift Shared/ActivitySummary.swift Tests/CalculationTests.swift -o "$work/calculation-tests"
"$work/calculation-tests"
