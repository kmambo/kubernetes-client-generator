#!/usr/local/bin/bash

set -euxo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
KUBERNETES_DIR="${SCRIPT_DIR}/kubernetes"
PYLINT_TEMPLATE_DIR=${SCRIPT_DIR}/pylint-templates
SPEC_DIR=${KUBERNETES_DIR}/api/openapi-spec/v3
DST=${SCRIPT_DIR}/output
SPEC_COPY_DIR=${DST}/spec
PRE_PROCESS_SCRIPT=${SCRIPT_DIR}/openapi/preprocess_spec.py
LIBTYPE=
LIB_NAME=
PKG_NAME=
KUBERNETES_LIB_DIR=

gen_manual_pyproj() {
  # assume already in ${DST}
    local tag=$1
    local version="${tag:1}"
    local description=
    if [[ $LIBTYPE == "urllib3" ]]; then
      description="Synchronous Kubernetes client with Pydantic support"
    elif [[ $LIBTYPE == "httpx" ]]; then
      description="Sync/Async Kubernetes client with Pydantic support"
    else  # assuming asyncio
      description="Asynchronous Kubernetes client with Pydantic support"
    fi

    cat > pyproject.toml << EOF
[project]
name = "$PKG_NAME"
version = "$version"
description = "$description"
requires-python = ">=3.13,<4.0"
authors = [
    {name = "Partho Bhowmick",email = "partho.bhowmick@icloud.com"}
]
license = "MIT"
readme = "README.md"
repository = "https://github.com/kmambo/kubernetes-pydantic-${LIBTYPE}-client"
keywords = ["OpenAPI", "OpenAPI-Generator", "Kubernetes"]
dynamic = [ "dependencies" ]

[tool.poetry]
packages = [{include = "$LIB_NAME", from = "src"}]

[tool.poetry.group.dev.dependencies]
pytest = ">= 7.2.1"
pytest-cov = ">= 2.8.1"
tox = ">= 3.9.0"
types-python-dateutil = ">= 2.8.19.14"
flake8 = ">= 4.0.0"
mypy = ">= 1.7"
black = ">= 24.10.0"
isort = ">= 6.0.1"

[build-system]
requires = ["poetry-core>=2.0.0,<3.0.0"]
build-backend = "poetry.core.masonry.api"

[tool.pylint.'MESSAGES CONTROL']
extension-pkg-whitelist = "pydantic"

[tool.mypy]
files = [
  "src/$LIB_NAME",
  #"test",  # auto-generated tests
  "tests", # hand-written tests
]

[tool.pytest.ini_options]
minversion = "6.0"
addopts = "-ra -q"
testpaths = [
    "tests",
    "integration",
]
# TODO: enable "strict" once all these individual checks are passing
# strict = true

# List from: https://mypy.readthedocs.io/en/stable/existing_code.html#introduce-stricter-options
warn_unused_configs = true
warn_redundant_casts = true
warn_unused_ignores = true

## Getting these passing should be easy
strict_equality = true
extra_checks = true

## Strongly recommend enabling this one as soon as you can
check_untyped_defs = true

## These shouldn't be too much additional work, but may be tricky to
## get passing if you use a lot of untyped libraries
disallow_subclassing_any = true
disallow_untyped_decorators = true
disallow_any_generics = true

### These next few are various gradations of forcing use of type annotations
#disallow_untyped_calls = true
#disallow_incomplete_defs = true
#disallow_untyped_defs = true
#
### This one isn't too hard to get passing, but return on investment is lower
#no_implicit_reexport = true
#
### This one can be tricky to get passing if you use a lot of untyped libraries
#warn_return_any = true

[[tool.mypy.overrides]]
module = [
  "client.configuration",
]
warn_unused_ignores = true
strict_equality = true
extra_checks = true
check_untyped_defs = true
disallow_subclassing_any = true
disallow_untyped_decorators = true
disallow_any_generics = true
disallow_untyped_calls = true
disallow_incomplete_defs = true
disallow_untyped_defs = true
no_implicit_reexport = true
warn_return_any = true

[tool.black]
line-length = 88
target-version = ["py313"]

[tool.isort]
profile = "black"

EOF

}

pyproject() {
  local tag=$1
  local version="${tag:1}"
  pushd $DST

  gen_manual_pyproj $tag
  poetry check && poetry lock

    if [[ $LIBTYPE == "urllib3" ]]; then
      poetry add "urllib3 (>=1.25.3,<3.0.0)" \
          "python-dateutil (>=2.8.2)" \
          "pydantic (>=2,<3)" \
          "typing-extensions (>=4.7.1)" \
          "lazy-imports (>= 1.0.1)" \
          "oauthlib (>=3.3.1,<4.0.0)" \
          "pyyaml(>= 6.0.0,<7.0.0)" \
          "requests_oauthlib(>=2.0.0,<3.0.0)" \
          "kubernetes_validate(>=1.34.0,<2.0.0)"
      poetry add -G dev \
        "pytest  (>= 7.2.1)" \
        "pytest-cov (>= 2.8.1)" \
        "tox (>= 3.9.0)" \
        "types-python-dateutil (>= 2.8.19.14)" \
        "mypy (>= 1.5)" \
        "flake8 (>= 4.0.0)" \
        "isort (>= 6.0.1)" \
        "black (>= 25.1.0)" \
        "pyright (>= 1.1.385)" \
        "autoflake (>= 2.3.1)"
    elif [[ $LIBTYPE == "httpx" ]]; then
      echo ""
      # TODO
    else  # assuming asyncio
      poetry add "urllib3 (>=1.25.3,<3.0.0)" \
          "python-dateutil (>=2.8.2)" \
          "aiohttp (>=3.8.4)" \
          "aiohttp-retry (>=2.8.3)" \
          "pydantic (>=2,<3)" \
          "typing-extensions (>=4.7.1)" \
          "lazy-imports (>= 1.0.1)"
      poetry add -G dev \
        "pytest  (>= 7.2.1)" \
        "pytest-cov (>= 2.8.1)" \
        "tox (>= 3.9.0)" \
        "types-python-dateutil (>= 2.8.19.14)" \
        "mypy (>= 1.5)" \
        "flake8 (>= 4.0.0)" \
        "isort (>= 6.0.1)" \
        "black (>= 25.1.0)" \
        "pyright (>= 1.1.385)" \
        "autoflake (>= 2.3.1)"
    fi

  poetry lock
  poetry update
  popd
}

openapi_validate() {
  local spec_dir=$1
  local validation_dir=${spec_dir}/openapi-v3-spec-validation

  mkdir -p ${validation_dir}
  shopt -s dotglob
  for f in ${SPEC_COPY_DIR}/*.json ;
  do
    filen=$(basename ${f})
    extension="${filen##*.}"
    filename="${filen%.*}"
    echo "Validating ${filen} ..."
    openapi-generator-cli  validate -i $f --recommend &> ${validation_dir}/${filename}
  done
  shopt -u dotglob

}

cp_spec() {
  local tag=$1
  mkdir -p ${SPEC_COPY_DIR}
  pushd ${KUBERNETES_DIR}
  git checkout master && git pull
  trap "popd" SIGINT SIGTERM SIGHUP SIGQUIT SIGABRT
  git checkout $tag
  cp ${SPEC_DIR}/*.json ${SPEC_COPY_DIR}
  cp ${SPEC_DIR}/.*.json ${SPEC_COPY_DIR}
  git switch -
  popd
  trap - SIGINT SIGTERM SIGHUP SIGQUIT SIGABRT
}

transform_spec() {
  local tag=$1
  local version="${tag:1}"
  shopt -s dotglob
  source ${SCRIPT_DIR}/.venv/bin/activate
  for f in ${SPEC_COPY_DIR}/*.json ;
  do
    filen=$(basename ${f})
    echo $filen
    python3 ${PRE_PROCESS_SCRIPT} ${version} ${f} ${f}
  done
  deactivate
  shopt -u dotglob
}

generate_library() {
  local tag=$1
  local version="${tag:1}"

  openapi-generator-cli generate -g python \
    --library $LIBTYPE \
    --skip-validate-spec \
    --minimal-update \
    --package-name $LIB_NAME \
    --additional-properties=projectName=${LIB_NAME},packageVersion=${version}  \
    --language-specific-primitives=intstr.IntOrString \
    --import-mappings=intstr.IntOrString=IntOrStr \
    --input-spec-root-directory ${SPEC_COPY_DIR} -o ${DST}

  mv ${DST}/${LIB_NAME} ${DST}/src/${LIB_NAME}
}

rename_output() {
  # I am on MacOS
  local SED=/usr/local/bin/gsed
  local LIB_PATH="${DST}/src/${LIB_NAME}"
  # fix imports
  find "${LIB_PATH}/api" -type f -name *.py \
    -exec ${SED} -i "s/from ${LIB_NAME}\.api\./from \./g" {} +
  find "${LIB_PATH}/models" -type f -name *.py \
    -exec ${SED} -i "s/from ${LIB_NAME}\.models\./from \./g" {} +
  find "${LIB_PATH}/config" -type f -name *.py \
    -exec ${SED} -i "s/from ${LIB_NAME}\.client\./from ${LIB_NAME}\.api_client\./g" {} +
}

init_dirs() {
  rm -rf ${DST}/* ${DST}/.* || true
  mkdir -p ${DST}/src
  mkdir -p ${SPEC_COPY_DIR}
}

check_py() {
  cp ${PYLINT_TEMPLATE_DIR}/.flake8 ${DST}
  cp ${PYLINT_TEMPLATE_DIR}/mypy.ini ${DST}
  POETRY_VIRTUALENVS_CREATE=true
  POETRY_VIRTUALENVS_IN_PROJECT=true
  pushd ${DST}
    poetry sync --no-root
    poetry run  autoflake \
      --ignore-pass-statements \
      --ignore-pass-after-docstring \
      --remove-all-unused-imports \
      -i -r src/$LIB_NAME
  	poetry run isort src/${LIB_NAME} || true
  	find src/${LIB_NAME} -type f -name '*.py' | xargs poetry run black || true
  	poetry run flake8 src/${LIB_NAME} || true
  	poetry run mypy src/${LIB_NAME} || true
  	poetry run pytest
  popd
}

local_build() {
  pushd ${DST}
  poetry build
  popd
}

gitops() {
    local tag=$1
    local feature_branch=branch/$tag
    pushd "${KUBERNETES_LIB_DIR}"
    git checkout develop && git pull
    git checkout -b $feature_branch || git checkout $feature_branch
    rm -rf *
    cp -rf ${DST}/* .
    git status
    git add -A
    git commit -m "commiting version $tag"
    git checkout develop
    git merge $feature_branch
    git tag -d $tag || true
    git push --delete origin $tag || true
    git tag $tag
    git push
    git push --tags
    popd
}

cp_config() {
  mkdir -p ${DST}/src/${LIB_NAME}/config
  cp -R ${SCRIPT_DIR}/base/$1/ ${DST}/src/${LIB_NAME}
}

if [ $# -lt 3 ]; then
  echo "Usage: $(basename "$0") <KUBERNETES_API_VERSION> <CLIENT_VERSION> <LIBTYPE>"
  exit
fi

set +e
python3 -c "import sys;kube_tag=sys.argv[1][1:].split('.');client_tag=sys.argv[2][1:].split('.');sys.exit(0 if kube_tag[1:] == client_tag[:-1] and sys.argv[3] in ['urllib3','asyncio', 'httpx'] else 1)" $1 $2 $3
VALID_ARGS=$?
if [[ $VALID_ARGS -ne 0 ]]; then
  echo "The client's major and minor version must match the Kubernetes minor and patch versions respectively."
fi
set -e

LIBTYPE=$3
PKG_NAME=kubernetes-client-${LIBTYPE}-pydantic
LIB_NAME=kubernetes
# LIB_NAME="${PKG_NAME//-/_}"
KUBERNETES_LIB_DIR=$( cd -- "$( dirname -- "${SCRIPT_DIR}" )" &> /dev/null && pwd )/"${PKG_NAME}"

init_dirs
cp_spec $1
transform_spec $1
# openapi_validate ${SPEC_COPY_DIR}
generate_library $2 $3
cp_config $LIBTYPE
pyproject $2 $3
rename_output
check_py
local_build
#gitops "$2"
