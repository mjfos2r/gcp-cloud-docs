def gs_download_to_stream(bucket_name, source_blob_name, file_obj):
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

def gs_dataframe_from_bucket(bucket_name, source_blob_name, delimiter=","):
    """Downloads a file from a bucket and converts to pandas.DataFrame, defaults to csv"""
    io_obj = io.BytesIO()
    raw_stream = gs_download_to_stream(bucket_name, source_blob_name, io_obj)
    raw_stream.seek(0)
    file_content = raw_stream.getvalue().decode('utf-8')
    df = pandas.read_csv(io.StringIO(file_content), delimiter=delimiter, encoding='utf-8')
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

def gs_upload_blob_from_stream(bucket_name, file_obj, destination_blob_name):
    """upload from a stream to a file in the bucket."""
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)
    file_obj.seek(0)
    blob.upload_from_file(file_obj)
    print(f"Stream data uploaded to {destination_blob_name} in bucket {bucket_name}")

