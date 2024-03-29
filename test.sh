#!/bin/bash

set -e

function run_tests {
  export BUNDLE_GEMFILE=$1

  cat <<-TESTMSG

#####################################
#
# Running tests with $BUNDLE_GEMFILE
#
#####################################

TESTMSG

  bundle install
  bundle exec rake
}

run_tests "ci/Gemfile"

run_tests "ci/Gemfile.activesupport"

run_tests "ci/Gemfile.faraday-1-0"

if ruby -e "exit 1 if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')"; then
  run_tests "ci/Gemfile.faraday-0-17"
else
  cat <<-SKIP
############################################
#
# Skipping old faraday tests on ruby >= 3.0
#
############################################
SKIP
fi

