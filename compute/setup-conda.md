# Let's set up conda on our fresh VM
Until I figure out how to simply use a container and give it full filesystem access, this will have to suffice. I will eventually script this for ease of use.

Anyway, once we've logged into our instance, let's download the conda installation script to our home directory. (This probably needs to be done at system level by root if multiple people are to use this instance. `{{TODO: FIX.}} <<- in prog. see below.`)

***
## User level setup!
1.First things first, let's download the installer. Grab the checksum for the specific installer from anaconda's repo.

Currently, the `sha256sum` is `4766d85b5f7d235ce250e998ebb5a8a8210cbd4f2b0fea4d2177b3ed9ea87884`

```bash
export CHECKSUM_TMP="4766d85b5f7d235ce250e998ebb5a8a8210cbd4f2b0fea4d2177b3ed9ea87884"
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O- | \
    tee /tmp/Miniconda3-latest-Linux-x86_64.sh | \
    sha256sum | grep -q "$CHECKSUM_TMP" && echo "File OK! Checksum valid." || \
    { echo "ERROR: FILE CORRUPTED! Checksum validation failed!"; rm /tmp/Miniconda3-latest-Linux-x86_64.sh; exit 1; }
```

If everything is correct, continue with installation, otherwise redownload and try again.
> Commands for manual download and checksum validation.
> ```bash
> wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
> echo "4766d85b5f7d235ce250e998ebb5a8a8210cbd4f2b0fea4d2177b3ed9ea87884 Miniconda3-latest-Linux-x86_64.sh" >checksum.sha
> sha256sum -c checksum.sha
> ```

***
2.Now we need to run the installer. use the following command to install miniconda3 to the path: `/home/<your_username>/miniconda3`.
Command:
`bash ~/Miniconda3-latest-Linux-x86_64.sh`
Which runs the entire installation script. Agree to the license that you definitely read ;) and then install to whatever prefix you desire. Instructions below are relative to the default location so adapt accordingly.

3.Now we have to restart our active shell.
`source ~/.profile`

4.Now we need to add two essential channels to pull packages from!

```bash
conda config --add channels conda-forge \
    && conda config --add channels bioconda \
    && conda install mamba
```
5.Now cleanup the installer script (and checksum file if applicable)

```bash
rm -rf ~/Miniconda3-latest-Linux-x86_64.sh # && rm checksum.sha # if manually checked from above
```

***

## Systemwide setup

This is a bit more involved but is the best way to create a centralized conda installation that allows everyone to share environments and reduce disk usage of duplicate tools.

aight, let's flex them sysadmin muscles.

1.First we need to create a usergroup that will be able to use conda without sudo.

```bash
sudo groupadd conda-users
sudo usermod -a -G conda-users <username>
```

2.Now we make our shared systemwide directory using best practices gleaned from [filesystem hiearchy definition](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard)

We are going to put our conda installation into `/usr/local/miniconda3` as this is the best practice for manually installed system-wide software.

- we want to separate our conda installation from the software installed by apt.
- we want to separate our conda installation from the python installed by apt.
- we want to separate our packages and envs from the ones installed by apt's pip

>>(**lookatmeimthepackagemanagernow.png**)

Anyway here are the commands:

```bash
# Remember to use the current sha256 checksum!
export CHECKSUM_TMP="4766d85b5f7d235ce250e998ebb5a8a8210cbd4f2b0fea4d2177b3ed9ea87884"
# Download and verify in one fell swoop.
wget -O- https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh | \
    tee /tmp/miniconda3/Miniconda3-latest-Linux-x86_64.sh | \
    sha256sum | grep -q "$CHECKSUM_TMP" && echo "File OK! Checksum valid." || \
    { echo "Checksum validation failed!"; rm /tmp/Miniconda3-latest-Linux-x86_64.sh; exit 1; }
```

3.Now we install it if everything worked out!

```bash
sudo sh /tmp/Miniconda3-latest-Linux-x86_64.sh -b -p /usr/local/miniconda3
```

4.Now we need to wrangle the permissions!
We need to set the owner of `/usr/local/miniconda3` to `root:conda-users` and then give everyone in the group write permissions as well as save permissions.

```bash
sudo chown -R root:conda-users /usr/local/miniconda3
sudo chmod -R g+w /usr/local/miniconda3
sudo chmod g+s /usr/local/miniconda3/envs
```

5.Now we just have to configure conda!
We're going to add a directory within `/etc/` where the config will reside!
We are going to make a global `condarc` file and specify where the envs and packages will reside.

```bash
sudo mkdir -p /etc/conda
# set up the directory locations
sudo tee /etc/conda/condarc <<EOF
envs_dirs:
  - /usr/local/miniconda3/envs
pkgs_dirs:
  - /usr/local/miniconda3/pkgs
EOF
```

6.Now we're going to add the conda script to the global `/etc/profile.d`

```bash
sudo tee /etc/profile.d/conda.sh <<EOF
export CONDA_ROOT=/usr/local/miniconda3
export PATH=\$CONDA_ROOT/bin:\$PATH
. \$CONDA_ROOT/etc/profile.d/conda.sh
EOF
```

7.Restart your terminal and log back in to check whether or not it worked! If it didn't, call Michael :)
!! Also !!
Don't forget to add conda-forge and bioconda to the channels list as well as install mamba!!

```bash
conda config --add channels conda-forge \
    && conda config --add channels bioconda \
    && conda install mamba
```

***
`{{TODO: script this and add it to gcloud to use as a startup script when spinning up new instances}}`
***
#>>{MJF - 2025-Feb-13}<<#