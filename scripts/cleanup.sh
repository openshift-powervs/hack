#!/usr/bin/env bash

#set -x

IBMCLOUD=${IBMCLOUD:-ibmcloud}
JQ=${JQ:-jq}
REGION=${IBM_REGION:-"eu-gb"}
POWERVS_SERVICE_INSTANCE=${POWERVS_SERVICE_INSTANCE:-"powervs-ipi-lon04"}
DOMAIN_NAME=${DOMAIN_NAME:-"scnl-ibm.com"}
CIS_INSTANCE=${CIS_INSTANCE:-"powervs-ipi-cis"}

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

for plugin in infrastructure-service power-iaas cloud-internet-services;do
  echo "checking plugin: ${plugin}..."

  if ! RUN_IBMCLOUD plugin show ${plugin}; then
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
    RUN_IBMCLOUD is security-group-delete "${sg_id}" --force
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

function delete_dns_records() {
  echo "Deleting the DNS records from Classic Infrastructure(Softlayer)"
  RUN_IBMCLOUD sl dns record-list "${DOMAIN_NAME}" --output JSON
  dns_json=${CMD_OUT}
  for record in *.apps api-int api;do
    host="${record}.${CLUSTER_NAME}"
    echo "deleting the record ${record}.${CLUSTER_NAME}"
    domain_id=$(echo "${dns_json}" | jq -r ".[]|select(.host == \"${host}\").id")
    if [[ -z "${domain_id}" ]]; then
      echo "$host not found"
    else
      echo "$host found with domainID: ${domain_id}"
      RUN_IBMCLOUD sl dns record-remove "${domain_id}"
    fi
  done
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

IBMCLOUD_login
delete_cos
delete_lbs
delete_sg
delete_virtual_servers
delete_dns_records
delete_dns_records_cis
delete_keys
