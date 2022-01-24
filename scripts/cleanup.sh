#!/usr/bin/env bash

#set -x

IBMCLOUD=${IBMCLOUD:-ibmcloud}
JQ=${JQ:-jq}
REGION=${IBM_REGION:-"eu-gb"}
POWERVS_SERVICE_INSTANCE=${POWERVS_SERVICE_INSTANCE:-"powervs-ipi-lon04"}
DOMAIN_NAME=${DOMAIN_NAME:-"scnl-ibm.com"}
CIS_INSTANCE=${CIS_INSTANCE:-"powervs-ipi-cis"}
DELETE_FUNCS=${DELETE_FUNCS:-"delete_cos delete_lbs delete_virtual_servers delete_sg delete_image delete_dns_records_cis delete_keys"}

if [[ -z "${INFRA_ID}" ]]; then
  echo "INFRA_ID is not set, please set the INFRA_ID to a valid value to cleanup the resources by that tag, find this in the <installation_dir>/metadata.json with key name infraID"
  exit
fi

if [[ -z "${CLUSTER_NAME}" ]]; then
  echo "CLUSTER_NAME is not set, please set with proper value to delete the DNS entries"
  exit
fi

if [[ -z "${IBMCLOUD_API_KEY}" ]]; then
  echo "IBMCLOUD_API_KEY is not set"
  exit
fi

if ! command -v "${IBMCLOUD}" &> /dev/null; then
  echo "${IBMCLOUD} could not be found, please install it, and the power-iaas and infrastructure-service plugins"
  exit
fi

if ! command -v "${JQ}" &> /dev/null; then
  echo "${JQ} could not be found, please install it."
  exit
fi

function RUN_IBMCLOUD() {
  if [[ "${DONT_PRINT_PARAMS}" != "true" ]]; then
    echo "params: $*"
  fi
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "$IBMCLOUD $*"
  else
    # shellcheck disable=SC2048
    CMD_OUT=$($IBMCLOUD $*)
  fi
}

for plugin in infrastructure-service power-iaas cloud-internet-services; do
  echo "checking plugin: ${plugin}..."

  RUN_IBMCLOUD plugin show ${plugin};
  if [[ "$?" != "0" ]]; then
    echo "plugin required, please install: ${IBMCLOUD} plugin install ${plugin}"
    exit
  fi
done

function IBMCLOUD_login() {
    DONT_PRINT_PARAMS=true RUN_IBMCLOUD login -a cloud.ibm.com --apikey "${IBMCLOUD_API_KEY}" -r "${REGION}"
}

function IBMCLOUD_logout() {
    DONT_PRINT_PARAMS=true RUN_IBMCLOUD logout
}

function delete_cos() {
  echo "deleting the COS instance: ${INFRA_ID}-cos"
  RUN_IBMCLOUD resource service-instances --output JSON --service-name cloud-object-storage
  cos_json=${CMD_OUT}
  cos_ids=$(echo "${cos_json}" | jq -r ".[]|select(.name == \"${INFRA_ID}-cos\").id")

  if [[ -z ${cos_ids} ]]; then
    echo "No COS found.."
    return 0
  fi
  while IFS= read -r id; do
    echo "found COS with $id, deleting it"
    RUN_IBMCLOUD resource service-instance-delete "${id}" --force --recursive
  done <<< "${cos_ids}"
}

function delete_lbs() {
  echo "deleting the load-balancers:"

  RUN_IBMCLOUD is lbs --output JSON
  lbs_json=${CMD_OUT}
  for lb in loadbalancer loadbalancer-int;do
    echo "deleting the load-balancer ${INFRA_ID}-${lb}"
    lb_id=$(echo "${lbs_json}" | jq -r ".[]|select(.name == \"${INFRA_ID}-${lb}\").id")
    if [[ -z "${lb_id}" ]]; then
      echo "${INFRA_ID}-${lb} not found"
    else
      echo "${INFRA_ID}-${lb} found with ID: ${lb_id}"
      RUN_IBMCLOUD is load-balancer-delete "${lb_id}" --force
    fi
  done
}

function delete_sg() {
  sg="${INFRA_ID}-ocp-sec-group"
  echo "Deleting the security group $sg"
  RUN_IBMCLOUD is sgs --output JSON
  sg_id=$(echo "${CMD_OUT}" | jq -r ".[]|select(.name == \"$sg\").id")
  if [[ -z "${sg_id}" ]]; then
    echo "$sg not found"
  else
    echo "$sg found with ID: ${sg_id}"
    echo "Targets for the SG:"
    RUN_IBMCLOUD is security-group-targets ${sg_id} --output JSON
    targets=$(echo "${CMD_OUT}" | jq -r '[.[].id]|join(" ")' )
    if [[ -n ${targets} ]]; then
      echo "Removing the targets[${targets}] from the security group"
      RUN_IBMCLOUD is security-group-target-remove "${sg_id}" ${targets} --force
    fi

    attempt_num=1
    max_attempts=10
    until RUN_IBMCLOUD is security-group-delete "${sg_id}" --force
    do
        if (( attempt_num == max_attempts ))
        then
            echo "Attempt $attempt_num failed and there are no more attempts left!"
            return 1
        else
            echo "Attempt $attempt_num failed! Trying again in 30 seconds..."
            ((attempt_num=attempt_num+1))
            sleep 30
        fi
    done
  fi
}

function delete_virtual_servers() {
  echo "Deleting the virtual servers"

  RUN_IBMCLOUD pi sl --json
  powervs_crn=$(echo "${CMD_OUT}" | jq -r ".[]|select(.Name == \"$POWERVS_SERVICE_INSTANCE\").CRN")
  if [[ -z "${powervs_crn}" ]]; then
    echo "$POWERVS_SERVICE_INSTANCE powervs service instance is not found"
  else
    echo "$POWERVS_SERVICE_INSTANCE powervs service instance found with CRN: ${powervs_crn}"
    RUN_IBMCLOUD pi st "${powervs_crn}"
    echo "Deleting the vms"
    RUN_IBMCLOUD pi ins --json
    ins_out=${CMD_OUT}
    for vm in bootstrap master-0 master-1 master-2 worker-.*;do
      echo "Deleting the ${INFRA_ID}-${vm}"
      instance_ids=$(echo "${ins_out}" | jq -r ".Payload.pvmInstances[]|select(.serverName|test(\"${INFRA_ID}-${vm}\")).pvmInstanceID")
      if [[ -z ${instance_ids} ]]; then
        echo "No virtual servers found with ${INFRA_ID}-${vm} pattern"
        continue
      fi
      while IFS= read -r id; do
        echo "deleting vm with $id"
        RUN_IBMCLOUD pi ind "${id}"
      done <<< "${instance_ids}"
    done
  fi
}

function delete_image() {
  echo "Deleting boot image"

  RUN_IBMCLOUD pi imgs --json
  boot_image_id=$(echo "${CMD_OUT}" | jq -r ".Payload.images[]|select(.name==\"${INFRA_ID}-boot-image\").imageID")
  if [[ -z "${boot_image_id}" ]]; then
    echo "${INFRA_ID}-boot-image was not found"
  else
    echo "Image found with imageID: ${boot_image_id}"
    RUN_IBMCLOUD pi imgd "${boot_image_id}"
  fi
}

function delete_dns_records_cis() {
  echo "Deleting the DNS records from CIS"
  RUN_IBMCLOUD cis instance-set "${CIS_INSTANCE}"
  RUN_IBMCLOUD cis domains --output JSON
  domain_id=$(echo "${CMD_OUT}" | jq -r ".[]|select(.name == \"${DOMAIN_NAME}\").id")
  if [[ -z "${domain_id}" ]]; then
    echo "${DOMAIN_NAME} not found"
  else
    echo "${DOMAIN_NAME} found with id: ${domain_id}"
    RUN_IBMCLOUD cis dns-records "${domain_id}" --output JSON
    records_json=${CMD_OUT}
    for record in *.apps api-int api;do
      record_name="${record}.${CLUSTER_NAME}.${DOMAIN_NAME}"
      echo "deleting ${record_name}"
      record_id=$(echo "${records_json}" | jq -r ".[]|select(.name == \"${record_name}\").id")
      if [[ -z "${record_id}" ]]; then
        echo "${record_name}  not found"
      else
        echo "${record_name} found with id: ${record_id}, deleting..."
        RUN_IBMCLOUD cis dns-record-delete "${domain_id}" "${record_id}"
      fi
    done
  fi
}

function delete_keys() {
  echo "Deleting the SSH key ${INFRA_ID}-key"
  RUN_IBMCLOUD pi key-delete "${INFRA_ID}-key"
}

errors=""
IBMCLOUD_login
for f in $DELETE_FUNCS; do
    $f
    if [[ $? != 0 ]]; then
        errors="${errors} \n issues encountered, or not all items were deleted during ${f}"
    fi
done

if [[ "$errors" != "" ]]; then
    printf "errors during cleanup for ${INFRA_ID}"
    printf "$errors\n"
fi
