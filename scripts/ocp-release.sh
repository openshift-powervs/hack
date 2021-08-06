#!/bin/bash

# This script expects pull_secret.json and pcloud_bot_key.json to be present in the home dir
# pull_secret.json is the ocp pull secret used during the installation
# pcloud_bot_key.json is the docker credential in json format for pushing images to quay.io/powercloud repository

set -e
set -x

TIMESTAMP=$(date +%Y%m%d%H%M)
FROM_RELEASE=${FROM_RELEASE:-quay.io/openshift-release-dev/ocp-release-nightly@sha256:512e79f1dbba47f66fc584d094f1a4cabb893d65af827fa3e3be36fc6c985140}
#FROM_RELEASE=docker.io/mkumatag/openshift-release:4.9-powervs-api
TO_IMAGE_REGISTRY=${TO_IMAGE_REGISTRY:-quay.io/powercloud}
TO_IMAGE=${TO_IMAGE:-openshift-release:4.9-powervs}-${TIMESTAMP}
MAX_PER_REGISTRY=${MAX_PER_REGISTRY:-8}

oc adm release new \
--from-release=${FROM_RELEASE} \
--to-image=localhost:5000/${TO_IMAGE} \
machine-config-operator=quay.io/powercloud/ose-machine-config-operator@sha256:685aa4e4cd77ba325cc361f868b804f4fbf561b5b4385cbb0ee7dd01d2cc1756 \
cluster-kube-apiserver-operator=quay.io/powercloud/openshift-cluster-kube-apiserver-operator@sha256:cab8b9d07db9ffe91a0c50e847f3544b9f3bb937f513293776bcd5d93f72205e \
cluster-etcd-operator=quay.io/powercloud/openshift-etcd-operator@sha256:0a73fc0ad29be7fe9c7a1ba8a9308fd5cdb5b7c315dabc013937767e347ac41e \
cluster-config-operator=quay.io/powercloud/openshift-cluster-config-operator@sha256:4d98cd7416a4e39293f87073560d23e844acdc205d416b739ff72a42d2112b11 \
hyperkube=quay.io/powercloud/hyperkube@sha256:4978196798db5a3645b1982478f0af03e9b6ca4d2b97da26ee5579ec8d89d779 \
machine-os-content=quay.io/powercloud/machine-os-content@sha256:cbed704ff0c60955c5faa0ecb7bc40c77f4398355a1740ff28112a9956c1f229 \
machine-api-operator=quay.io/powercloud/machine-api-operator@sha256:df5e9f413918e6a64a1d59a510ef0e9ce90c190155e18a7fdd2ccf117fcf0602 \
--max-per-registry=${MAX_PER_REGISTRY} --allow-missing-images --insecure -a ~/pull_secret.json

podman pull localhost:5000/${TO_IMAGE}
podman tag localhost:5000/${TO_IMAGE} ${TO_IMAGE_REGISTRY}/${TO_IMAGE} 
podman push --authfile ~/pcloud_bot_key.json ${TO_IMAGE_REGISTRY}/${TO_IMAGE}
