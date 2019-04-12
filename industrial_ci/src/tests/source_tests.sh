#!/bin/bash

# Copyright (c) 2015, Isaac I. Y. Saito
# Copyright (c) 2019, Mathias Lüdtke
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
#
## Greatly inspired by JSK travis https://github.com/jsk-ros-pkg/jsk_travis

# source_tests.sh script runs integration tests for the target ROS packages.
# It is dependent on environment variables that need to be exported in advance
# (As of version 0.4.4 most of them are defined in env.sh).

function run_catkin_lint {
    local path=$1; shift
    ici_asroot pip install catkin-lint
    if catkin_lint --explain "$@" "$path"; then
        echo "catkin_lint passed."
    else
        ici_error "catkin_lint failed by either/both errors and/or warnings"
    fi
}

function run_source_tests {
    # shellcheck disable=SC1090
    source "${ICI_SRC_PATH}/builders/$BUILDER.sh" || ici_error "Builder '$BUILDER' not supported"

    ici_require_run_in_docker # this script must be run in docker

    ici_time_start setup_apt
    ici_asroot apt-get update -qq
    # If more DEBs needed during preparation, define ADDITIONAL_DEBS variable where you list the name of DEB(S, delimitted by whitespace)
    if [ "$ADDITIONAL_DEBS" ]; then
        local debs=($ADDITIONAL_DEBS)
        ici_asroot apt-get install -qq -y "${debs[@]}" || ici_error "One or more additional deb installation is failed. Exiting."
    fi
    ici_time_end  # setup_apt

    if [ "$CCACHE_DIR" ]; then
        ici_run "setup_ccache" ici_asroot apt-get install -qq -y ccache
        export PATH="/usr/lib/ccache:$PATH"
    fi

    ici_run "${BUILDER}_setup" ici_quiet builder_setup

    ici_run "setup_rosdep" ici_setup_rosdep

    local upstream_ws=~/upstream_ws
    local target_ws=~/target_ws
    local downstream_ws=~/downstream_ws
    local extend="/opt/ros/$ROS_DISTRO"

    if [ "$CATKIN_LINT" == "true" ] || [ "$CATKIN_LINT" == "pedantic" ]; then
        local catkin_lint_args=($CATKIN_LINT_ARGS)
        if [ "$CATKIN_LINT" == "pedantic" ]; then
        	catkin_lint_args+=(--strict -W2)
        fi
        ici_run "catkin_lint" run_catkin_lint "$TARGET_REPO_PATH" "${catkin_lint_args[@]}"
    fi

    if [ -n "$UPSTREAM_WORKSPACE" ]; then
        ici_build_workspace "upstream" "$extend" "$upstream_ws"
        extend="$upstream_ws/install"
    fi

    ici_build_workspace "target" "$extend" "$target_ws" "$TARGET_REPO_PATH"

    if [ "$NOT_TEST_BUILD" != "true" ]; then
        ici_test_workspace "target" "$extend" "$target_ws"
    fi

    extend="$target_ws/install"
    if [ -n "$DOWNSTREAM_WORKSPACE" ]; then
        ici_build_workspace "downstream" "$extend" "$downstream_ws"
        #extend="$downstream_ws/install"

        if [ "$NOT_TEST_DOWNSTREAM" != "true" ]; then
            ici_test_workspace "downstream" "$extend" "$downstream_ws"
        fi
    fi
}
