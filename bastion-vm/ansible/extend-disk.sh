(echo n;echo p;echo 3;echo ;echo ;echo t;echo 3;echo 8e;echo w) | fdisk /dev/sda > /dev/null 2>&1; fdisk -l /dev/sda
partprobe
pvcreate /dev/sda3
vgextend rhel /dev/sda3
vgdisplay -v
lvextend -l +100%FREE /dev/rhel/root
xfs_growfs  /dev/rhel/root