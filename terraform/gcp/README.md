# SpanDock server on Google Cloud (Terraform)

Creates one Compute Engine VM running a SpanDock server: Ubuntu 24.04, a Shielded VM, and **no firewall rule**, because SpanDock only connects out.

```bash
cp terraform.tfvars.example terraform.tfvars   # set project, region, size, disk
gcloud auth application-default login
terraform init
terraform apply
```

**Activate the hub once.** After two or three minutes, run the command in the `activation` output (it reads the serial port). It prints a link: open it, sign in, check that the code matches, and approve.

**Size:** `e2-medium` (2 vCPU, 4 GB) and 30 GB suit up to about 50 developers. For larger teams, use the calculator on https://www.spandock.com/requirements.

**Add a satellite:** on the hub, open Settings → Scaling → Add server and copy the join code (it works once, for 30 minutes). Then apply this module again with `name = "spandock-satellite-1"` and `join_code = "spandock-join:..."`. Satellites need Premium or Enterprise.

**No external IP?** Set `external_ip = false` and give the network Cloud NAT. The server needs outbound HTTPS.

Full guide: https://www.spandock.com/docs/deploy
