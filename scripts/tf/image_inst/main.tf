provider "ibm" {
  alias            = "powervs"
  ibmcloud_api_key = ""
  region           = "lon"
  zone             = "lon06"
}

locals {
   cloud_inst_id = ""
}

resource "ibm_pi_image" "boot_img" {
  provider = ibm.powervs
  pi_image_name = "rhma_test_img"
  pi_cloud_instance_id = local.cloud_inst_id
  pi_image_bucket_name = "rhcos-powervs-images-eu-gb"
  pi_image_bucket_access = "public"
  pi_image_bucket_region = "eu-gb"
  pi_image_bucket_file_name = "rhcos-412-86-202208090152-0-ppc64le-powervs.ova.gz"
  pi_image_storage_type = "tier1"
}

resource "ibm_pi_instance" "test_instance" {
    provider              = ibm.powervs
    pi_memory             = "8"
    pi_processors         = "0.5"
    pi_instance_name      = "rhma-prov-test"
    pi_proc_type          = "shared"
    pi_image_id           = ibm_pi_image.boot_img.image_id
    pi_key_pair_name      = "dmistry"
    pi_sys_type           = "s922"
    pi_cloud_instance_id  = local.cloud_inst_id
    pi_pin_policy         = "none"
    pi_health_status      = "WARNING"
    pi_network            {network_id = "1939ec0a-c010-4c2a-991a-03495a116536"}
    pi_storage_type       = "tier1"
}

