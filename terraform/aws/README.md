# SpanDock server on AWS (Terraform)

Creates one EC2 instance running a SpanDock server: Ubuntu 24.04, an encrypted gp3 disk, IMDSv2, and a security group with **no inbound rule**, because SpanDock only connects out.

```bash
cp terraform.tfvars.example terraform.tfvars   # set region, size, disk
terraform init
terraform apply
```

**Activate the hub once.** After two or three minutes, run the command in the `activation` output. It prints a link: open it, sign in, check that the code matches, and approve. The license is then stored on the server; restarts don't ask again.

**Size:** `t3.medium` (2 vCPU, 4 GB) and 30 GB suit up to about 50 developers. For larger teams, use the calculator on https://www.spandock.com/requirements.

**Add a satellite:** on the hub, open Settings → Scaling → Add server and copy the join code (it works once, for 30 minutes). Then apply this module again in a new workspace (or folder) with `name = "spandock-satellite-1"` and `join_code = "spandock-join:..."`. Satellites need Premium or Enterprise.

**Updates:** the server updates itself when "Install updates automatically" is on in its settings.

Full guide: https://www.spandock.com/docs/deploy
