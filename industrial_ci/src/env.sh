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

for v in BUILD_PKGS_WHITELIST PKGS_DOWNSTREAM TARGET_PKGS USE_MOCKUP; do
    ici_enforce_deprecated "$v" "Please migrate to new workspace definition"
done

for v in CATKIN_PARALLEL_JOBS CATKIN_PARALLEL_TEST_JOBS ROS_PARALLEL_JOBS ROS_PARALLEL_TEST_JOBS; do
    ici_mark_deprecated "$v" "Job control is not available anymore"
done

ici_mark_deprecated UBUNTU_OS_CODE_NAME "Was renamed to OS_CODE_NAME."
if [ ! "$APTKEY_STORE_HTTPS" ]; then export APTKEY_STORE_HTTPS="https://raw.githubusercontent.com/ros/rosdistro/master/ros.key"; fi
if [ ! "$APTKEY_STORE_SKS" ]; then export APTKEY_STORE_SKS="hkp://ha.pool.sks-keyservers.net"; fi  # Export a variable for SKS URL for break-testing purpose.
if [ ! "$HASHKEY_SKS" ]; then export HASHKEY_SKS="0xB01FA116"; fi

# variables in docker.env without default will be exported with empty string
# this might break the build, e.g. for Makefile which rely on these variables
if [ -z "${CC}" ]; then unset CC; fi
if [ -z "${CFLAGS}" ]; then unset CFLAGS; fi
if [ -z "${CPPFLAGS}" ]; then unset CPPFLAGS; fi
if [ -z "${CXX}" ]; then unset CXX; fi
if [ -z "${CXXFLAGS}" ]; then unset CXXLAGS; fi

# If not specified, use ROS Shadow repository http://wiki.ros.org/ShadowRepository
if [ ! "$ROS_REPOSITORY_PATH" ]; then
    case "${ROS_REPO:-ros-shadow-fixed}" in
    "building")
        ROS_REPOSITORY_PATH="http://repositories.ros.org/ubuntu/building/"
        ;;
    "ros"|"main")
        ROS_REPOSITORY_PATH="http://packages.ros.org/ros/ubuntu"
        ;;
    "ros-shadow-fixed"|"testing")
        ROS_REPOSITORY_PATH="http://packages.ros.org/ros-shadow-fixed/ubuntu"
        ;;
    *)
        error "ROS repo '$ROS_REPO' is not supported"
        ;;
    esac
fi

export OS_CODE_NAME
export OS_NAME
export DOCKER_BASE_IMAGE

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
    "indigo"|"jade")
        OS_CODE_NAME="trusty"
        ;;
    "kinetic"|"lunar")
        OS_CODE_NAME="xenial"
        ;;
    "melodic")
        OS_CODE_NAME="bionic"
        ;;
    "")
        if [ -n "$DOCKER_IMAGE" ] || [ -n "$DOCKER_BASE_IMAGE" ]; then
          # try to reed ROS_DISTRO from imgae
          if [ "$DOCKER_PULL" != false ]; then
            docker pull "${DOCKER_IMAGE:-$DOCKER_BASE_IMAGE}"
          fi
          export ROS_DISTRO=$(docker image inspect --format "{{.Config.Env}}" "${DOCKER_IMAGE:-$DOCKER_BASE_IMAGE}" | grep -o -P "(?<=ROS_DISTRO=)[a-z]*")
        fi
        if [ -z "$ROS_DISTRO" ]; then
            error "Please specify ROS_DISTRO"
        fi
        ;;
    *)
        error "ROS distro '$ROS_DISTRO' is not supported"
        ;;
    esac
fi

if [ -z "$DOCKER_BASE_IMAGE" ]; then
    DOCKER_BASE_IMAGE="$OS_NAME:$OS_CODE_NAME" # scheme works for all supported OS images
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
