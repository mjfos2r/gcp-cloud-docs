# Interacting with GCP object checksums

So with our data, uploads are want to corrupt. To hedge against this, we need to generate and validate checksums at each end of the transfer.

1. generate local checksum on the original data object.
2. upload that object to the bucket
3. validate the checksum of the object in the bucket and ensure it is unchanged.

## Buckets o' hash

To view the checksum of objects in GCP buckets, the following commands can be used.

```bash
gcloud storage -L gs://bucket-12345/data/runs/run_id/run_data.tar.gz
# which returns something like this:
gs://bucket-12345/data/runs/run_id/run_data.tar.gz:
  Creation Time:               2025-06-05T00:42:42Z
  Update Time:                 2025-06-05T00:42:42Z
  Storage Class Update Time:   2025-06-05T00:42:42Z
  Storage Class:               STANDARD
  Content-Length:              169814251157
  Content-Type:                application/x-tar
  Hash (CRC32C):               bmTrIQ==
  Hash (MD5):                  A4Pe111PdunqyYnMwZooIg==
  ETag:                        CMiAr6GG2Y0DEAE=
  Generation:                  1749084162211912
  Metageneration:              1
  ACL:                         []
TOTAL: 1 objects, 169814251157 bytes (158.15GiB)
```

We can also generate a hash of the remote object via `gcloud storage hash`

```bash
gcloud storage hash gs://bucket-12345/data/runs/run_id/run_data.tar.gz
# which returns
---
crc32c_hash: bmTrIQ==
digest_format: base64
md5_hash: A4Pe111PdunqyYnMwZooIg==
url: gs://bucket-12345/data/runs/run_id/run_data.tar.gz
```

*to get the hash by itself, use the following:*

```bash
gcloud storage ls -L gs://bucket-12345/data/runs/run_id/run_data.tar.gz | grep "Hash (MD5):" | awk -F' ' '{print $3}'
# which returns
A4Pe111PdunqyYnMwZooIg==
```

This is in *base64* but we generate checksums locally in *hex*
Gotta convert it to use it in a script or otherwise.

The better approach is to just convert the md5sum to *base64* which we can do via the following approach. (for cases where the hash is already calculated and needs conversion)

```bash
cat 20250325_PBA65894_US_BB_JBB_1-40.tar.gz.md5 | awk -F' ' '{print $1}' | xxd -r -p | base64
# which returns the following checksum in base64
A4Pe111PdunqyYnMwZooIg==
```

## more hash please

So one hash might suffice but we've had issues before where the hash itself is on a corrupted file. Valid hash but corrupt file. Let's hash our files before compression, then hash the digest, and generate another hash as well to ensure NO CORRUPTION.

### Pre-flight checks

This is gonna hash each file going into the compressed object
Then hash the hash.

#### on local machine

```bash
cd $files_directory
find . -type f -print0 | sort -z | xargs -0 md5sum > files.raw.md5
# then hash that content list
md5sum raw_hashes.md5 > files.raw.md5.digest
```

then we compress our files and hash the compressed object:

```bash
tar --use-compression-program=pigz -cvf files.tar.gz $files_directory
md5sum files.tar.gz > files.tar.gz.md5
```

### Post flight checks

#### on local Machine

```bash
LOCAL_HASH=$(cat 20250325_PBA65894_US_BB_JBB_1-40.tar.gz.md5 | awk -F' ' '{print $1}' | xxd -r -p | base64)
REMOTE_HASH=$(gcloud storage ls -L gs://fc-secure-83a5cea5-a13e-43ab-95d3-d39955cb7e61/nanopore/promethion_runs/20250325_PBA65894_US_BB_JBB_1-40/20250325_PBA65894_US_BB_JBB_1-40.tar.gz | grep "Hash (MD5):" | awk -F' ' '{print $3}')

[[ $LOCAL_HASH == $REMOTE_HASH ]] \
    && {
        echo "Checksums match!";
        echo "LOCAL: $LOCAL_HASH";
        echo "REMOTE: $REMOTE_HASH";
        } \
    || {
        echo "ERROR: Checksum mismatch";
        echo "LOCAL: $LOCAL_HASH";
        echo "REMOTE: $REMOTE_HASH";
        }
```

#### on remote machine

Same thing but in reverse:

```bash
# make our output directory
mkdir -p decompressed
# check the raw hash
md5sum -c files.raw.md5.digest
# check the tarball
md5sum -c files.tar.gz.md5
# if groovy, unpack it
tar --use-compression-program=pigz -xvf files.tar.gz -C decompressed --strip-components=1
# now check each file
cd decompressed
md5sum -c ../files.raw.md5
```

This should iron out any issues we may run into during compression and upload.

## different hash please

So let's add another hashing algorithm for robustness.

Either CRC32 since gcloud uses that automatically, or we can try xxhash since I've read good things about that. (and it's *allegedly* very FAST)

```bash
xxhsum -H1 files.tar.gz > files.tar.gz.xxh64
```

and on the remote machine:

```bash
xxhsum -c files.tar.gz.xxh64
```
