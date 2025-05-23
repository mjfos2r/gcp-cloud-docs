#!/bin/zsh
# Michael J. Foster
# github.com/mjfos2r
# 2025-Feb-25

# if anything breaks crash out.
set -euo pipefail

# Instead of hardcoding the project_id, let's just pull it from the environment 
# (so we can specify alternative projects or grab the default from gcloud)
PROJECT="${GOOGLE_CLOUD_PROJECT:-"$(gcloud config get-value project)"}"
echo "Current GCP Project: ${PROJECT}"

function usage() {
    echo "Usage: $0 [options] [instance]"
    echo "This is a simple helper script to start and stop gcloud instances."
    echo "Options:"
    echo "  -h                Show this help message"
    echo "  -l                List instances"
    echo "  -d                Describe instance"
    echo "  -1                Start instance"
    echo "  -0                Stop instance"
    echo "  -c                Connect to instance"
    echo "  -j                Connect to instance with port forwarding (jupyter server)"
    echo "  -p PORT           Specify custom local port (default: 8888)"
    echo "  -r REMOTE_PORT    Specify custom remote port (default: same as local port)"
    echo "  -i INSTANCE       Name of instance (can also be specified as last argument)"
    echo "  -v                Verbose mode [! Requires -j !] (show jupyterhub terminal output)"
    echo " "
    echo "!! This script will pull the default project from \$(gcloud config get-value project) !!"
    echo "If you have multiple projects, set the 'GOOGLE_CLOUD_PROJECT' variable and try again"
    echo " "
    echo "Command: export GOOGLE_CLOUD_PROJECT='my-project-id'"
}

# Initialize default values
ACTION=""
INSTANCE=""
LOCAL_PORT=8888
REMOTE_PORT=""  # Will default to LOCAL_PORT if not specified
VERBOSE=false   # Control whether to show jupyterhub terminal output

# Parse command line options
while getopts ":hld10cjp:r:i:v" opt; do
    case ${opt} in
        h)
            usage
            exit 0
            ;;
        l)
            ACTION="list"
            ;;
        d)
            ACTION="describe"
            ;;
        1)
            ACTION="start"
            ;;
        0)
            ACTION="stop"
            ;;
        c)
            ACTION="connect"
            ;;
        j)
            ACTION="jupyter"
            ;;
        p)
            LOCAL_PORT=$OPTARG
            ;;
        r)
            REMOTE_PORT=$OPTARG
            ;;
        i)
            INSTANCE=$OPTARG
            ;;
        v)
            VERBOSE=true
            ;;
        \?)
            echo "Error: Invalid option: -$OPTARG" >&2
            usage
            exit 1
            ;;
        :)
            echo "Error: Option -$OPTARG requires an argument" >&2
            usage
            exit 1
            ;;
    esac
done

# Shift to the non-option arguments
shift $((OPTIND - 1))

# Check if instance name was provided as positional argument
if [[ -z "$INSTANCE" && $# -eq 1 ]]; then
    INSTANCE=$1
elif [[ -z "$INSTANCE" && $# -gt 1 ]]; then
    echo "Error: Too many arguments provided" >&2
    usage
    exit 2
fi

# If REMOTE_PORT is not set, use LOCAL_PORT
if [[ -z "$REMOTE_PORT" ]]; then
    REMOTE_PORT=$LOCAL_PORT
fi

# Validate arguments
if [[ -z "$ACTION" ]]; then
    echo "Error: No action specified" >&2
    usage
    exit 1
fi

# List action doesn't need instance name
if [[ "$ACTION" != "list" && -z "$INSTANCE" ]]; then
    echo "Error: Instance name required for action: $ACTION" >&2
    usage
    exit 1
fi

# Execute the requested action
case $ACTION in
    "list")
        gcloud compute instances list --project "$PROJECT"
        ;;
    "describe")
        echo "Describing gcp instance: $INSTANCE"
        gcloud compute instances describe "$INSTANCE"
        ;;
    "start")
        echo "Starting gcp instance: $INSTANCE"
        gcloud compute instances start --project "$PROJECT" "$INSTANCE"
        ;;
    "stop")
        echo "Stopping gcp instance: $INSTANCE"
        gcloud compute instances stop --project "$PROJECT" "$INSTANCE"
        ;;
    "connect")
        echo "Connecting to gcp instance: $INSTANCE"
        gcloud compute ssh --ssh-key-file ~/.ssh/mjf_id_2d25519-sk --project "$PROJECT" "$INSTANCE" --internal-ip
        ;;
    "jupyter")
        echo "Connecting to gcp instance: $INSTANCE with port forwarding!"
        echo "Local port: $LOCAL_PORT, Remote port: $REMOTE_PORT"
        if $VERBOSE; then
            echo "Verbose mode enabled: Jupyter terminal output will be shown"
        else
            echo "Verbose mode disabled: Jupyter terminal output will be suppressed"
        fi
        
        # check to see if jupyterhub is installed and available on our instance
        # if verbose flag is set and jupyterhub is installed, dump journalctl -u jupyterhub -f to stdout, else suppress to /dev/null
        # if it is not installed, init jupyerlab the single user way via conda (boo hiss!)
        REMOTE_CMD='
        if systemctl is-active jupyterhub >/dev/null 2>&1; then
            echo "JupyterHub is running at: http://localhost:'$LOCAL_PORT'"
            echo "Press Ctrl+C to disconnect when finished."
            trap "echo -e \"\nDisconnecting...\"; exit 0" INT
            if '$VERBOSE'; then
                echo "Terminal output for jupyterhub service:"
                journalctl -u jupyterhub -f
            else
                echo "Connect to JupyterHub using the URL provided above and login!"
                # Keep the connection open but without terminal spam
                tail -f /dev/null
            fi
        else
            echo "Initializing jupyter-lab server!"
            echo "Current PATH: $PATH"
            # Look for CONDA_EXE first.
            if [ -n "${CONDA_EXE:-}" ]; then
                eval "$(${CONDA_EXE} shell.bash hook)"
            else
                # if it aint set then hunt for conda.sh
                echo "CONDA_EXE not set, looking for conda.sh"
                CONDAINIT=$(find $HOME -type f -wholename "*/etc/profile.d/conda.sh" 2>/dev/null | head -n1)
                if [ -f "$CONDAINIT" ]; then
                    echo "Found $CONDAINIT"
                    source "$CONDAINIT"
                else
                    echo "ERROR: Could not locate conda on the remote VM!"
                    exit 1
                fi
            fi
            echo "Activating conda base..."
            conda activate base
            echo "Conda environment: $CONDA_PREFIX"
            echo "Which jupyter-lab: $(which jupyter-lab)"
            echo "Starting jupyter-lab..."
            jupyter-lab --no-browser --port='$REMOTE_PORT'
        fi'

        gcloud compute ssh --ssh-key-file ~/.ssh/mjf_id_2d25519-sk --project "$PROJECT" "$INSTANCE" --internal-ip \
            -- -L ${LOCAL_PORT}:localhost:${REMOTE_PORT} \
            "/bin/bash -l -c '$REMOTE_CMD'"
        ;;
esac
