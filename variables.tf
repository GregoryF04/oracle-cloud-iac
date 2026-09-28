variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" { default = "eu-frankfurt-1" }
variable "compartment_ocid" {}
variable "ssh_public_key_path" {}
variable "github_token" {
  sensitive = true
}
variable "cloudflare_api_token" {
  sensitive = true
}
variable "cloudflare_zone_id" {}
variable "domain_name" {}