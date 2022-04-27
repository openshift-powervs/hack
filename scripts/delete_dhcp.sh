#!/usr/bin/env -S -i bash
export IBMCLOUD_HOME=/home/<you>

printf "Remember that no env vars will be picked up outside this script"
sleep 1

API_KEY=""
BEARER_TOKEN=$(curl -X POST     "https://iam.cloud.ibm.com/identity/token"     -H "content-type: application/x-www-form-urlencoded"     -H "accept: application/json"     -d "grant_type=urn%3Aibm%3Aparams%3Aoauth%3Agrant-type%3Aapikey&apikey=${API_KEY}" | jq -r .access_token)

## Regions: # eu-gb, eu-gb-1, lon, lon04 | ca-tor, tor
IBM_REGION="eu-gb"
REGION="lon"
#ZONE="04"
ZONE="06"
#IBM_REGION="ca-tor"
#REGION="tor"
#ZONE="01"

# lon04
lon04_CLOUD_INSTANCE_ID="e449d86e-c3a0-4c07-959e-8557fdf55482" 
lon04_CRN="crn:v1:bluemix:public:power-iaas:lon04:a/65b64c1f1c29460e8c2e4bbfbd893c2c:e449d86e-c3a0-4c07-959e-8557fdf55482::"
# lon06
lon06_CLOUD_INSTANCE_ID="7763a372-a9a8-4d19-aaf3-63765a693e5b"
lon06_CRN="crn:v1:bluemix:public:power-iaas:lon06:a/65b64c1f1c29460e8c2e4bbfbd893c2c:7763a372-a9a8-4d19-aaf3-63765a693e5b::"
# toronto
tor01_CRN="crn:v1:bluemix:public:power-iaas:tor01:a/65b64c1f1c29460e8c2e4bbfbd893c2c:fc35919d-10d3-4305-8199-bd3719a8a03c::"
tor01_CLOUD_INSTANCE_ID="fc35919d-10d3-4305-8199-bd3719a8a03c"

## compose var names
## todo: this falls apart for values with dashes (e.g. eu-de-1)
eval CLOUD_INSTANCE_ID='$'"${REGION}${ZONE}_CLOUD_INSTANCE_ID"
eval SERVICE_CRN='$'"${REGION}${ZONE}_CRN"

## Set Targets
# api endpoint and ibmcloud region
ibmcloud login -a "${API_ENDPOINT}" --apikey "${API_KEY}" -r "${IBM_REGION}"
# resource group
ibmcloud target -g powervs-ipi-resource-group
# powervs service instance
ibmcloud pi service-target "${SERVICE_CRN}"

DHCP_SERVICE_ID=$1

if [[ "${DHCP_SERVICE_ID}" == "" ]]; then
	echo "empty dhcp svc id. exiting"
	exit 1
fi

curl -X DELETE  "https://${REGION}.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/${CLOUD_INSTANCE_ID}/services/dhcp/${DHCP_SERVICE_ID}" \
  -H "Authorization: Bearer ${BEARER_TOKEN}" \
  -H "CRN: ${SERVICE_CRN}" \
  -H 'Content-Type: application/json'

echo
