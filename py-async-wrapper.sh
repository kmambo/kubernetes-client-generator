#!/usr/local/bin/bash
set -euo pipefail

DIR=$(dirname "$0")
echo "DIR=$DIR"

PARENT=$(dirname "$DIR")
echo "PARENT=$PARENT"

DST="${PARENT}/python-async-client"
echo "DST=$DST"

SRC="${DIR}/python-async-client"
echo "SRC=$SRC"

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

if [ ! -d "$DST"]; then
    mkdir -p "$DST"
fi

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

  cp -rf $SRC/* $DST/*
  cp -rf $SRC/.* $DST/.*

  gitops $tag
  popd
done
