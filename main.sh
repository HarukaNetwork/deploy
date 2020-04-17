#!/bin/bash

# Server Setup script, setup partitions and disks, installing byobu, parted, git and zsh

# Check if the Operation System have APT or not
# Assuming OS with apt is Debian/Ubuntu
# The code is very dirty though
# TO-DO: Need proper implementation in the futrue

LSB_RELEASE="$(lsb_release -d | cut -d ':' -f 2 | sed -e 's/^[[:space:]]*//')"
command -v apt > /dev/null
if [[ $? != 1 ]]; then
       if [[ ${LSB_RELEASE} =~ "Ubuntu" || ${LSB_RELEASE} =~ "Debian GNU/Linux" || ${LSB_RELEASE} =~ "Deepin" ]]; then
          # Install packages
          sudo apt install byobu git zsh parted gnupg2 -y
       else
          echo "Not installing byobu git zsh parted gnupg2, please install it manually."
          echo "This script is made for Debian/Ubuntu only, Aborting..."
          exit 0
       fi
else
       echo "Not installing byobu git zsh parted gnupg2, please install it manually."
       echo "This script is made for Debian/Ubuntu only, Aborting..."
       exit 0
fi

# Add users, and copy public keys
BASEDIR=$(dirname "$0")
for user in $(ls "$BASEDIR"/personal_setups); do
       useradd -m "$user"
       usermod -aG sudo "$user"
       chsh -s /bin/bash "$user"
       cp -R "$BASEDIR"/personal_setups/"$user"/. /home/"$user"/

       # Chown folder owner
       chown -R "$user":"$user" /home/"$user"

       # Give users "blank" encrypted password :D
       echo "$user":U6aMy0wojraho | sudo chpasswd -e

       # Edit file "/etc/pam.d/common-password"
       # From
       # password        [success=1 default=ignore]      pam_unix.so obscure sha512
       # To
       # password        [success=1 default=ignore]      pam_unix.so minlen=1 sha512

       # Make user change password on next login
       passwd -e "$user"
done

sed -i "s/^%sudo/# %sudo/" /etc/sudoers
echo "%sudo ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers
touch /var/lib/cloud/instance/warnings/.skip

# Initialize disks
uninit_dsks=$(lsblk -r --output NAME,MOUNTPOINT | awk -F / '/sd/ { dsk=substr($1,1,3);dsks[dsk]+=1 } END { for ( i in dsks ) { if (dsks[i]==1) print i } }')
dsks=()
for dsk in $uninit_dsks; do
	parted /dev/"$dsk" --script -- mklabel gpt mkpart primary 0% 100%
	dsks+=("/dev/${dsk}1")
done

NVME_DEV="/dev/nvme0n1"
if [ -e "$NVME_DEV" ]; then
	dsks+=("$NVME_DEV")
fi

sleep 5
echo y | mdadm --create --verbose --level=0 --metadata=1.2 --raid-devices=${#dsks[@]} /dev/md/drive "${dsks[@]}"
echo 'DEVICE partitions' >/etc/mdadm.conf
mdadm --detail --scan >>/etc/mdadm.conf
mdadm --assemble --scan
mkfs.ext4 /dev/md/drive
mkdir -p /workspace
mount /dev/md/drive /workspace

# Populate fstab
RAID_UUID=$(blkid -s UUID -o value /dev/md/drive)
echo -e "UUID=${RAID_UUID}\t/workspace\text4\trw,relatime,defaults\t0\t1" >>/etc/fstab

# Setup personal folder and chown it at /workspace
for user in $(ls "$BASEDIR"/personal_setups); do
       # Add changes to bashrc
       echo "export USE_CCACHE=1" >> /home/"$user"/.bashrc
       echo "export CCACHE_DIR=/workspace/$user/ccache" >> /home/"$user"/.bashrc
       echo "export SKIP_ABI_CHECKS=true" >> /home/"$user"/.bashrc
       echo "export TEMPORARY_DISABLE_PATH_RESTRICTIONS=true" >> /home/"$user"/.bashrc
       echo "ccache -M 350G" >> /home/"$user"/.bashrc

       # Make new folders
       mkdir /workspace/"$user"
       mkdir /workspace/"$user"/ccache

       # Chown folders owner
       chown -R "$user":"$user" /workspace/"$user"
       chown -R "$user":"$user" /home/"$user"
done

# Setting up environment for Android building

git config --global user.email "akito@evolution-x.org"
git config --global user.name "Akito Mizukito"
git clone https://github.com/realakito/script .setup_scripts
cd .setup_scripts || echo "Failed to cd to .setup_scripts . Are you sure git is installed?"; return
bash setup/android_build_env.sh
cd ../ || return

# Cleanup
rm -rf .android-scripts
