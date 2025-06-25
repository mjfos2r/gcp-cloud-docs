import os
import re
import argparse
import magic
from google.cloud import billing_v1
from google.auth.credentials import AnonymousCredentials
from google.api_core.client_options import ClientOptions


# I need to either fix this or wipe it. I can't bring myself to wipe it but I
# also cannot be bothered to fix it so here it sits.
class GCSFuseOperations:
    def __init__(self):
        self.class_a = 0
        self.class_b = 0
        self.free_ops = 0

    def add_operation(self, operation, count=1):
        if operation == 'A':
            self.class_a += count
        elif operation == 'B':
            self.class_b += count
        else:
            self.free_ops += count

    def total(self):
        return self.class_a + self.class_b

def get_gcs_pricing():
    client_options = ClientOptions(
        api_endpoint='cloudbilling.googleapis.com'
    )
    client = billing_v1.CloudCatalogClient(
        credentials=AnonymousCredentials(),
        client_options=client_options
    )

    request = billing_v1.ListServicesRequest(
        parent='services/',
    )
    services = client.list_services(request=request)

    gcs_service = next((service for service in services if service.display_name == "Cloud Storage"), None)
    if not gcs_service:
        print("Cloud Storage service not found")
        return None

    request = billing_v1.ListSkusRequest(
        parent=gcs_service.name,
    )
    skus = client.list_skus(request=request)

    pricing = {
        'class_a': None,
        'class_b': None
    }

    for sku in skus:
        if 'Class A' in sku.description:
            pricing['class_a'] = sku.pricing_info[0].pricing_expression.tiered_rates[0].unit_price.nanos / 1e11
        elif 'Class B' in sku.description:
            pricing['class_b'] = sku.pricing_info[0].pricing_expression.tiered_rates[0].unit_price.nanos / 1e11

        if all(pricing.values()):
            break

    return pricing

def estimate_file_operations(file_path):
    file_type = magic.from_file(file_path)

    if "Python script" in file_type:
        return estimate_python_operations(file_path)
    elif "shell script" in file_type.lower():
        return estimate_shell_operations(file_path)
    elif "ELF" in file_type:
        return estimate_binary_operations(file_path)
    else:
        print(f"Unsupported file type: {file_type}")
        return None

def estimate_python_operations(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    ops = GCSFuseOperations()

    # storage.objects.list
    ops.add_operation('A')

    # Estimate operations based on Python function calls
    ops.add_operation('A', len(re.findall(r'\bos\.listdir\s*\(', content)))

    mkdir_count = len(re.findall(r'\bos\.mkdir\s*\(', content))
    ops.add_operation('B', 2 * mkdir_count)  # storage.objects.get for directory and directory/
    ops.add_operation('A', mkdir_count)  # storage.objects.insert for directory/

    file_ops_count = len(re.findall(r'\bopen\s*\(', content))
    ops.add_operation('B', 2 * file_ops_count)  # storage.objects.get for file and file/
    ops.add_operation('A', 2 * file_ops_count)  # storage.objects.insert for empty object and when closing

    remove_count = len(re.findall(r'\bos\.remove\s*\(', content))
    ops.add_operation('A', remove_count)  # storage.objects.list
    ops.add_operation('free', remove_count)  # storage.objects.delete

    return ops

def estimate_shell_operations(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    ops = GCSFuseOperations()

    # storage.objects.list
    ops.add_operation('A')

    # Estimate operations based on shell commands
    ls_count = len(re.findall(r'\bls\b', content))
    ops.add_operation('A', ls_count)  # storage.objects.list for each ls

    mkdir_count = len(re.findall(r'\bmkdir\b', content))
    ops.add_operation('B', 2 * mkdir_count)  # storage.objects.get for directory and directory/
    ops.add_operation('A', mkdir_count)  # storage.objects.insert for directory/

    cp_count = len(re.findall(r'\bcp\b', content))
    ops.add_operation('B', 2 * cp_count)  # storage.objects.get for file and file/
    ops.add_operation('A', 2 * cp_count)  # storage.objects.insert for empty object and when closing

    rm_count = len(re.findall(r'\brm\b', content))
    ops.add_operation('A', 3 * rm_count)  # storage.objects.list (3 times per rm operation)
    ops.add_operation('free', 2 * rm_count)  # storage.objects.delete (2 times per rm operation)

    return ops

def estimate_binary_operations(file_path):
    # This is still a simplified estimation for binary files
    file_size = os.path.getsize(file_path)

    ops = GCSFuseOperations()
    estimated_ops = file_size // 1024  # Assume one operation per 1KB

    ops.add_operation('A', estimated_ops // 2)
    ops.add_operation('B', estimated_ops // 2)

    return ops

def estimate_gcsfuse_operations(file_path):
    operations = estimate_file_operations(file_path)
    if operations is None:
        return

    print(f"\nEstimated GCSFuse operations for {file_path}:")
    print(f"Class A operations: {operations.class_a}")
    print(f"Class B operations: {operations.class_b}")
    print(f"Free operations: {operations.free_ops}")
    print(f"Total billable operations: {operations.total()}")

    # Fetch current pricing
    pricing = get_gcs_pricing()
    if pricing:
        class_a_cost = operations.class_a * pricing['class_a'] / 100000
        class_b_cost = operations.class_b * pricing['class_b'] / 100000
        total_cost = class_a_cost + class_b_cost

        print(f"\nEstimated cost (based on current pricing):")
        print(f"Class A operations: ${class_a_cost:.6f}")
        print(f"Class B operations: ${class_b_cost:.6f}")
        print(f"Total cost: ${total_cost:.6f}")
    else:
        print("\nUnable to fetch current pricing. Using default estimates.")
        class_a_cost = operations.class_a * 0.05 / 100000  # $0.05 per 100,000 Class A operations
        class_b_cost = operations.class_b * 0.004 / 100000  # $0.004 per 100,000 Class B operations
        total_cost = class_a_cost + class_b_cost

        print(f"\nEstimated cost (using default pricing):")
        print(f"Class A operations: ${class_a_cost:.6f}")
        print(f"Class B operations: ${class_b_cost:.6f}")
        print(f"Total cost: ${total_cost:.6f}")

def main():
    parser = argparse.ArgumentParser(description="Estimate GCSFuse operations for a program.")
    parser.add_argument("file_path", help="Path to the program file")
    args = parser.parse_args()

    estimate_gcsfuse_operations(args.file_path)

if __name__ == "__main__":
    main()
