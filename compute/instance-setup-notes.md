# Google Cloud Compute Notes
Assuming we've set up and instantiated our VM, here's how we set up the dev environment.
```bash
sudo apt update
sudo apt list --upgradable
sudo apt upgrade
sudo apt install gh git tmux htop dos2unix
gh auth login
gh auth setup-git
git config --global user.email "<email here>"
git config --global user.name "Michael J. Foster"
git config --global --type bool push.autoSetupRemote true

# This is not needed when using a GPU node but I will keep it here for docker container creation at a later date
mkdir -p ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
rm -rf ~/miniconda3/miniconda.sh
bash ~/miniconda3/bin/conda init bash
source ~/.profile
conda config --add channels conda-forge &&
conda config --add channels bioconda &&
conda install mamba

wget https://cdn.oxfordnanoportal.com/software/analysis/dorado-0.5.2-linux-x64.tar.gz &&
tar -xzvf dorado-0.5.2-linux-x64.tar.gz
sudo mv dorado-0.5.2-linux-x64/bin/dorado /usr/local/bin/dorado &&
sudo mv dorado-0.5.2-linux-x64/lib/* /usr/local/lib/

curl -L https://github.com/lh3/minimap2/releases/download/v2.26/minimap2-2.26_x64-linux.tar.bz2 | tar -jxvf -
sudo mv minimap2-2.26_x64-linux/minimap2 /usr/local/bin &&
sudo mv minimap2-2.26_x64-linux/k8 /usr/local/bin &&
sudo mv minimap2-2.26_x64-linux/paftools.js /usr/local/bin &&
sudo mv minimap2-2.26_x64-linux/minimap2.1 /usr/share/man/man1/

ls -l /dev/disk/by-id/google-*
sudo mkdir -p /mnt/disks/nanopore-assembly
sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/nvme0n2
sudo mount -o discard,defaults /dev/nvme0n2 /mnt/disks/nanopore-assembly/ && chmod a+w /mnt/disks/nanopore-assembly/
sudo chmod a+w /mnt/disks/nanopore-assembly/
cd /mnt/disks/nanopore-assembly/
git clone https://github.com/mjfos2r/borrelia_nanopore_assembly.git

cd borrelia_nanopore_assembly/snakemake/
conda create --name assembly
mamba update -f assembly_env.yml
conda activate
```

## !! This was prior to (semi)-abandoning snakemake and converting to docker containers for everything

This requires considerable revision!
