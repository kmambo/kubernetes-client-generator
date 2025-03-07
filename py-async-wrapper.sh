#!/usr/local/bin/bash
set -euo pipefail

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo "DIR=$DIR"

PARENT=$(dirname "$DIR")
echo "PARENT=$PARENT"

DST="${PARENT}/python-async-client"
echo "DST=$DST"

SRC="${DIR}/python-async-client"
echo "SRC=$SRC"

build_package() {
    pushd $DST
    poetry build
    popd
}

gitops() {
    local tag=$1
    pushd $DST
    git add -A
    git commit -m "commiting version $tag"
    git tag $tag
    popd
}

set_py_settings() {
    local tag=$1
    pushd $DIR

    cat > python-settings.sh << EOF
export KUBERNETES_BRANCH="master" 
export PACKAGE_NAME="client"
export OPENAPI_GENERATOR_COMMIT=v7.11.0
export CLIENT_VERSION="${tag:1}" 
EOF

    popd
}

pyproject() {
    local tag=$1
    local version="${tag:1}"
    pushd $DST
    cat > pyproject.toml << EOF
[project]
name = "client"
version = "$version"
description = "Kubernetes"
requires-python = "^3.12"
authors = [
    {name = "Partho Bhowmick",email = "p.s.bhowmick@gmail.com"}
]
license = "NoLicense"
readme = "README.md"
repository = "https://github.com/kubernetes-client/python"
keywords = ["OpenAPI", "OpenAPI-Generator", "Kubernetes"]
requires = [
]

[tool.poetry]
packages = [{include = "client", to="kubernetes.client"}]

[tool.poetry.group.dev.dependencies]
pytest = ">= 7.2.1"
pytest-cov = ">= 2.8.1"
tox = ">= 3.9.0"
flake8 = ">= 4.0.0"
types-python-dateutil = ">= 2.8.19.14"
mypy = ">= 1.5"

[build-system]
requires = ["setuptools"]
build-backend = "setuptools.build_meta"

[tool.pylint.'MESSAGES CONTROL']
extension-pkg-whitelist = "pydantic"

[tool.mypy]
files = [
  "client",
  #"test",  # auto-generated tests
  "tests", # hand-written tests
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

EOF
poetry add "urllib3 (>=1.25.3,<3.0.0)" \
    "python-dateutil (>=2.8.2)" \
    "aiohttp (>=3.8.4)" \
    "aiohttp-retry (>= 2.8.3)" \
    "pydantic (>=2,<3)" \
    "typing-extensions (>=4.7.1)"
poetry lock
    popd
}
set -x
if [ ! -d "$DST" ]; then
    mkdir -p "$DST"
fi
if [ ! -d "$DST/.git" ]; then
    pushd "$DST"
    git init
    popd
fi
set +x

tags=( v32.0.1 v31.0.0 v30.1.0 v29.1.0 )
for tag in ${tags[@]}; do
  echo $tag
  set_py_settings $tag
  
  pushd $DIR
  
  ./openapi/python-asyncio.sh python-async-client python-settings.sh

  if [ -d "$DST/client" ]; then
    rm -rf "$DST/client"
  fi

  if [ -d "$DST/docs" ]; then
    rm -rf "$DST/docs"
  fi

  if [ -d "$DST/test" ]; then
    rm -rf "$DST/test"
  fi

  rm -f $SRC/swagger.json
  rm -f $SRC/swagger.json.unprocessed
  if [ ! -d "$SRC/.git" ]; then
      rm -rf "$SRC/.git"
  fi
  cp -rf $SRC/* $DST/
  cp -rf $SRC/.* $DST/
  pyproject $tag
  gitops $tag
  build_package
  popd
done

