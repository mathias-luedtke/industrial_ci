#!/bin/bash

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
# limitations uder the License.
function  ici_start_fold() {
    shift 3
    echo -en "##[group]"
}

function  ici_end_fold() {
    shift 4
    echo -e "##[endgroup]"
}

function ici_report_result() {
    echo "$1=$2"
    echo "GHO ${GITHUB_OUTPUT-}  ${GITHUB_ENV-}"
    if [ -n "${GITHUB_OUTPUT-}" ]; then
        echo "$1=$2" | tee -a "$GITHUB_OUTPUT"
    fi
}
