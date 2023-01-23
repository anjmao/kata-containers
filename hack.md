###  Build rootfs and image

```sh
#!/bin/bash

set -ex

pushd ./tools/osbuilder
sudo make DEBUG=true USE_DOCKER=true DISTRO=ubuntu EXTRA_PKGS="bash coreutils curl" rootfs image
popd
```


###  Prepare eks cluster.

```sh
eksctl create cluster am-kata-eks --region=us-east-2 -N 1 --ssh-access
eksctl utils write-kubeconfig -c=am-kata-eks --region=us-east-2
eksctl create iamserviceaccount \
--name ebs-csi-controller-sa \
--region=us-east-2 \
--namespace kube-system \
--cluster am-kata-eks \
--attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
--approve \
--role-only \
--role-name AmazonEKS_EBS_CSI_DriverRole

eksctl create addon --name aws-ebs-csi-driver --region=us-east-2 --cluster am-kata-eks --service-account-role-arn arn:aws:iam::<account-id>:role/AmazonEKS_EBS_CSI_DriverRole --force
```

###  Add spot metal node via CAST AI API. 
Note: make sure to change default node configuration container runtime to containerd.

```sh
export CLUSTER_ID="your-cluster"
export API_KEY="your-key"
curl -X POST "https://api.cast.ai/v1/kubernetes/external-clusters/${CLUSTER_ID}/nodes" \
 -H  "accept: application/json" -H  "X-API-Key: ${API_KEY}" -H  "Content-Type: application/json" \
 -d "{\"instanceType\":\"m5zn.metal\",\"spotConfig\":{\"isSpot\":true}}"
```

###  Build custom docker image

```sh
docker build -t ghcr.io/anjmao/kata-containers/kata-deploy:latest . -f ./hack/Dockerfile
docker push ghcr.io/anjmao/kata-containers/kata-deploy:latest
```

###  Deploy kata

```sh
kubectl apply -f ./tools/packaging/kata-deploy/kata-rbac/base/kata-rbac.yaml
kubectl apply -f ./tools/packaging/kata-deploy/kata-deploy/base/kata-deploy-stable.yaml
kubectl apply -f ./tools/packaging/kata-deploy/runtimeclasses/kata-runtimeClasses.yaml
```

###  Deploy demo app

```sh
kubectl apply -f ./tools/packaging/kata-deploy/examples/test-deploy-kata-clh.yaml
```

TODO: Check https://github.com/kata-containers/kata-containers/issues/4412


### Enable debug logs

```sh
sed -i -e 's/^# *\(enable_debug\).*=.*$/\1 = true/g' /opt/kata/share/defaults/kata-containers/configuration-clh.toml
sed -i -e 's/^kernel_params = "\(.*\)"/kernel_params = "\1 agent.log=debug initcall_debug"/g' /opt/kata/share/defaults/kata-containers/configuration-clh.toml
sed -i -e 's/^kernel_params = "\(.*\)"/kernel_params = "\1 agent.debug_console_vport=1026"/g' /opt/kata/share/defaults/kata-containers/configuration-clh.toml
cat <<EOF | tee -a "/etc/containerd/config.toml"
[debug]
level = "debug"
EOF
systemctl restart containerd
```

Access logs:

```sh
journalctl -f -u containerd
```
