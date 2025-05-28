#!/usr/local/bin/bash
set -euxo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SPEC_DIR=/Users/partho/oss/kubernetes/api/openapi-spec/v3
SPEC_COPY_DIR=${SCRIPT_DIR}/spec
OUTDIR=$SCRIPT_DIR/output

pushd $SCRIPT_DIR
trap "popd" SIGINT SIGTERM SIGHUP SIGQUIT SIGABRT
mkdir -p $SPEC_COPY_DIR
rm -f $SPEC_COPY_DIR/*
rm -f $SPEC_COPY_DIR/.*
cp $SPEC_DIR/*.json $SPEC_COPY_DIR
cp $SPEC_DIR/.*.json $SPEC_COPY_DIR


openapi-generator-cli generate -g python --library asyncio --package-name client  --input-spec-root-directory $SPEC_COPY_DIR -o $OUTDIR
# shopt -s extglob
# for file in $HOME/oss/kubernetes/api/openapi-spec/v3/*(*.json|.*.json)
# do
#   echo $file
# done

