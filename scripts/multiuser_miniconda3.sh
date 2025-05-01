cd /opt
sudo mkdir -p miniconda3
sudo wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /opt/miniconda3/miniconda.sh
sudo bash /opt/miniconda3/miniconda.sh -b -u -p /opt/miniconda3
sudo rm -rf /opt/miniconda3/miniconda.sh

sudo chgrp -R /opt/miniconda3
sudo chmod 770 -R  /opt/miniconda3
sudo adduser mf019 conda-users
sudo adduser mahassani conda-users
...
