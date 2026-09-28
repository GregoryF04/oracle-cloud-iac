data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "web" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name
  shape               = "VM.Standard.E2.1.Micro"
  display_name        = "game-of-life-instance-tf"

  create_vnic_details {
    subnet_id        = oci_core_subnet.main.id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data           = base64encode(file("${path.module}/cloud-init.yaml"))
  }

  lifecycle {
    ignore_changes = [source_details]
  }
}

output "public_ip" {
  value = oci_core_instance.web.public_ip
}