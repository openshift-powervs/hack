
## PowerVS IPI - Doc

> Note: The intention for this doc is to address instructions to install, todos, issues, anything we want to maintain as a running doc

### How to trigger ipi installer:

- Git clone and build the code
  ```shell
  $ git clone https://github.com/openshift-powervs/installer.git
  $ go mod vendor
  $ ./hack/build.sh
  ```
- Set the environment variables
  ```shell
  export IBMID="mkumatag@in.ibm.com"
  export IBMID_PASSWORD=<API_KEY>
  export IBMCLOUD_REGION="lon"
  export IBMCLOUD_ZONE="lon04"
  ```
- Install config file
```yaml
apiVersion: v1
baseDomain: scnl-ibm.com
compute:
- architecture: ppc64le
  hyperthreading: Enabled
  name: worker
  platform: {}
  replicas: 2
controlPlane:
  architecture: ppc64le
  hyperthreading: Enabled
  name: master
  platform: {}
  replicas: 3
metadata:
  name: <NAME OF THE CLUSTER>
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.0.0/16
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  powervs:
    clusterOSImage: "https://art-rhcos-ci.s3.amazonaws.com/releases/rhcos-4.7-ppc64le/47.83.202102081610-0/ppc64le/rhcos-47.83.202102081610-0-metal.ppc64le.raw.gz"
    region: eu-gb
    #until GetSession() is updated: export IBMCLOUD_REGION=eu-gb
    zone: lon04
    #until GetSession() is updated: export IBMCLOUD_ZONE=lon04
    #userid:
    #apikey: "set IBMCLOUD_PASSWORD instead"
publish: External
pullSecret: <PULL_SECRET FROM openshift.com sit>
sshKey: <SSH PUBLIC KEY>
```
  
- Trigger the installer
  ```shell
  ./bin/openshift-install create cluster --dir ocp-test
  ```

### Workarounds:
