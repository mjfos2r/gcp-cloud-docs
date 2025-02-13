#!/bin/zsh
# Michael J. Foster
# github.com/mjfos2r
# 2025-Feb-13

# Until I add the flag to specify project_id, hardcode it here.
PROJECT="<PROJECT_ID_GOES_HERE>"

function usage() {
    echo "Usage: $0 [-h] [-l] [-p port] [-1 | -0 | -c | -j | -d] <instance>"
    echo "This is a simple helper script to start and stop gcloud instances. "
    echo "Options: "
    echo "          -h                           Show this help message "
    echo "          -l                           List instances"
    echo "          -d <instance>                Describe instance"
    echo "          -1                           Start instance"
    echo "          -0                           Stop instance"
    echo "          -c                           Connect to instance"
    echo "          -j                           Connect to instance with port forwarding (jupyter server)"
    echo "          -p <port>                    Specify custom port (default: 8888)"
    echo "          <instance>                   Name of Instance"
}
# Check for no arguments
if [[ $# -eq 0 ]]; then
    echo "Error: Please provide an argument" >&2
    usage
    exit 1
fi

# Initialize default port
PORT=8888

# Check for port argument
if [[ "$1" == "-p" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Error: -p requires a port number" >&2
        usage
        exit 1
    fi
    PORT=$2
    shift 2
fi

# Handle single argument cases
if [[ $# -eq 1 ]]; then
    case $1 in
        "-h")
            usage
            exit 0
            ;;
        "-l")
            gcloud compute instances list --project "$PROJECT"
            exit 0
            ;;
        *)
            usage
            echo "ERROR: Please specify either -h for usage, -l to list all available instances, or include both an action and instance name" >&2
            exit 2
            ;;
    esac
fi
# Handle two argument cases
if [[ $# -eq 2 ]]; then
    # Validate argument order
    if [[ $2 =~ ^- ]]; then
        usage
        echo "ERROR: Instance name should be the second argument, not an option" >&2
        exit 2
    fi

#    ZONE="--zone=us-central1-a"
# !!TODO: Rewrite argparsing using getopts for positional flexibility.
    case $1 in
        "-d")
            INSTANCE=$2
            echo "Describing gcp instance: $INSTANCE"
            exec gcloud compute instances describe "$INSTANCE"
            ;;
        "-1")
            INSTANCE=$2
            echo "Starting gcp instance: $INSTANCE"
            exec gcloud compute instances start --project "$PROJECT" "$INSTANCE"
            ;;
        "-0")
            INSTANCE=$2
            echo "Stopping gcp instance: $INSTANCE"
            exec gcloud compute instances stop --project "$PROJECT" "$INSTANCE"
            ;;
        "-c")
            INSTANCE=$2
            echo "Connecting to gcp instance: $INSTANCE"
            exec gcloud compute ssh --project "$PROJECT" "$INSTANCE" --internal-ip
            ;;
        "-j")
            INSTANCE=$2
            echo "Connecting to gcp instance: $INSTANCE with port forwarding!"
            echo "Initializing jupyter-lab server!"
            REMOTE_CMD='
              echo "Current PATH: $PATH"
              echo "Sourcing conda..."
              source $(find ~ -type f -wholename "*/miniconda3/etc/profile.d/conda.sh")
              echo "Activating conda base..."
              conda activate base
              echo "Conda environment: $CONDA_PREFIX"
              echo "Which jupyter-lab: $(which jupyter-lab)"
              echo "Starting jupyter-lab..."
              jupyter-lab --no-browser --port='$PORT
            exec gcloud compute ssh --project "$PROJECT" "$INSTANCE" --internal-ip \
                -- -L ${PORT}:localhost:${PORT} \
                "/bin/bash -l -c '$REMOTE_CMD'"
            ;;
        *)
            usage
            echo "ERROR: Invalid action specified. Please use -1, -0, -d, -c, or -j" >&2
            exit 2
            ;;
    esac
fi
# If we get here, too many arguments were provided
usage
echo "ERROR: Too many arguments provided" >&2
exit 2
