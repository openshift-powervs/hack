# How to run the cleanup script

```shell
$ IBMCLOUD_API_KEY=<API_KEY> INFRA_ID=<INFRA_ID>  CLUSTER_NAME=<CLUSTER_NAME> ./cleanup.sh
```

> Note: INFRA_ID can be found in the <installation_dir>/metadata.json file with key name infraID

example:

```shell
$ IBMCLOUD_API_KEY=1234 INFRA_ID=mkumatag-ocp-2j7c6 CLUSTER_NAME=mkumatag-ocp ./cleanup.sh
```
