resource "github_actions_secret" "ssh_host" {
  repository  = "game-of-life"
  secret_name = "SSH_HOST"
  value       = oci_core_instance.web.public_ip
}