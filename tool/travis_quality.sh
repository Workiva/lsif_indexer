#!/usr/bin/env bash

set -e

git diff --exit-code
dartanalyzer --fatal-warnings .
