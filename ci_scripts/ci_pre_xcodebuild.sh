#!/bin/sh
# Xcode Cloud runs this before every xcodebuild action.
# Board M0-03: a failing CoachCore test must stop the build, so nothing reaches
# TestFlight. Running the package tests before the archive makes that hold
# whatever actions the Xcode Cloud workflow has.
set -eu

echo "HealthCoach build ${CI_BUILD_NUMBER:-local} · action ${CI_XCODEBUILD_ACTION:-unknown} · commit ${CI_COMMIT:-unknown}"

if [ "${CI_XCODEBUILD_ACTION:-}" = "archive" ]; then
    cd "${CI_PRIMARY_REPOSITORY_PATH:-$(dirname "$0")/..}/CoachCore"
    echo "Running CoachCore tests before archive"
    swift test
fi
