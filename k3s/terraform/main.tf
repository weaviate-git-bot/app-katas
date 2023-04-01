locals {
  region = "europe-west1"
  zone   = "europe-west1-b"
  # machine_type = "n2-standard-4"
  machine_type = "n2-standard-8"
  storage_name = "k3s-storage"
  has_snapshot = var.snapshot_name != "" && var.snapshot_name != null
}

module "network_info" {
  source  = "andreswebs/network-info/google"
  version = "0.2.0"
  network = "default"
}

data "cloudinit_config" "vm" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/tpl/cloudinit.yaml.tftpl", {
      device_file = "/dev/disk/by-id/google-${local.storage_name}"
      mount_path  = "/mnt/disks/${local.storage_name}"
      mkfs        = !local.has_snapshot
    })
  }
}

module "vm" {
  source                       = "andreswebs/public-vm/google"
  version                      = "0.5.0"
  name                         = "k3s"
  region                       = local.region
  zone                         = local.zone
  subnetwork                   = module.network_info.subnetwork[local.region].name
  domain_name                  = "technet.link"
  external_access_ip_whitelist = var.external_access_ip_whitelist
  firewall_allow_web           = false
  machine_type                 = local.machine_type

  metadata = {
    "user-data" = data.cloudinit_config.vm.rendered
  }

  extra_disks = [
    {
      name     = local.storage_name
      zone     = local.zone
      type     = "pd-ssd"
      size     = 200
      snapshot = var.snapshot_name
    }
  ]
}

module "dns" {
  source                = "andreswebs/reverse-dns/google"
  version               = "0.1.0"
  dns_reverse_zone_name = "internal-reverse"
  dns_zone_name         = "internal-technet-link"
  fqdn                  = module.vm.hostname
  ipv4_address          = module.vm.internal_ip
}

locals {
  app_hostname    = module.vm.hostname
  app_ip_external = module.vm.external_ip
}
