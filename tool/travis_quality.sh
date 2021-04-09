#!/usr/bin/env bash

set -e

git diff --exit-code
dartanalyzer --fatal-warnings .
dartfmt --dry-run --set-exit-if-changed .
