#!/bin/bash

# Copyright 2017 The Kubernetes Authors.
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

# Script to fetch latest swagger spec.
# Puts the updated spec at api/swagger-spec/

set -o errexit
set -o nounset
set -o pipefail

# Generates client.
# Required env vars:
#   CLEANUP_DIRS: List of directories (string separated by space) to cleanup before generation for this language
#   KUBERNETES_BRANCH: Kubernetes branch name to get the swagger spec from
#   CLIENT_VERSION: Client version. Will be used in the comment sections of the generated code
#   PACKAGE_NAME: Name of the client package.
#   OPENAPI_GENERATOR_COMMIT: openapi-generator commit sha or tag/branch name. Will only be used as a reference in docs.
# Input vars:
#   $1: output directory
: "${CLEANUP_DIRS?Must set CLEANUP_DIRS env var}"
: "${KUBERNETES_BRANCH?Must set KUBERNETES_BRANCH env var}"
: "${CLIENT_VERSION?Must set CLIENT_VERSION env var}"
: "${CLIENT_LANGUAGE?Must set CLIENT_LANGUAGE env var}"
: "${PACKAGE_NAME?Must set PACKAGE_NAME env var}"
: "${OPENAPI_GENERATOR_COMMIT?Must set OPENAPI_GENERATOR_COMMIT env var}"

output_dir=$1
pushd "${output_dir}" > /dev/null
output_dir=`pwd`
popd > /dev/null
SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")
pushd "${SCRIPT_ROOT}" > /dev/null
SCRIPT_ROOT=`pwd`
popd > /dev/null

if ! which mvn > /dev/null 2>&1; then
    echo "Maven is not installed."
    exit
fi

# There should be only one version of openapi-generator-maven-plugin.
unset PLUGIN_VERSION
shopt -s nullglob
FOLDERS=(/root/.m2/repository/org/openapitools/openapi-generator-maven-plugin/*)
for folder in "${FOLDERS[@]}"; do
    if [[ -d "${folder}" ]]; then
        folder=$(basename "${folder}")
        if [[ ! -z "${PLUGIN_VERSION:-}" ]]; then
            echo "Multiple openapi-generator-maven-plugin version exists: ${PLUGIN_VERSION} & ${folder}"
            exit 1
        fi
        PLUGIN_VERSION="${folder}"
    fi
done
if [[ -z "${PLUGIN_VERSION:-}" ]]; then
    echo "Cannot find openapi-generator-maven-plugin version"
    exit 1
fi
shopt -u nullglob

# To make sure we can reproduce generation, we would also log code-gen exact commit
pushd /source/openapi-generator
  OPENAPI_GENERATOR_COMMIT_ACTUAL=$(git rev-parse HEAD)
popd

mkdir -p "${output_dir}"

echo "--- Downloading and pre-processing OpenAPI spec"
python3 "${SCRIPT_ROOT}/preprocess_spec.py" "${CLIENT_LANGUAGE}" "${KUBERNETES_BRANCH}" "${output_dir}/swagger.json" "${USERNAME}" "${REPOSITORY}"

echo "--- Cleaning up previously generated folders"
for i in ${CLEANUP_DIRS}; do
    echo "--- Cleaning up ${output_dir}/${i}"
    rm -rf "${output_dir}/${i}"
done

echo "--- Generating client ..."

mvn_args=(
    -Dgenerator.spec.path="${output_dir}/swagger.json"
    -Dgenerator.output.path="${output_dir}"
    -D=generator.client.version="${CLIENT_VERSION}"
    -D=generator.package.name="${PACKAGE_NAME}"
    -D=openapi-generator-version="${PLUGIN_VERSION}"
    -Duser.home=/root
)

if [ -n "${USE_SINGLE_PARAMETER:-}" ]; then
    mvn_args+=("-D=use-single-parameter=${USE_SINGLE_PARAMETER}")
fi

mvn -f "${SCRIPT_ROOT}/generation_params.xml" clean generate-sources "${mvn_args[@]}"

mkdir -p "${output_dir}/.openapi-generator"
echo "Requested Commit/Tag : ${OPENAPI_GENERATOR_COMMIT}" > "${output_dir}/.openapi-generator/COMMIT"
echo "Actual Commit        : ${OPENAPI_GENERATOR_COMMIT_ACTUAL}" >> "${output_dir}/.openapi-generator/COMMIT"

rm -rf "${output_dir}/.git"
echo "---Done."
