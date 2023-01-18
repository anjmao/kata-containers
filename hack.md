Build rootfs and image

```sh
#!/bin/bash

set -ex

export EXTRA_PKGS="bash coreutils"

pushd ./tools/osbuilder
make USE_DOCKER=true DISTRO=ubuntu rootfs
make USE_DOCKER=true image
popd
```

Prepare eks cluster + separate spot metal instance.

```sh
eksctl create cluster am-kata-eks --region=us-east-2 -N 1 --ssh-access
eksctl utils write-kubeconfig -c=am-kata-eks --region=us-east-2
```

Add spot metal node via CAST AI API. 
Note: make sure to change default node configuration container runtime to containerd.

```sh
export CLUSTER_ID="your-cluster"
export API_KEY="your-key"
curl -X POST "https://api.cast.ai/v1/kubernetes/external-clusters/${CLUSTER_ID}/nodes" \
 -H  "accept: application/json" -H  "X-API-Key: ${API_KEY}" -H  "Content-Type: application/json" \
 -d "{\"instanceType\":\"m5zn.metal\",\"spotConfig\":{\"isSpot\":true}}"
```

Build custom docker image

```sh
docker build -t ghcr.io/anjmao/kata-containers/kata-deploy:latest . -f ./hack/Dockerfile
docker push ghcr.io/anjmao/kata-containers/kata-deploy:latest
```

Deploy kata

```sh
kubectl apply -f ./tools/packaging/kata-deploy/kata-rbac/base/kata-rbac.yaml
kubectl apply -f ./tools/packaging/kata-deploy/kata-deploy/base/kata-deploy.yaml
kubectl apply -f ./tools/packaging/kata-deploy/runtimeclasses/kata-runtimeClasses.yaml
```

Deploy demo app

```sh
kubectl apply -f ./tools/packaging/kata-deploy/examples/test-deploy-kata-clh.yaml
```
