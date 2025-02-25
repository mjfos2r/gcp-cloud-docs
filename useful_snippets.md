# Useful GCP commands

## Disk Management

```bash
# To create a disk (image not required thus far but would be helpful for spinning up DBs?)
# for --type, it can be one of [ pd-standard, pd-ssd, pd-balanced, pd-extreme, ...  ]
gcloud compute disks create DISK_NAME --size=SIZE --type=DISK_TYPE --zone=ZONE --image=IMAGE
# it can also be created from a snapshot.
gcloud compute disks create DISK_NAME --source-snapshot=SNAPSHOT_NAME --zone=ZONE

# to mount a disk to an instance
# Then ssh into it and attach as elsewhere described.
gcloud compute instances attach-disk INSTANCE_NAME --disk=DISK_NAME --zone=ZONE

# to detach a disk from an instance
gcloud compute instances detach-disk INSTANCE --disk=DISK_NAME --zone=ZONE

# to delete a disk
gcloud compute disks delete DISK_NAME --zone=ZONE
```

## VM management

```bash
# To populate later
```

