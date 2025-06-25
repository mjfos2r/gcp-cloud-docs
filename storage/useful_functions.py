import io

import pandas
from google.storage import storage

# swiped and adapted from:
# [google itself](https://github.com/googleapis/python-storage/tree/main/samples/snippets)

#TODO: Finish populating docstrings

def gs_download_to_stream(bucket_name, source_blob_name, file_obj):
    """
    Download a bucket object to an io.<format>IO handle.
    It could probably be any io handle, but I've only gotten it to work
    using io.BytesIO()
    """
    # to download object: gs://my_bucket/path/to/file/in/bucket/file.txt
    #     bucket_name == "my_bucket"
    #     source_blob_name == "path/to/file/in/bucket/file.txt"
    #     file_obj == "stream/file-like object" -> io.<format>IO()
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(source_blob_name)
    blob.download_to_file(file_obj)
    print(f"Downloaded blob: {source_blob_name} \n to file-like object/stream.\n")
    return file_obj


def gs_dataframe_from_bucket(
    bucket: Optional[str] = None,
    target_blob: Optional[str] = None,
    *,
    full_path: Optional[str] = None,
    delimiter=","
    ) -> pandas.DataFrame:
    """
    This function downloads a remote table from Google Cloud Storage and loads it into a `pandas.DataFrame()`.

    This function can be used in one of two ways:
        1. Specify both `bucket_name` and `source_blob_name` directly.
        2. Provide a single `full_path` in the form "gs://<bucket>/<path/to/blob>".

    Also, encoding of target file is assumed to be `utf-8`.

    Args:
        bucket_name(str, optional): Name of the GCS bucket. (e.g. "my-gcp-bucket").
        source_blob_name(str, optional): Path to the blob within the bucket (e.g. "path/to/my/file.csv").
        full_path(str, optional): Complete path to the file. (e.g. "gcs://my-bucket/path/to/my/file.csv").
        delimiter(str, optional): Specify the delimiter used in the remote table. [ default: "," ]

    Returns:
        pandas.DataFrame: Dataframe created from the contents of the downloaded file.

    Raises:
        ValueError: If neither (`bucket` and `target_blob`) nor `full_path` is provided.

    Examples:
        >>> df = gs_dataframe_from_bucket(bucket = "my-bucket", target_blob= "path/to/my/file.tsv", delimiter="\t")
        >>> df
           A   B
        0  1   6
        1  2   7
        2  3   8
        3  4   9
        4  5  10

        >>> df = gs_dataframe_from_bucket(full_path = "gcs://my-bucket/path/to/my/file.tsv", delimiter="\t")
        >>> df
           A   B
        0  1   6
        1  2   7
        2  3   8
        3  4   9
        4  5  10
    """
    if full_path:
        parts = full_path.replace("gs://", "").split("/", 1)
        if len(parts) != 2:
            raise ValueError(f"Invalid full_path format: {full_path}")
        bucket, target_blob = parts
    elif not (bucket and target_blob):
        raise ValueError("Must provide either `bucket` and `target_blob`, or `full_path`.")

    io_obj = io.BytesIO()
    raw_stream = gs_download_to_stream(bucket, target_blob, io_obj)
    raw_stream.seek(0)
    df = pandas.read_csv(
        io.StringIO(raw_stream.getvalue().decode("utf-8")),
        delimiter=delimiter,
        encoding="utf-8",
    )
    print("Created dataframe from filestream")
    return df


def gs_rename_blob(bucket_name, blob_name, new_name):
    """
    Rename a specified blob in a specified google bucket.

    bucket_name == "my_bucket"
    blob_name == "path/to/file/in/bucket/old_name.txt"
    new_name == "path/to/file/in/bucket/new_name.txt"
    """

    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(blob_name)

    new_blob = bucket.rename_blob(blob, new_name)
    print(f"Blob {blob.name} was renamed to {new_blob.name}")


def gs_list_blobs(bucket, prefix, delimiter=None, loud=False):
    storage_client = storage.Client()
    r_blobs = storage_client.list_blobs(bucket, prefix=prefix, delimiter=delimiter)
    blobs = []
    if loud:
        print("Blobs:")
    for blob in r_blobs:
        blobs.append(blob)
        if loud:
            print(blob.name)
    if delimiter:
        if loud:
            print("Prefixes:")
            for prefix in blob.prefixes:
                print(prefix)
    return blobs


def gs_upload_blob_from_stream(bucket_name, destination_blob_name, file_obj):
    """upload from a stream to a file in the bucket."""
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)
    file_obj.seek(0)
    blob.upload_from_file(file_obj)
    print(f"Stream data uploaded to {destination_blob_name} in bucket {bucket_name}")


def gs_dataframe_to_bucket(df, target_file, delimiter=","):
    """Downloads a file from a bucket and converts to pandas.DataFrame, defaults to csv. pass it a full bucket path and it will strip down to the blob name."""
    parts = target_file.replace("gs://", "").split("/")
    target_blob = "/".join(parts[1::])
    bucket = parts[0]
    stream = io.StringIO()
    df.to_csv(stream, sep="\t", index=False, encoding="utf-8")
    gs_upload_blob_from_stream(bucket, target_blob, new_tsv)
