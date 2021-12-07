#!/usr/bin/env bash
set -e

SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")
source "${SCRIPT_ROOT}/lib.sh"

cd "${SCRIPT_ROOT}/../poc"

WASM_MODULE="./target/wasm32-wasi/release/ring-pod-example.wasi.wasm"

mkdir temp || true
mkdir temp/wasm || true
mkdir temp/wasm/cache || true

cp ../deploy/chart/crds/crd.yaml temp/00_crd.yaml
kubectl apply -f ./temp/00_crd.yaml

NR_CONTROLLERS=10

echo "" > temp/01_namespaces.yaml

for (( VARIABLE = 0; VARIABLE < NR_CONTROLLERS; VARIABLE++ ))
do

cat << EOF >> temp/01_namespaces.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: namespace${VARIABLE}
EOF

cat << EOF > temp/wasm/controller${VARIABLE}.yaml
name: controller${VARIABLE}
abi: rust_v1alpha1
envs:
  - ["RUST_LOG", "debug"]
  - ["IN_NAMESPACE", "namespace${VARIABLE}"]
  - ["OUT_NAMESPACE", "namespace$(((VARIABLE+1) % NR_CONTROLLERS))"]
args: []
EOF
cp ${WASM_MODULE} temp/wasm/controller${VARIABLE}.wasm

done

cat << EOF > temp/02_resource.yaml
apiVersion: amurant.io/v1
kind: Resource
metadata:
    name: run001
    namespace: namespace0
spec:
    nonce: 0
EOF

kubectl apply -f ./temp/

cargo run -p controller --release ./temp/wasm/