#!/bin/bash

# Copyright (c) 2017, Mathias Lüdtke
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

if [ -z "$ABICHECK_URL" ]; then
    error 'please specify ABICHECK_URL'
fi

function install_abi_tracker() {
    sudo apt-get update -qq
    sudo apt-get install -y -qq libelf-dev wdiff rfcdiff elfutils autoconf pkg-config links

    wget -q -O - https://raw.githubusercontent.com/lvc/installer/master/installer.pl | perl - -install -prefix /usr abi-tracker

    git clone https://github.com/universal-ctags/ctags.git /tmp/ctags
    (cd /tmp/ctags && ./autogen.sh && ./configure && make install)

    mkdir -p "/abicheck/db/$TARGET_REPO_NAME/" "/abicheck/src/$TARGET_REPO_NAME"/{current,0.0.0}
    cp -a "$TARGET_REPO_PATH" "/abicheck/src/$TARGET_REPO_NAME/current/src"
}

function run_abi_check() {
    ici_require_run_in_docker # this script must be run in docker

    ici_time_start install_abi_tracker
    install_abi_tracker > /dev/null
    ici_time_end  # install_abi_tracker

    ici_time_start setup_rosdep

    # Setup rosdep
    rosdep --version
    if ! [ -d /etc/ros/rosdep/sources.list.d ]; then
        sudo rosdep init
    fi
    ret_rosdep=1
    rosdep update || while [ $ret_rosdep != 0 ]; do sleep 1; rosdep update && ret_rosdep=0 || echo "rosdep update failed"; done

    ici_time_end  # setup_rosdep

    ici_time_start abi_check

    local target_ext
    target_ext=$(grep -Pio '\.(zip|tar\.\w+|tgz|tbz2)\Z' <<< "$ABICHECK_URL")
    local target_file="src/$TARGET_REPO_NAME/0.0.0/$TARGET_REPO_NAME-0.0.0$target_ext"

    cat <<EOF > /abicheck/repo.json
{
"Name":           "$TARGET_REPO_NAME",
"PreInstall":     "catkin_init_workspace && rosdep install -q --from-paths . --ignore-src -y"
}
EOF

    cat <<EOF > /abicheck/db/$TARGET_REPO_NAME/Monitor.json
\$VAR1 = {
        'Source' => {

                        '0.0.0' => '$target_file',
                        'current' => 'src/$TARGET_REPO_NAME/current'
                    }
        };
EOF

    wget -q -O "/abicheck/$target_file" "$ABICHECK_URL"

    source "/opt/ros/$ROS_DISTRO/setup.bash"
    if ! (cd /abicheck && abi-monitor -build repo.json && abi-tracker -build -t abireport repo.json); then
        ret=$?
        for l in "/abicheck/build_logs/$TARGET_REPO_NAME"/*/*; do
            echo "Log $l:"
            cat "$l"
        done
        ici_exit $ret
    fi
    ici_time_end  # abi_check

    echo
    echo "ABI compliance with $(basename "$ABICHECK_URL" "$target_ext")"
    echo
    links -dump "/abicheck/objects_report/$TARGET_REPO_NAME/0.0.0/current/report.html"
    grep -q '"BC": "100"' "/abicheck/objects_report/$TARGET_REPO_NAME/0.0.0/current/meta.json"
}
