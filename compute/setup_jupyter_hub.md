# Systemwide Jupyter Installation and Configuration

#>>{ mjf - 2025-feb-14 }<<#

## Let's set up jupyterhub/jupyterlab so that multiple people can use it simultaneously. this is not compatible with conda installations of jupyter regardless of how it is installed.

This forces us to use apt to manage this. We're going to hope that this doesn't break too much.
The vm.sh script also won't be able to find the jupyter env? maybe? we'll see.

1. So first we need to make sure we've updated apt and then install the packages: `python3-full python3-venv nodejs npm pipx`

    ```bash
    sudo apt-get update
    sudo apt-get install -y python3-venv nodejs npm
    ```

2. Now lets init a systemwide venv.

    ```bash
    sudo python3 -m venv /opt/jupyterhub
    ```

3. Now to activate the venv and install jupyterhub and jupyterlab as well as nativeauthenticator for easier login to the hub.

    ```bash
    sudo /opt/jupyterhub/bin/pip install jupyterhub jupyterlab jupyterhub-nativeauthenticator
    sudo npm install -g configurable-http-proxy
    ```

4. We also need to add it to everyone's path

    ```bash
    sudo bash -c 'cat > /etc/profile.d/jupyterhub.sh << EOF
    export PATH="/opt/jupyterhub/bin:$PATH"
    EOF'
    ```

5. systemd needs a service defined. let's do that now.

    First, let's create the file via `sudo vim /etc/systemd/system/jupyterhub.service` using a text editor and add the following text.

    ```ini
    [Unit]
    Description=JupyterHub
    After=network.target

    [Service]
    User=root
    Environment="PATH=/opt/jupyterhub/bin:/usr/bin:/usr/local/bin:/usr/lib/node_modules/.bin:/usr/local/miniconda3/bin"
    ExecStart=/opt/jupyterhub/bin/jupyterhub -f /etc/jupyterhub/jupyterhub_config.py
    WorkingDirectory=/etc/jupyterhub

    [Install]
    WantedBy=multi-user.target
    ```

    Exit vim via the following key combination: `:wq`

    ```bash
    "<shift> + ;" # to get the colon
    "wq"
    "<enter>"
    ```

6. Now we gotta make the config file and systemd service to point to our installations!

    ```bash
    sudo mkdir -p /etc/jupyterhub
    cd $_
    sudo /opt/jupyterhub/bin/jupyterhub --generate-config
    ```

6a. Oh we also need to create `/usr/local/share/jupyter` so that we can install kernels for individual conda envs.

    ```bash
    sudo mkdir -p /usr/local/share/jupyter/kernels
    # and change perms to be accessible to everyone in the conda-users group
    sudo chown -R :conda-users /usr/local/share/jupyter
    # and add all the perms (USING SETGID TO ENSURE ALL NEW DIRS AND FILES ARE WITH THE SAME GLOBAL GROUP PERMS!)
    sudo chmod -R g+w /usr/local/share/jupyter
    sudo chmod -R g+s /usr/local/share/jupyter
    ```

7. groovy, now let's configure our config. open it in a text editor and update the following settings.

    We need to set the IP, port, and also make sure the memlimit is unrestricted.
    We also are going to change our port to the default used by `vm.sh` which is `8888`.

    We're also going to need to add approved users.
    Find the list of users with the following commands:

    ```bash
    # returns just users
    getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}'
    # returns more info
    getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {printf "Username: %s\tUID: %s\tHome: %s\n", $1, $3, $6}'
    ```

    ```python
    # Basic settings
    c.JupyterHub.ip = '0.0.0.0'
    c.JupyterHub.port = 8888

    # Use JupyterLab interface by default
    c.Spawner.default_url = '/lab'

    # Use system PAM authenticator
    c.JupyterHub.authenticator_class = 'jupyterhub.auth.PAMAuthenticator'

    # define allowed users
    c.Authenticator.allowed_users = { 'as3256', 'blk18', 'mahassani', 'mh057', 'kotzen', 'rl275', 'mfoster11', 'mf019', 'bkotzen'}

    # Users' server will find conda
    c.Spawner.env_keep = ['PATH', 'PYTHONPATH', 'CONDA_ROOT', 'CONDA_DEFAULT_ENV', 'VIRTUAL_ENV', 'LANG', 'LC_ALL']

    # Each user gets their home directory as workspace
    c.Spawner.notebook_dir = '/home/{username}'

    # Keep this as is to prevent memory issues
    c.Spawner.mem_limit = None
    ```

8. Okay now we can restart systemd and add the service.

    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable jupyterhub
    sudo systemctl start jupyterhub
    # check status
    sudo systemctl status jupyterhub
    ```

9. Before we can use jupyterhub, we need to create a password for ourselves. (Unless you've already done this!)

    ```bash
    sudo passwd <username>
    ```

10. Now this should be functional! Let's test it out!

    ```bash
    vm -j ram-optimized
    ```

Connect to the [url provided](0.0.0.0:8888) and then log in with your username and the password you just set!