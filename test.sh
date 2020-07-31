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

run_tests "ci/Gemfile.oldfaraday"

