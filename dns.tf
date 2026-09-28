resource "cloudflare_record" "main" {
  zone_id = var.cloudflare_zone_id
  name    = "games"
  content = oci_core_instance.web.public_ip
  type    = "A"
  ttl     = 300
  proxied = false
}