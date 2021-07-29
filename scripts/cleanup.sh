#!/usr/bin/env bash

#set -x

IBMCLOUD=${IBMCLOUD:-ibmcloud}
REGION=${IBM_REGION:-"eu-gb"}
POWERVS_SERVICE_INSTANCE=${POWERVS_SERVICE_INSTANCE:-"powervs-ipi-lon04"}
DOMAIN_NAME=${DOMAIN_NAME:-"openshift-on-power.com"}

if [[ -z "${INFRA_ID}" ]]; then
  echo "INFRA_ID is not set, please set the INFRA_ID to a valid value to cleanup the resources by that tag"
  exit
fi

if [[ -z "${CLUSTER_NAME}" ]]; then
  echo "CLUSTER_NAME is not set, please set with proper value to delete the DNS entries"
  exit
fi

if ! command -v ${IBMCLOUD} &> /dev/null; then
  echo "${IBMCLOUD} could not be found, please install it"
  exit
fi

if [[ -z "${IBMCLOUD_API_KEY}" ]]; then
  echo "IBMCLOUD_API_KEY is not set"
  exit
fi

function RUN_IBMCLOUD() {
  if [[ "${DONT_PRINT_PARAMS}" != "true" ]]; then
    echo "params: $*"
  fi
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo $IBMCLOUD $*
  else
#    params=$(echo $*)
    CMD_OUT=$($IBMCLOUD $*)
  fi
}

function IBMCLOUD_login() {
    DONT_PRINT_PARAMS=true RUN_IBMCLOUD login -a cloud.ibm.com --apikey ${IBMCLOUD_API_KEY} -r ${REGION}
}

function IBMCLOUD_logout() {
    DONT_PRINT_PARAMS=true RUN_IBMCLOUD logout
}


function delete_cos() {
  echo "deleting the COS instance: ${INFRA_ID}-cos"
  RUN_IBMCLOUD resource service-instance-delete ${INFRA_ID}-cos --force --recursive
  echo ${CMD_OUT}
}

function delete_lbs() {
  echo "deleting the load-balancers:"

  echo "deleting the public load-balancer ${INFRA_ID}-loadbalancer"
  RUN_IBMCLOUD is lbs --output JSON
  lb_id=$(echo ${CMD_OUT} | jq -r ".[]|select(.name == \"${INFRA_ID}-loadbalancer\").id")
  if [[ -z "${lb_id}" ]]; then
    echo "${INFRA_ID}-loadbalancer not found"
  else
    echo "${INFRA_ID}-loadbalancer found with ID: ${lb_id}"
    RUN_IBMCLOUD is load-balancer-delete ${lb_id} --force
  fi

  echo "deleting the internal load-balancer ${INFRA_ID}-loadbalancer-int"
  RUN_IBMCLOUD is lbs --output JSON
  lb_int_id=$(echo ${CMD_OUT} | jq -r ".[]|select(.name == \"${INFRA_ID}-loadbalancer-int\").id")
  if [[ -z "${lb_int_id}" ]]; then
    echo "${INFRA_ID}-loadbalancer-int not found"
  else
    echo "${INFRA_ID}-loadbalancer-int found with ID: ${lb_int_id}"
    RUN_IBMCLOUD is load-balancer-delete ${lb_int_id} --force
  fi
}

function delete_sg() {
  sg="${INFRA_ID}-ocp-sec-group"
  echo "Deleting the security group $sg"
  RUN_IBMCLOUD is sgs --output JSON
  sg_id=$(echo ${CMD_OUT} | jq -r ".[]|select(.name == \"$sg\").id")
  if [[ -z "${sg_id}" ]]; then
    echo "$sg not found"
  else
    echo "$sg found with ID: ${sg_id}"
    RUN_IBMCLOUD is security-group-delete ${sg_id} --force
  fi
}

function delete_virtual_servers() {
  echo "Deleting the virtual servers"

  RUN_IBMCLOUD pi sl --json
  powervs_crn=$(echo ${CMD_OUT} | jq -r ".[]|select(.Name == \"$POWERVS_SERVICE_INSTANCE\").CRN")
  if [[ -z "${powervs_crn}" ]]; then
    echo "$POWERVS_SERVICE_INSTANCE powervs service instance is not found"
  else
    echo "$POWERVS_SERVICE_INSTANCE powervs service instance found with CRN: ${powervs_crn}"
    RUN_IBMCLOUD pi st ${powervs_crn}
    echo "Deleting the vms"
    RUN_IBMCLOUD pi ins --json
    ins_out=${CMD_OUT}
    for vm in bootstrap master-0 master-1 master-2;do
      echo "Deleting the ${vm}"
      instance_id=$(echo ${ins_out} | jq -r ".Payload.pvmInstances[]|select(.serverName == \"${INFRA_ID}-${vm}\").pvmInstanceID")
      if [[ -z "${instance_id}" ]]; then
        echo "$vm not found"
      else
        echo "$vm found with ID: ${instance_id}"
        RUN_IBMCLOUD pi ind ${instance_id}
      fi
    done
  fi
}

function delete_dns_records() {
  echo "Deleting the DNS records"
  RUN_IBMCLOUD sl dns record-list ${DOMAIN_NAME} --output JSON
  dns_json=${CMD_OUT}
  for record in *.apps api-int api;do
    host="${record}.${CLUSTER_NAME}"
    echo "deleting the record ${record}.${CLUSTER_NAME}"
    domain_id=$(echo ${dns_json} | jq -r ".[]|select(.host == \"${host}\").id")
    if [[ -z "${domain_id}" ]]; then
      echo "$host not found"
    else
      echo "$host found with domainID: ${domain_id}"
      RUN_IBMCLOUD sl dns record-remove ${domain_id}
    fi
  done
}

IBMCLOUD_login
delete_cos
delete_lbs
delete_sg
delete_virtual_servers
delete_dns_records
