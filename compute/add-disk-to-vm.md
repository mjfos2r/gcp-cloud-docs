# Okay lets add a new persistent disk to our instance.

## TODO: Add commands for adding new disks via gcloud CLI

## Steps for setting up disk within VM

Ok now that the disk is created and mounted lets add it to the instance, format, and mount it.

1. Identify disk id.

```bash
# what's the id of our new disk
ls -l /dev/disk/by-id/google-*
```

Which will return something like the following:

```bash
lrwxrwxrwx 1 root root  9 Feb 13 17:25 /dev/disk/by-id/google-rachel-1-500g -> ../../sdb
lrwxrwxrwx 1 root root  9 Feb 13 17:25 /dev/disk/by-id/google-ram-optimized -> ../../sda
lrwxrwxrwx 1 root root 10 Feb 13 17:25 /dev/disk/by-id/google-ram-optimized-part1 -> ../../sda1
lrwxrwxrwx 1 root root 11 Feb 13 17:25 /dev/disk/by-id/google-ram-optimized-part14 -> ../../sda14
lrwxrwxrwx 1 root root 11 Feb 13 17:25 /dev/disk/by-id/google-ram-optimized-part15 -> ../../sda15
```

and the disk id is `/dev/sdb/`

2. Create mount point.

```bash
# let's create our mount point
sudo mkdir -p /mnt/disks/<mount-point-directory>
```

3. Format disk.

```bash
# ok let's format our disk
sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/<disk-id>
```

4. Mount the disk.

```bash
# and now lets mount our disk to the mountpoint we created!
# (and expand permissions for all to read and write to it!)
sudo mount -o discard,defaults /dev/<disk-id> /mnt/disks/<mount-directory>/ && sudo chmod a+w /mnt/disks/<mount-point-directory>
```

5. Now we need to make mounting happen automatically on boot.
   a.First we need to back up /etc/fstab (timestamp the backup)

   ```bash
   sudo cp /etc/fstab /etc/fstab.backup.20250213
   ```

   b. Now we need to retrieve the UUID of the disk. (use the disk-id from above 'e.g. /dev/sdb')

   ```bash
   sudo blkid /dev/<disk-id>
   ```

   Example Return:

   ```bash
   /dev/sdb: UUID="2ee8dd54-3975-4528-930b-9e030060bd69" BLOCK_SIZE="4096" TYPE="ext4"
   ```

   c. Now we need to add the following information to fstab using vim or nano.
   `UUID=<UUID_VALUE> /mnt/disks/<MOUNT_DIR> <FILE_SYSTEM_TYPE> discard,defaults,<MOUNT_OPTION> 0 2`

   we can use a text editor or use echo append it like below. (don't forget sudo!)

   ```bash
   sudo vim /etc/fstab
   ```

   The file should look something like this:

   ```bash
   # /etc/fstab: static file system information
   UUID=d93392c2-f9f4-48b6-915c-de0b168c4ed2 / ext4 rw,discard,errors=remount-ro,x-systemd.growfs 0 1
   UUID=9459-3AFC /boot/efi vfat defaults 0 0
   ```

   create a new line at the bottom and add the line from above.
   Example:

   ```bash
   UUID=2ee8dd54-3975-4528-930b-9e030060bd69 /mnt/disks/rachel-1 ext4 discard,defaults,nofail 0 2
   ```

   d. Now let's check to make sure that it's added correctly in the /etc/fstab file!

   ```bash
   cat /etc/fstab
   ```

   which should return something like the following:

   ```bash
   # /etc/fstab: static file system information
   UUID=d93392c2-f9f4-48b6-915c-de0b168c4ed2 / ext4 rw,discard,errors=remount-ro,x-systemd.growfs 0 1
   UUID=9459-3AFC /boot/efi vfat defaults 0 0
   UUID=2ee8dd54-3975-4528-930b-9e030060bd69 /mnt/disks/rachel-1 ext4 discard,defaults,nofail 0 2
   ```

---

And boom bap bob's your uncle, now we can turn it off and on and the disk should automatically mount! You can powercycle the VM to test if you want to!

#>>{MJF - 2025-Feb-13}<<#
