#!/bin/bash

# Copyright (c) 2015, Isaac I. Y. Saito
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

ici_enforce_deprecated BEFORE_SCRIPT "Please migrate to new hook system."
ici_enforce_deprecated NOT_TEST_INSTALL "testing installed test files has been removed."
ici_enforce_deprecated CATKIN_CONFIG "Explicit catkin configuration is not available anymore."

for v in BUILD_PKGS_WHITELIST PKGS_DOWNSTREAM TARGET_PKGS USE_MOCKUP; do
    ici_enforce_deprecated "$v" "Please migrate to new workspace definition"
done

for v in CATKIN_PARALLEL_JOBS CATKIN_PARALLEL_TEST_JOBS ROS_PARALLEL_JOBS ROS_PARALLEL_TEST_JOBS; do
    ici_mark_deprecated "$v" "Job control is not available anymore"
done

ici_mark_deprecated ROSINSTALL_FILENAME "Please migrate to new UPSTREAM_WORKSPACE format"
ici_mark_deprecated UBUNTU_OS_CODE_NAME "Was renamed to OS_CODE_NAME."

# variables in docker.env without default will be exported with empty string
# this might break the build, e.g. for Makefile which rely on these variables
if [ -z "${CC}" ]; then unset CC; fi
if [ -z "${CFLAGS}" ]; then unset CFLAGS; fi
if [ -z "${CPPFLAGS}" ]; then unset CPPFLAGS; fi
if [ -z "${CXX}" ]; then unset CXX; fi
if [ -z "${CXXFLAGS}" ]; then unset CXXLAGS; fi

function  ros1_defaults {
    DEFAULT_OS_CODE_NAME=$1
    ROS1_DISTRO=${ROS1_DISTRO:-$ROS_DISTRO}
    ROS1_REPOSITORY_PATH=${ROS1_REPOSITORY_PATH:-$ROS_REPOSITORY_PATH}
    ROS1_REPO=${ROS1_REPO:-${ROS_REPO:-ros}}
    BUILDER=${BUILDER:-catkin_tools}
}
function  ros2_defaults {
    DEFAULT_OS_CODE_NAME=$1
    ROS2_DISTRO=${ROS2_DISTRO:-$ROS_DISTRO}
    ROS2_REPOSITORY_PATH=${ROS2_REPOSITORY_PATH:-$ROS_REPOSITORY_PATH}
    ROS2_REPO=${ROS2_REPO:-${ROS_REPO:-ros2}}
    BUILDER=${BUILDER:-colcon}
}

function set_ros_variables {
    case "$ROS_DISTRO" in
    "indigo"|"jade")
        ros1_defaults "trusty"
        DEFAULT_DOCKER_IMAGE=""
        ;;
    "kinetic"|"lunar")
        ros1_defaults "xenial"
        ;;
    "melodic")
        ros1_defaults "bionic"
        ;;
    "ardent")
        ros2_defaults "xenial"
        ;;
    "bouncy"|"crystal")
        ros2_defaults "bionic"
        ;;
    esac

    if [ ! "$ROS1_REPOSITORY_PATH" ]; then
        case "${ROS1_REPO}" in
        "building")
            ROS1_REPOSITORY_PATH="http://repositories.ros.org/ubuntu/building/"
            DEFAULT_DOCKER_IMAGE=""
            ;;
        "ros"|"main")
            ROS1_REPOSITORY_PATH="http://packages.ros.org/ros/ubuntu"
            ;;
        "ros-shadow-fixed"|"testing")
            ROS1_REPOSITORY_PATH="http://packages.ros.org/ros-shadow-fixed/ubuntu"
            DEFAULT_DOCKER_IMAGE=""
            ;;
        *)
            if [ -n "$ROS1_DISTRO" ]; then
                error "ROS1 repo '$ROS1_REPO' is not supported"
            fi
            ;;
        esac
    fi

    if [ ! "$ROS2_REPOSITORY_PATH" ]; then
        case "${ROS2_REPO}" in
        "ros2"|"main")
            ROS2_REPOSITORY_PATH="http://packages.ros.org/ros2/ubuntu"
            ;;
        "ros2-testing"|"testing")
            ROS2_REPOSITORY_PATH="http://packages.ros.org/ros2-testing/ubuntu"
            DEFAULT_DOCKER_IMAGE=""
            ;;
        *)
            if [ -n "$ROS2_DISTRO" ]; then
                error "ROS2 repo '$ROS2_REPO' is not supported"
            fi
            ;;
        esac
    fi

}

# If not specified, use ROS Shadow repository http://wiki.ros.org/ShadowRepository
export OS_CODE_NAME
export OS_NAME
export DOCKER_BASE_IMAGE
export ROS_DISTRO

# exit with error if OS_NAME is set, but OS_CODE_NAME is not.
# assume ubuntu as default
if [ -z "$OS_NAME" ]; then
    OS_NAME=ubuntu
elif [ -z "$OS_CODE_NAME" ]; then
    error "please specify OS_CODE_NAME"
fi

if [ -n "$UBUNTU_OS_CODE_NAME" ]; then # for backward-compatibility
    OS_CODE_NAME=$UBUNTU_OS_CODE_NAME
fi

if [ -z "$OS_CODE_NAME" ]; then
    case "$ROS_DISTRO" in
    "")
        if [ -n "$DOCKER_IMAGE" ] || [ -n "$DOCKER_BASE_IMAGE" ]; then
          # try to reed ROS_DISTRO from (base) image
          ici_docker_try_pull "${DOCKER_IMAGE:-$DOCKER_BASE_IMAGE}"
          ROS_DISTRO=$(docker image inspect --format "{{.Config.Env}}" "${DOCKER_IMAGE:-$DOCKER_BASE_IMAGE}" | grep -o -P "(?<=ROS_DISTRO=)[a-z]*") || true
        fi
        if [ -z "$ROS_DISTRO" ]; then
            error "Please specify ROS_DISTRO"
        fi
        set_ros_variables
        ;;
    *)
        set_ros_variables
        if [ -z "$DEFAULT_OS_CODE_NAME" ]; then
            error "ROS distro '$ROS_DISTRO' is not supported"
        fi
        OS_CODE_NAME=$DEFAULT_OS_CODE_NAME
        DEFAULT_DOCKER_IMAGE=${DEFAULT_DOCKER_IMAGE-ros:${ROS_DISTRO}-ros-core}
        ;;
    esac
else
    set_ros_variables
fi

if [ -z "$DOCKER_BASE_IMAGE" ]; then
    DOCKER_BASE_IMAGE="$OS_NAME:$OS_CODE_NAME" # scheme works for all supported OS images
else
    DEFAULT_DOCKER_IMAGE=""
fi


export TERM=${TERM:-dumb}

# legacy support for UPSTREAM_WORKSPACE and USE_DEB
if [ "$UPSTREAM_WORKSPACE" = "debian" ]; then
  ici_warn "Setting 'UPSTREAM_WORKSPACE=debian' is superfluous and gets removed"
  unset UPSTREAM_WORKSPACE
fi

if [ "$USE_DEB" = true ]; then
  if [ "${UPSTREAM_WORKSPACE:-debian}" != "debian" ]; then
    error "USE_DEB and UPSTREAM_WORKSPACE are in conflict"
  fi
  ici_warn "Setting 'USE_DEB=true' is superfluous"
fi

if [ "$UPSTREAM_WORKSPACE" = "file" ] || [ "${USE_DEB:-true}" != true ]; then
  ROSINSTALL_FILENAME="${ROSINSTALL_FILENAME:-.travis.rosinstall}"
  if [ -f  "$TARGET_REPO_PATH/$ROSINSTALL_FILENAME.$ROS_DISTRO" ]; then
    ROSINSTALL_FILENAME="$ROSINSTALL_FILENAME.$ROS_DISTRO"
  fi

  if [ "${USE_DEB:-true}" != true ]; then # means UPSTREAM_WORKSPACE=file
      if [ "${UPSTREAM_WORKSPACE:-file}" != "file" ]; then
        error "USE_DEB and UPSTREAM_WORKSPACE are in conflict"
      fi
      ici_warn "Replacing 'USE_DEB=false' with 'UPSTREAM_WORKSPACE=$ROSINSTALL_FILENAME'"
  else
      ici_warn "Replacing 'UPSTREAM_WORKSPACE=file' with 'UPSTREAM_WORKSPACE=$ROSINSTALL_FILENAME'"
  fi
  UPSTREAM_WORKSPACE="$ROSINSTALL_FILENAME"
fi
