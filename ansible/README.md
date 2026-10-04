# SpanDock servers with Ansible

Installs SpanDock servers (a hub, and satellites if you have them) on machines you already have: Ubuntu 24.04+ or Debian 13 (glibc 2.38+), systemd, and outbound HTTPS. No inbound port is needed.

```bash
cp inventory.example.ini inventory.ini   # list your hosts
ansible-playbook -i inventory.ini site.yml
```

**The role:**
- creates a `spandock` service account;
- downloads the release and checks it against `checksums.txt`;
- installs a `spandock` systemd service and starts it.

For a new hub it then prints the **activation link**: open it, sign in, check that the code matches, and approve, once.

**Variables** (`roles/spandock_server/defaults/main.yml`):
- `spandock_version`: a release tag, or `latest`.
- `spandock_join_code`: a single-use code from the hub (Settings → Scaling → Add server) that makes this host a satellite. Pass it on the command line: `-e spandock_join_code=spandock-join:...`.

Running the playbook again upgrades to the chosen version and keeps all data.

Full guide: https://www.spandock.com/docs/deploy
