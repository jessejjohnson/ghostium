Mount volume and grant permissions

```
lsblk
sudo mkfs -t xfs /dev/nvme1n1
sudo mkdir /mnt/chromium
sudo mount /dev/nvme1n1 /chromium
chmod -R 777 /mnt/chromium
```