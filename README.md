# Oracle Cloud IaC — Mini Games

Terraform + cloud-init for deploying a collection of browser-based mini games on Oracle Cloud Always Free (`VM.Standard.E2.1.Micro`, Frankfurt).

Application: https://github.com/GregoryF04/game-of-life
Live site: https://games.gregorydump.download

## What is created with a single `terraform apply`

* VCN, subnet, internet gateway, route table, and security list (22, 80, 443, ICMP)
* Oracle Linux 9 compute instance with cloud-init bootstrap
* Cloudflare DNS A record pointing to the new instance's IP address
* GitHub Actions secret `SSH_HOST`, updated automatically

## Architecture

```text
User ──HTTPS──> Cloudflare DNS (DNS only)
                       │
                       ▼
              Oracle VM (E2.1.Micro)
              nginx :80/:443 (Let's Encrypt)
                       │
                       │ reverse proxy
                       ▼
              Docker: Node.js/Express :8080 (localhost)
                       │
          ┌────────────┼─────────────┐
       games (static) /api (state) /health, /status
```

### CI/CD

```text
git push
   ↓
GitHub Actions
   ↓
SSH
   ↓
git reset --hard
   ↓
docker compose up -d --build
   ↓
/health check
```

## Project structure

| File                       | Purpose                                                                     |
| -------------------------- | --------------------------------------------------------------------------- |
| `main.tf`                  | Providers: OCI, GitHub, Cloudflare                                          |
| `network.tf`               | VCN, subnet, security list                                                  |
| `instance.tf`              | Compute instance, image and availability domain selection                   |
| `dns.tf`                   | A record for `games.<domain>`                                               |
| `github.tf`                | Synchronization of the `SSH_HOST` secret                                    |
| `cloud-init.yaml`          | Bootstrap: swap, Docker, nginx, cron monitoring                             |
| `terraform.tfvars.example` | Template for secrets and configuration (the actual file is in `.gitignore`) |

## Getting started

```bash
cp terraform.tfvars.example terraform.tfvars
# Fill in the required values

terraform init
terraform plan
terraform apply
```

After `apply`, there is one intentional manual step. It depends on DNS propagation and Let's Encrypt rate limits:

```bash
sudo certbot --nginx -d games.<domain> --non-interactive --agree-tos -m <email> --redirect
```

## Expensive lessons learned

### Swap before Docker

With only 1 GB of RAM, running:

```bash
dnf install docker-ce
```

without swap can result in an OOM kill.

Swap is therefore created as the first step in cloud-init, before installing Docker.

### Free Tier limits are tied to the availability domain

`VM.Standard.E2.1.Micro` had a quota of `0` in AD-1. The resulting error looked like:

```text
404 NotAuthorizedOrNotFound
```

When provisioning an Always Free instance, make sure to select an availability domain where the Free Tier quota is actually available.

### DNS may not work correctly during cloud-init

During bootstrap, DNS resolution can fail with a resolver such as:

```text
nameserver 192.168.122.1
```

The configuration explicitly uses Google DNS:

```text
8.8.8.8
```

to avoid bootstrap failures caused by the unavailable resolver.

### Private repositories do not work with a non-interactive `git clone`

A private GitHub repository requires authentication. A plain non-interactive `git clone` cannot prompt for credentials, so repository access needs to be configured appropriately.

### SELinux can block nginx → localhost

SELinux can prevent nginx from connecting to the Node.js application on localhost.

The required setting is:

```bash
setsebool -P httpd_can_network_connect 1
```

### A CI deployment can report a false success

`ssh-action` does not necessarily fail when a command in the middle of the remote script fails unless configured to stop on errors.

Use:

```yaml
script_stop: true
```

and verify the deployment by checking the application's `/health` endpoint.

### Ignore changes to the image source

The image data source can return a new OCID when Oracle publishes a fresh image build. Without handling this, Terraform may attempt to "update" an otherwise healthy running instance.

The instance therefore uses:

```hcl
lifecycle {
  ignore_changes = [source_details]
}
```

This prevents routine image rebuilds from triggering an unnecessary instance replacement/update.

## Known limitations

* Terraform state is stored locally; there is no remote backend.
* The TLS certificate must be issued manually after each instance recreation.
* The deployment uses a single instance with no high-availability or failover setup.
