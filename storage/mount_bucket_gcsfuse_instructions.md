# gcsfuse notes and tutorial

## the problem

We gotta do something bout them persistent disk charges. We already got buckets, what if we could just mount em like disks?
Turns out We can do this _quite_ easily using a tool shown to me by John Colangeli. (big thanks!)

Previously, due to my limited understanding of the gcp cloud infrastructure and cloud sysadmin/devops, if I needed more space on a VM
I would have to create a blank disk, add the disk to the VM, mount and format the disk, then it would be available for use.
To then back the data up to the bucket, the entire disk mountpoint would then have to be rsynced/cp -r 'ed into the bucket which is very
painful for large analyses.

That adds *significant* complexity and generates task avoidance (personally) due to the painful nature of manual bucket syncing. That leads to strange issues with data
versioning and poor results availability across teams. Also means redundant processes ( like re-downloading annotation databases >:| )

Its also *expensive*.

## Persistent Disk Pricing

***

Persistent disks are [quite expensive](https://cloud.google.com/compute/disks-image-pricing#disk)
Disk pricing for us-central1 as of 27-Aug-2024:
    - standard provisioned space : $0.04/GB
    - SSD provisioned space      : $0.17/GB
    - balanced provisioned space : $0.10/GB
    - extreme provisioned space  : $0.125/GB

***

## Bucket Pricing

Buckets are [relatively cheap*](https://cloud.google.com/storage/pricing)
    - Pricing is by [storage class](https://cloud.google.com/storage/docs/storage-classes)
    - Some classes necessitate [retrieval fees](https://cloud.google.com/storage/pricing#retrieval-pricing)
        - Some of these classes have [minimum storage durations](https://cloud.google.com/storage/pricing#early-delete)
    - All classes are subject to [operation charges](https://cloud.google.com/storage/pricing#operations-pricing)
        >this is moving files in and out, deleting files, etc. Charged per 1,000 operations.

***

Bucket pricing for us-central1 as of 27-Aug-2024:
    - Class, price per GB per month, retrieval fee, minimum storage duration
    - STANDARD storage, $0.020  /GB/month, None, None
    - NEARLINE storage, $0.010  /GB/month, $0.01/GB, 30 days
    - COLDLINE storage, $0.004  /GB/month, $0.02/GB, 90 days
    - ARCHIVE  storage, $0.0012 /GB/month, $0.05/GB, 365 days

***
Okay, so we will be using STANDARD class storage in the us-central1 region. This qualifies for single-region pricing.
We will need to pay for storage per month,
~loading data into the bucket from outside of GCP~ <- this is free, actually.
moving data from GCP to outside of the bucket, [egress pricing here](https://cloud.google.com/storage/pricing#network-egress)
    - this is $0.12/GB but we aren't downloading much locally so this shouldn't be an issue at all.

However we do not need to pay file transfer fees for transfers [within the same region in GCP](https://cloud.google.com/storage/pricing#network-buckets)
see: [always free](https://cloud.google.com/storage/pricing#cloud-storage-always-free)
    - we also get 5k ops free per month.

## GCSFuse overview

[gcsfuse](https://cloud.google.com/storage/docs/gcs-fuse) is a tool from goggle that allows users to mount a bucket as a
file system in userspace. This means we can use buckets identically^[1] to how we use mounted disks.

##Benefits of using buckets as mounted disks:
    1. no more persistent disk charges, money can instead be spent on high cpu instances.
    2. data is now backed up to the bucket by default, no more versioning issues due to stale data.
    3. data is now available on every instance with ease. no more weird versioning issues and tedious repeat downloads. Just mount the bucket

Caveats of using buckets as mounted disks:
    1. it is probably going to introduce some issues dealing with file latency and designate the need for some sort of cache.
        >we can cross this bridge when we get to it.
    2. Buckets can also be expensive. While storage per GB is cheaper than even the cheapest persistent disk, we do have the potential to
    rack up some charges in [file operations](https://cloud.google.com/storage/pricing#operations-pricing)!!!
       - using gcsfuse uses many Class A and Class B operations for each action: [ops mapping table](https://cloud.google.com/storage/docs/gcs-fuse#operations-mapping)
       - Class A operations cost $0.01 per 1000
       - Class B operations cost $0.0004 per 1000
    3. Buckets must *NOT* be autoclassed, (additional charge) and must be appropriately classed to STANDARD class _within the correct region_ to maximize cost effectiveness.
    4. Will possibly be making a calculator to adequately measure the cost of using a bucket as an attached disk. Google has one
        - [here](https://cloud.google.com/products/calculator?hl=en)

## GCSFUSE COMMAND TO OPERATIONS CLASS TABLE

`gcsfuse --debug_gcs example-bucket mount-point`:
    - storage.objects.list, Class A

`cd mount-point`, n/a, n/a
    No JSON API call, Free Operation

`ls mount-point`:
    - storage.objects.list(""), Class A

`mkdir subdir`:
    - storage.objects.get("subdir"), Class B
    - storage.objects.get("subdir/"), Class B
    - storage.objects.insert("subdir/"), Class A

`cp ~/local.txt subdir/`:
    - storage.objects.get("subdir/local.txt"), Class B
    - storage.objects.get("subdir/local.txt/"), Class B
    - storage.objects.insert("subdir/local.txt"), Class A
        - #to create an empty object
    - storage.objects.insert("subdir/local.txt"), Class A
        - #when closing after done writing,

`rm -rf subdir`,
    - storage.objects.list("subdir"), Class A
    - storage.objects.list("subdir/"), Class A
    - storage.objects.delete("subdir/local.txt"), Free Operation
    - storage.objects.list("subdir/"), Class A
    - storage.objects.delete("subdir/"), Free Operation

***

## How to connect a bucket to a VM

> mounting a bucket reminds me of an outhouse and that's oddly poetic.

Anyway, let's get started.
### Steps To Mount

1. First, we need to make sure that you have gcloud installed and activated. you should already have this set up on your local machine.
    - if you don't, [fix that here](https://cloud.google.com/sdk/docs/install)
2. Assuming everything is groovy, make sure that the service account for the compute instance has the appropriate API scopes. If this isn't set correctly, all you can do
    is read from the bucket. Not much use to just look at the bucket.
    To check the service account scope, execute the following command in your local terminal:

    ```{bash}
    gcloud compute instances describe INSTANCE_NAME --zone=ZONE --format="value(serviceAccounts[0].scopes.list())" | tr ',' '\n'
    ```

    - this ~will~ **should** return something like the following: `https://www.googleapis.com/auth/cloud-platform`
    - We now have the default scope, to expand the scope we need to add: `https://www.googleapis.com/auth/devstorage.read_write`

3. execute the following command:

    ```{bash}
    gcloud compute instances set-service-account INSTANCE_NAME --zone=ZONE \
    --scopes=https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/devstorage.read_write
    ```

4. okay great, now you can read and write to buckets to your hearts content within gcp compute instances. Let's actually ssh into our vm and connect the bucket.
5. once inside, make sure that gcsfuse is installed. check the version ```gcsfuse --version```
6. if it isn't installed, follow [these instructions](https://cloud.google.com/storage/docs/gcsfuse-install)
7. okay now that you have it installed, in your home directory (or wherever you want the bucket mountpoint to be)
    a. create a buckets directory and a subdirectory for each bucket you want to mount.

    ```{bash}
    mkdir -p /local/path/to/buckets/bucket1
    ```

8. then using gcsfuse, mount your bucket to the respective directory. Make sure that you use the `--implicit-dirs` flag otherwise it won't work properly.
    - using `--debug_fuse --debug_gcs` also makes things easier so that you can see what's breaking when it does.

    ```{bash}
    gcsfuse --debug_fuse --debug_gcs --implicit-dirs my-bucket1 /local/path/to/buckets/bucket1
    ```

    The name of the local path can be anything you want it to be, it doesn't have to be derivative of the bucket name, it's just helpful to do that.

9. check to verify successful mounting. `ls` and `cd` into it. You can also `mkdir test` and `touch test/hello.txt` then check in the storage web viewer to make sure.

    **BE VERY CAREFUL NOW, YOU CAN JUST AS EASILY DELETE EVERYTHING IN THE BUCKET AS YOU CAN WITH ANY OTHER LINUX FILESYSTEM**

10. use the bucket as you would a mounted disk.
11. send a slack to @michaelfoster when you run into issues trying to process files stored in the bucket because it will probably mean he has to figure out caching >:|

***

## Final notes for now

Okay, so depending on how many operations you are doing, it could still end up costing a chunk of money.
However, this is still **probably** cheaper than persistent disk. I think a dynamic disk strategy is likely the best option here.
I need to work on a calculator to determine how many operations certain actions or scripts will perform, then calculate cost based on that.

It would be very handy to have a full calculator to estimate the cost of certain jobs and whatnot. That is still in very early planning.

anyway, that's all I've got for now!

#>>{MJF - 2024-Aug-27}<<#