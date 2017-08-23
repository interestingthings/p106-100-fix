# p106-100-fix
quick fix for smos to support new Nvidia cards. Only for testing.

## Installation:

clone repo

`sudo apt update && sudo apt install git-core`

`git clone https://github.com/kusayuzayushko/p106-100-fix.git`

`cd p106-100-fix`

become root

`sudo su`

copy grub to /etc/default/grub, oc_nv.sh to /root/utils/oc_nv.sh and rclocal.sh to /root/utils/rclocal.sh

`cp grub /etc/default/`

`cp oc_nv.sh /root/utils`

`cp rclocal.sh /root/utils`

maybe make scripts executable by running

`chmod +x /root/utils/oc_nv.sh /root/utils/rclocal.sh`

`reboot`
