###  Build rootfs and image

```sh
#!/bin/bash

set -ex

pushd ./tools/osbuilder
sudo make DEBUG=true USE_DOCKER=true DISTRO=ubuntu EXTRA_PKGS="bash coreutils curl vim" rootfs image
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

### List pci devices

```
yum install pciutils
lspci
```


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

```
# Kata container volume fs
dd if=/dev/zero of=/var/www/html/out bs=10k count=100k
1048576000 bytes (1.0 GB, 1000 MiB) copied, 4.05981 s, 258 MB/s


# Native container volume fs
dd if=/dev/zero of=/var/www/html/out bs=10k count=100k
1048576000 bytes (1.0 GB, 1000 MiB) copied, 0.51914 s, 2.0 GB/s


# Native container Block volume with manual mount inside container
dd if=/dev/zero of=/var/www/html/out bs=10k count=100k
1048576000 bytes (1.0 GB, 1000 MiB) copied, 0.53927 s, 1.9 GB/s

# Kata containers block volume with manual mount inside container
dd if=/dev/zero of=/var/www/html/out bs=10k count=100k
1048576000 bytes (1.0 GB, 1000 MiB) copied, 0.646092 s, 1.6 GB/s
```

### Get vm device info
```
curl --unix-socket //run/vc/vm/<id>/clh-api.sock -X GET 'http://localhost/api/v1/vm.info' -H 'Accept: application/json' | jq
```

### Create filesystem for block volume

```
mkfs.ext4 /dev/block
mkdir -p /var/www/html
mount /dev/block /var/www/html
```


### vCPU calc

```
lscpu
Architecture:        x86_64
CPU op-mode(s):      32-bit, 64-bit
Byte Order:          Little Endian
CPU(s):              48
On-line CPU(s) list: 0-47
Thread(s) per core:  2
Core(s) per socket:  12
Socket(s):           2
NUMA node(s):        2
Vendor ID:           GenuineIntel
CPU family:          6
Model:               85
Model name:          Intel(R) Xeon(R) Platinum 8252C CPU @ 3.80GHz
Stepping:            7
CPU MHz:             4493.350
CPU max MHz:         4500.0000
CPU min MHz:         1200.0000
BogoMIPS:            7600.00
Virtualization:      VT-x
L1d cache:           32K
L1i cache:           32K
L2 cache:            1024K
L3 cache:            25344K
NUMA node0 CPU(s):   0-11,24-35
NUMA node1 CPU(s):   12-23,36-47


(Threads x Cores) x Physical CPU = Number vCPU
For example, A 8 cores/ 16 threads CPU has (16 Threads x 8 Cores) x 1 CPU = 128 vCPUs

```