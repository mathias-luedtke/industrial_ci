#!/bin/bash

# Copyright (c) 2015, Isaac I. Y. Saito
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Greatly inspired by JSK travis https://github.com/jsk-ros-pkg/jsk_travis

## This is a "common" script that can be run on travis CI at a downstream github repository.
## See ./README.rst for the detailed usage.

set -e # exit script on errors
if [ "$DEBUG_BASH" ]; then set -x; fi # print trace if DEBUG

# Define some env vars that need to come earlier than util.sh
export ICI_SRC_PATH; ICI_SRC_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"  # The path on CI service (e.g. Travis CI) to industrial_ci src dir.

# shellcheck source=industrial_ci/src/util.sh
source "${ICI_SRC_PATH}/util.sh"
# shellcheck source=industrial_ci/src/docker.sh
source "${ICI_SRC_PATH}/docker.sh"
# shellcheck source=industrial_ci/src/deprecated.sh
source "${ICI_SRC_PATH}/deprecated.sh"
# shellcheck source=industrial_ci/src/config.sh
source "${ICI_SRC_PATH}/config.sh"

trap ici_exit EXIT # install industrial_ci exit handler

# Start prerelease, and once it finishs then finish this script too.
if [ "$PRERELEASE" == true ]; then
  TEST=ros_prerelease
elif [ -n "$ABICHECK_URL" ]; then
  TEST=abi_check
elif [ -n "$CLANG_FORMAT_CHECK" ]; then
  TEST=clang_format_check
elif [ "$BLACK_CHECK" = true ]; then
  TEST=black_check
elif [ -z "$TEST" ]; then
  TEST=source_tests
fi

echo "Running test '$TEST'"
ici_run_test "$TEST"
