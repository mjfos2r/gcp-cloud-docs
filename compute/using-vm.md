# Let's get the `vm.sh` script set up and set up the vm for use!

So the provided script, vm.sh, is a handy helper script I wrote to make using GCP instances much easier.

Once it's downloaded, save the file to a location on your path. alternatively, create a directory for useful scripts and add that to your path. I will give the commands for the latter:

*BEFORE DOING THE FOLLOWING, AFTER DOWNLOADING THE SCRIPT: `vm.sh`, BE SURE TO CHANGE THE VALUE ON LINE #7 TO REFLECT YOUR DESIRED PROJECT. I WILL ADAPT IT TO ACCEPT PROJECTS SOMETIME SOON BUT UNTIL THEN IT NEEDS TO BE HARD CODED!!!*

1.create a scripts folder and add it to your path!

```bash
mkdir ~/scripts \
    && cp vm.sh ~/scripts/ \
    && echo "PATH=$PATH:$HOME/scripts" >> ~/.zshrc
```

2.Now add an alias for the script so that you don't have to call vm.sh every time.

-My personal preference is to type `vm` instead of `vm.sh`
-that's done simply by adding an alias to your `.zshrc` file.

```bash
echo 'alias vm="vm.sh"' >>.zshrc
```

3.Now it's ready to be used. Restart your terminal and test that it works.

First off, make sure that the command is working just by typing in `vm` which should return the usage statement.

Now let's make sure that it can list the available instances by running `vm -l`

4.Connect to the desired instance and add yourself to the `conda-users` usergroup.

```bash
# on local shell
vm -c ram-optimized
...
# on remote shell (in same terminal)
whoami
sudo usermod -a -G conda-users <username>
exit
```

5.Restart your terminal and check that conda is accessible and functional.

```bash
# on local shell
vm -c ram-optimized
...
# on remote shell
conda activate
conda info
mamba info
exit
```

5a. If we are using jupyterhub and want to use kernels from conda environments, we need to install the following package into the base env.

```bash
conda install -n base -c conda-forge nb_conda_kernels
```

And this should allow jupyterhub to identify ipynb kernels within each environment.

*Make sure that ipykernel is installed to EACH environment you wish to use with jupyterhub.*

6.Cool! Now that you're set up to use conda. You can use jupyterlab functionality with the helper script.

This is essential to being able to connect using jupyter easily.

```bash
# on local shell
vm -j ram-optimized
```
Take the url that appears in the terminal output and use jupyter as usual!

7. Okay, so now we have to activate our environment and start the ipykernel.\

This is an example of creating a new env and setting up the kernel.

```bash
conda create -n my_env python=3.10 -y
conda activate my_env
conda install -c conda-forge ipykernel
python -m ipykernel install --user --name=my_env --display-name "Python (my_env)"
```

Restart the server to allow the kernel to be found!

```bash
sudo systemctl restart jupyterhub
```

***
#>>{MJF - 2025-Feb-13}<<#