# SpanDock deploy kits

Run a [SpanDock](https://www.spandock.com) server on a cloud VM: one paste, one command, Terraform or Ansible. A SpanDock server needs **no inbound port and no public address**; it only connects out.

| Kit | Use it for |
|---|---|
| [`cloud-init.yaml`](cloud-init.yaml) | Paste as "user data" in any provider's console: DigitalOcean, Hetzner, Akamai, Vultr, AWS, Google Cloud, Azure… |
| [`install-server.sh`](install-server.sh) | A Linux machine you already have: `curl -fsSL https://www.spandock.com/deploy/install-server.sh \| sudo bash` |
| [`terraform/aws`](terraform/aws) | EC2: Ubuntu 24.04, encrypted gp3, IMDSv2, no inbound rule |
| [`terraform/gcp`](terraform/gcp) | Compute Engine: Shielded VM, no firewall rule |
| [`ansible`](ansible) | Hubs and satellites on hosts you manage |

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://shell.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https%3A%2F%2Fgithub.com%2FSpanDock%2Fspandock-deploy&cloudshell_workspace=terraform%2Fgcp)

Every kit installs the same thing:
- a `spandock` service account;
- the latest release (or a version you pin), checked against its published checksums;
- a systemd service that restarts on failure and updates itself when that's turned on in the server's settings.

## Requirements

- Ubuntu 24.04 or later, or Debian 13 (glibc 2.38 or later); x86-64 or ARM64.
- 2 vCPU, 4 GB of memory and 30 GB of disk suit up to about 50 developers. Size larger teams with the [hardware calculator](https://www.spandock.com/requirements).
- Outbound HTTPS.

## Activate the server

A new server waits for one approval and doesn't serve until it gets it. A few minutes after boot it prints a link (on the serial console and in `journalctl -u spandock -f`). Open the link, sign in, check that the code matches, and approve. The license is then stored on the server.

## Satellites

To add a satellite, take a join code from the hub (Settings → Scaling → Add server; it works once, for 30 minutes) and pass it to any kit:
- `SPANDOCK_JOIN_CODE` for the script or cloud-init;
- `join_code` for Terraform;
- `spandock_join_code` for Ansible.

Satellites need Premium or Enterprise.

## Docs

The full guide is at https://www.spandock.com/docs/deploy. Each kit's own README has the details.

This repository holds the deploy kits only; the SpanDock app is distributed from [SpanDock/spandock-releases](https://github.com/SpanDock/spandock-releases). Issues and pull requests for the kits are welcome.

## License

The kits are licensed under the [Apache License 2.0](LICENSE). "SpanDock" and the SpanDock logos are trademarks of Nolatech Ltd and aren't covered by this license.
