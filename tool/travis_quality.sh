#!/usr/bin/env bash

set -e

git diff --exit-code
dartanalyzer --fatal-warnings .
# The Dart formatter has changed between 2.7.2 and 2.12, resulting in
# false formatting failures. Comment this out for the time being.
#dartfmt --dry-run --set-exit-if-changed ..
