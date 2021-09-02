#!/usr/bin/env bash

set -e

git diff --exit-code
dart analyze
dart format --set-exit-if-changed .
