#!/usr/bin/bash

export TOKEN=$(ibmcloud iam oauth-tokens | cut -d ' ' -f 5 )
export CLOUD_INSTANCE_ID="blah"
export CLOUD_CRN="CRN: crn:v1:bluemix:public:power-iaas:lon04:blahblahblah::"
export REGION="lon"

if [[ -z  $1 ]];
then
    echo "USAGE: ./dhcp_service_cleanup.sh get | dhcp_service_cleanup.sh <id-of-dhcp-service>"
    exit 1
fi

DHCP_SERVICE_ID=$1

if [[ $1 == "get" ]];
then

  curl "https://${REGION}.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/${CLOUD_INSTANCE_ID}/services/dhcp/" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "${CLOUD_CRN}"

  echo
  exit 0
fi


curl -X DELETE "https://${REGION}.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/${CLOUD_INSTANCE_ID}/services/dhcp/${DHCP_SERVICE_ID}" \
-H "Authorization: Bearer ${TOKEN}" \
-H "${CLOUD_CRN}"

echo

