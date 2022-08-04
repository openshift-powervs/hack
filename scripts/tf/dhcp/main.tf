# query dhcp services, match a name
# edit the following:
#   - replace "DHCPSERVER8a3434436a2e42648582906c9ee86fb9_Private" with the name of your nw
#     it should have the same format ("DHCPSERVER[0-9a-z]_Private"
#   - add your api key, region, and zone to the provider block
#   - set pi_cloud_instance_id to the ID of course Power VS Service Instance
#     it should match the id from your install-config.yaml
#

# teraform init
# terraform apply

locals {
  ids = data.ibm_pi_dhcps.dhcps.servers[*].dhcp_id
  names = data.ibm_pi_dhcps.dhcps.servers[*].network_name
  dhcp_id_from_name = matchkeys(local.ids, local.names, ["DHCPSERVER8a3434436a2e42648582906c9ee86fb9_Private"])[0]
}

provider "ibm" {
  ibmcloud_api_key = "your_api_key"
  region           = "tor"
  zone             = "tor01"
}

data "ibm_pi_dhcps" "dhcps" {
  pi_cloud_instance_id = "<your svc inst id>"
}

output dhcps {
  value = data.ibm_pi_dhcps.dhcps
}

output dhcp_id {
  value = local.dhcp_id_from_name
}
