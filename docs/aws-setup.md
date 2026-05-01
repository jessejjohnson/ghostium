# AWS setup notes

Recommended instance:

```text
c7i.8xlarge
Ubuntu 24.04 LTS
Root volume: 50 GiB gp3
Build volume: 500 GiB gp3
Mount: /work
```

Recommended gp3 settings for the build volume:

```text
Size: 500 GiB
IOPS: 6000+
Throughput: 250 MiB/s+
```

The initialization script auto-detects the second unmounted disk. To force a specific disk:

```bash
WORK_DEVICE=/dev/nvme1n1 sudo ./scripts/01-init-instance.sh
```

To avoid formatting an existing disk:

```bash
FORMAT_WORK_DEVICE=0 sudo ./scripts/01-init-instance.sh
```

Cost controls:

- Stop the EC2 instance when idle.
- Keep the EBS volume for incremental builds.
- Add AWS budget alerts.
- Do not terminate the instance unless you know your build volume is preserved.
