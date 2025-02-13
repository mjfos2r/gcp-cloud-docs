# Let's get the `vm.sh` script set up and set up the vm for use!

So the provided script, vm.sh, is a handy helper script I wrote to make using GCP instances much easier.

Once it's downloaded, save the file to a location on your path. alternatively, create a directory for useful scripts and add that to your path. I will give the commands for the latter:

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
sudo usermod -a -G conda-users $(whoami)
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

6.Cool! Now that you're set up to use conda. You can use jupyterlab functionality with the helper script.

This is essential to being able to connect using jupyter easily.

```bash
# on local shell
vm -j ram-optimized
```
Take the url that appears in the terminal output and use jupyter as usual!

***
#>>{MJF - 2025-Feb-13}<<#