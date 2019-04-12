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
# limitations under the License.
#

function ici_resolve_scheme {
    local url=$1; shift
    if [[ $url =~ ([^:]+):([^#@]+)[#@](.+) ]]; then
        local fragment="${BASH_REMATCH[3]}"
        local repo=${BASH_REMATCH[2]}
        local name=${repo##*/}
        local scheme=${BASH_REMATCH[1]}

        case "$scheme" in
            bitbucket | bb)
                echo "$name" "git" "https://bitbucket.org/$repo" "$fragment"
                ;;
            github | gh)
                echo "$name" "git" "https://github.com/$repo" "$fragment"
                ;;
            gitlab | gl)
                echo "$name" "git" "https://gitlab.com/$repo" "$fragment"
                ;;
            git+*)
                echo "$name" "git" "$scheme:$repo" "$fragment"
                ;;
            *)
                echo "$name" "$scheme" "$scheme:$repo" "$fragment"
                ;;
        esac
    else
        ici_error "could not parse URL '$url'"
    fi

}

function ici_install_pkgs_for_command {
  local command=$1; shift
  if ! which "$command" > /dev/null; then
      apt-get -qq install --no-install-recommends -y "$@"
  fi
}

function ici_import_repository {
    local sourcespace=$1; shift
    local url=$1; shift

    ici_install_pkgs_for_command vcs python-vcstool

    local -a parts
    parts=($(ici_resolve_scheme "$url"))
    case "${parts[1]}" in
        git)
          ici_install_pkgs_for_command git git-core
            ;;
        *)
            ;;
    esac
    vcs import "$sourcespace" <<< "{repositories: {'${parts[0]}': {type: '${parts[1]}', url: '${parts[2]}', version: '${parts[3]}'}}}"
}

function ici_import_file {
    local sourcespace=$1; shift
    local file=$1; shift

    ici_install_pkgs_for_command vcs python-vcstool
    vcs import "$sourcespace" < "$file"
}

function ici_import_url {
    local sourcespace=$1; shift
    local url=$1; shift

    ici_install_pkgs_for_command vcs python-vcstool
    ici_install_pkgs_for_command wget wget

    set -o pipefail
    wget -O- -q "$url" | vcs import "$sourcespace"
    set +o pipefail
}

function ici_prepare_sourcespace {
    local sourcespace="$1"; shift

    mkdir -p "$sourcespace"

    for source in "$@"; do
        case "$source" in
        git* | bitbucket:* | bb:* | gh:* | gl:*)
            ici_import_repository "$sourcespace" "$source"
            ;;
        http://* | https://*) # When UPSTREAM_WORKSPACE is an http url, use it directly
            ici_import_url "$sourcespace" "$source"
            ;;
        -*)
            echo "Removing ''${sourcespace:?}/${source:1}'"
            rm -rf "${sourcespace:?}/${source:1}"
            ;;
        /*)
            if [ -d "$source" ]; then
                cp -a "$source" "$sourcespace"
            else
                ici_error "'$source' is not a directory"
            fi
            ;;
        "")
            ici_error "source is empty string"
            ;;
        *)
            if [ -d "$TARGET_REPO_PATH/$source" ]; then
                cp -av "$TARGET_REPO_PATH/$source" "$sourcespace"
            elif [ -f "$TARGET_REPO_PATH/$source" ]; then
                ici_import_file "$sourcespace" "$TARGET_REPO_PATH/$source"
            else
                ici_error "cannot read source from '$source'"
            fi
            ;;
        esac
    done
}

function ici_setup_rosdep {
    ici_install_pkgs_for_command rosdep python-rosdep
    # Setup rosdep
    rosdep --version
    if ! [ -d /etc/ros/rosdep/sources.list.d ]; then
        sudo rosdep init
    fi

    update_opts=()
    case "$ROS_DISTRO" in
    "jade")
        if rosdep update --help | grep -q -- --include-eol-distros; then
          update_opts+=(--include-eol-distros)
        fi
        ;;
    esac

    ici_retry 2 rosdep update "${update_opts[@]}"
}

function ici_exec_in_workspace {
    local extend=$1; shift
    local path=$1; shift
    # shellcheck disable=SC1090
    ( { [ ! -e "$extend/setup.bash" ] || source "$extend/setup.bash"; } && cd "$path" && exec "$@")
}

function install_dependencies {
    local extend=$1; shift
    local skip_keys=$1; shift
    rosdep_opts=(-q --from-paths "$@" --ignore-src -y)
    if [ -n "$skip_keys" ]; then
      rosdep_opts+=(--skip-keys "$skip_keys")
    fi
    set -o pipefail # fail if rosdep install fails
    ici_exec_in_workspace "$extend" "." rosdep install "${rosdep_opts[@]}" | { grep "executing command" || true; }
    set +o pipefail
}

function ici_build_workspace {
    local name=$1; shift
    local extend=$1; shift
    local ws=$1; shift

    local ws_env="${name^^}_WORKSPACE"
    local sources=("$@" ${!ws_env})
    ici_run "setup_${name}_workspace" ici_prepare_sourcespace "$ws/src" "${sources[@]}"
    ici_run "install_${name}_dependencies" install_dependencies "$extend" "$ROSDEP_SKIP_KEYS" "$ws/src"
    ici_run "build_${name}_workspace" builder_run_build "$extend" "$ws"
}

function ici_test_workspace {
    local name=$1; shift
    local extend=$1; shift
    local ws=$1; shift

    ici_run "run_${name}_test" builder_run_tests "$extend" "$ws"
    builder_test_results "$extend" "$ws"
}
