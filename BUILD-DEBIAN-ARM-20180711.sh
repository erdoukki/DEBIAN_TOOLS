#!/bin/bash

## BUILD-DEBIAN-ARM.sh
##

## Enjoy... 
## But,
## you may use at your own risks !

###
# HOW TO USE
###

# executer sans sudo avec la ligne de commande ./BUILD-DEBIAN-ARM.sh

###
# VERSIONS HISTORY
###

# Version 20180628-008
# Build Debian IMAGE for SD card system
# GPL
# 2014-2017 (c) G.KERMA
# 20151129 : GKE
# - refresh
# - jessie
# 20160930 : GKE
# - fixes
# 20170825 : GKE
# - 0.2-012 from 0.1-9
# 20180624 : GKE
# 001 - refresh
# 002 - Debian stretch & new Kernel Linux image armmp
# 003 - flash-kernel & MACHINEID
# 20180626 : GKE
# 005 - qemu-utils & u-boot-dtb.bin (custom)
# 006 - /boot ext4
# 20180628 : GKE
# 007 - non interactive fix for new linux kernel image install
# 007 - ajout du runtime
# 007 - ajout DEBUG et interactivemode (false = no question, true = activation des prompts)
# 008 - suppression du mode 64 bits du ext4 du FS de BOOT : KO (revert)
# 009 - /boot ext2
# 20180710 : GKE
# 001 - chroot generic fixes : OK
# 002 - eMMC fwenv
# 003 - /boot ext2 fixes
# 004 - need some fixes
# 20180711 : GKE
# 001 - quick generic fixes : OK

###
# PARAMS
###

# Définir les constantes
##export SDCARD=/dev/sdd

export DEBUG=true
export interactivemode=true

export WORKDIR=`pwd`/work
export CUSTDIR=`pwd`/custom

# ajouter le / finale dans TARGET
export TARGET=/mnt/target/

export MACADDR=AA:BB:CC:DD:EF:56
export TARGETHOST=DEBIANU3

export MACHINEID='Hardkernel ODROID-U3 board based on Exynos4412'

export DISTRIB=stretch
export DISTRIBUPG=stretch

export TARGETNAME=$TARGETHOST'-'$DISTRIB'_TST20180711-001'

export ROOTPASS=nosoup4u
export ARCH=armhf
export BASE_DISTRIB=http://http.debian.net/debian

export KERNEL_URL=http://builder.mdrjr.net/kernel-3.8/00-LATEST/odroidu2.tar.xz
export KERNEL_MD5=http://builder.mdrjr.net/kernel-3.8/00-LATEST/odroidu2.tar.xz.md5sum
export ADDON_URL=https://raw.githubusercontent.com/mdrjr/odroid-utility/master/odroid-utility.sh

export TARGETIMG=$TARGETNAME.IMG
export TARGETIMGSIZE=2G

# block size 512
export BOOTSIZE=3072
export ROOTSIZE=135168

# PROMPT de DEBUT
start=`date +%s`
echo "--- START @ `date`"

if $DEBUG ; then
  export interactivemode=true
else
  export interactivemode=false
fi

##echo DEVICE $SDCARD
echo TARGET $TARGET
echo WORKDIR $WORKDIR
echo ARCH $ARCH
echo DISTRIB $DISTRIB
echo TARGETIMG $TARGETIMG
if $interactivemode ; then
  read -p "START : Press any key to continue ..." -n1 -s
fi

###
# PREPARATION DU HOST
###

sudo apt-get update
sudo apt-get install -y qemu-user-static qemu-utils debootstrap u-boot-tools

###
# NETTOYAGE DES GARBAGES PRECEDENTS
###

sudo rm -vRf $TARGET
##sudo rm -vRf $WORKDIR

mkdir -v -p $WORKDIR
sudo chmod -Rv a+Xrw $WORKDIR
cd $WORKDIR

###
# PREPARATION DE LA CIBLE
###

qemu-img create -f raw $TARGETIMG $TARGETIMGSIZE

export TARGETDEV=`sudo losetup -v --show --find $TARGETIMG`
export BOOTDEV=`sudo losetup -v -o $((512*$BOOTSIZE)) $TARGETDEV --show --find $TARGETIMG`
export ROOTDEV=`sudo losetup -v -o $((512*$ROOTSIZE)) $TARGETDEV --show --find $TARGETIMG`

echo TARGETDEV $TARGETDEV
echo BOOTDEV $BOOTDEV
echo ROOTDEV $ROOTDEV

# PROMPT before delete partitions
if $interactivemode ; then
  read -p "BOOTLOADER FLASH : Press any key to continue ..." -n1 -s
fi

mkdir -v -p $WORKDIR/boot
cd $WORKDIR/boot
if [ -f $CUSTDIR/boot.tar ]
then
  cp $CUSTDIR/boot.tar $WORKDIR/boot/boot.tar
  sudo tar xvf $WORKDIR/boot/boot.tar
else
  rm $WORKDIR/boot/boot.tar.gz
  wget http://odroid.in/guides/ubuntu-lfs/boot.tar.gz -O $WORKDIR/boot/boot.tar.gz
  sudo tar zxvf $WORKDIR/boot/boot.tar.gz
fi
sudo chmod a+xrw -Rc $WORKDIR/boot/
sudo chmod a+x -Rc $WORKDIR/boot/boot/sd_fusing.sh 
cd $WORKDIR/boot/boot
sudo sh -c "$WORKDIR/boot/boot/sd_fusing.sh $TARGETDEV"
sudo sync

cd $WORKDIR
if [ -f $CUSTDIR/u-boot-dtb.bin ]
then
if $interactivemode ; then
    read -p "BOOTLOADER FLASH custom u-boot-dtb.bin found : Press any key to continue ..." -n1 -s
  fi
  sudo dd if=$CUSTDIR/u-boot-dtb.bin of=$TARGETDEV seek=63
else
  echo "u-boot-dtb.bin is missing ! The system may not bootup correctly ..."
fi

LC_ALL=C LANGUAGE=C LANG=C sudo fdisk -l $TARGETIMG

# PROMPT before delete partitions
if $interactivemode ; then
  read -p "PARTITION DELETE : Press any key to continue ..." -n1 -s
fi

cat << __EOF__ | LC_ALL=C LANGUAGE=C LANG=C sudo fdisk $TARGETIMG
o
w
__EOF__

sync
sudo partprobe

LC_ALL=C LANGUAGE=C LANG=C sudo fdisk -l $TARGETIMG

# PROMPT before MKFS
if $interactivemode ; then
  read -p "PARTITION CREATE : Press any key to continue ..." -n1 -s
fi

cat << __EOF__ | LC_ALL=C LANGUAGE=C LANG=C sudo fdisk $TARGETIMG
n
p
1
$BOOTSIZE
+64M
n
p
2
$ROOTSIZE

w
__EOF__

sync
sudo partprobe

LC_ALL=C LANGUAGE=C LANG=C sudo fdisk -l $TARGETIMG

# PROMPT before MKFS
if $interactivemode ; then
  read -p "FORMAT FS : Press any key to continue ..." -n1 -s
fi

# Préparation et tune du FS de BOOT
sudo mkfs.ext2 -L BOOT $BOOTDEV

sudo e2fsck -f $BOOTDEV
sudo e2label $BOOTDEV BOOT
sudo dumpe2fs $BOOTDEV | head

# Préparation et tune du FS de ROOT
sudo mkfs.ext4 -L ROOTFS $ROOTDEV

sudo tune2fs -o journal_data_writeback $ROOTDEV
sudo tune2fs -O ^has_journal $ROOTDEV
sudo e2fsck -f $ROOTDEV
sudo e2label $ROOTDEV ROOTFS
sudo dumpe2fs $ROOTDEV | head

###
# MONTAGE DE LA CIBLE
###

sudo mkdir -p -v $TARGET

sudo mount -v -t ext4 $ROOTDEV $TARGET
sudo mkdir -p -v $TARGET'boot'
sudo mount -v -t ext2 $BOOTDEV $TARGET'boot'

# PROMPT avant BUILDROOT
echo
if $interactivemode ; then
  read -p "debootstrap ? Press any key to continue ..." -n1 -s
fi

###
# INSTALLATION OS DE BASE
###

sudo qemu-debootstrap --foreign --arch=$ARCH $DISTRIB $TARGET $BASE_DISTRIB

sudo sh -c "echo 'T0:23:respawn:/sbin/getty -L ttySAC1 115200 vt100' >> $TARGET'etc/inittab'"

cat << __EOF__ | sudo tee $TARGET'etc/apt/sources.list'
# deb http://ftp.fr.debian.org/debian/ $DISTRIB main

deb http://ftp.fr.debian.org/debian/ $DISTRIB main contrib non-free
deb-src http://ftp.fr.debian.org/debian/ $DISTRIB main contrib non-free

deb http://security.debian.org/ $DISTRIB/updates main contrib non-free
deb-src http://security.debian.org/ $DISTRIB/updates main contrib non-free

# $DISTRIB-updates, previously known as 'volatile'
deb http://ftp.fr.debian.org/debian/ $DISTRIB-updates main contrib non-free
deb-src http://ftp.fr.debian.org/debian/ $DISTRIB-updates main contrib non-free
__EOF__

cat << __EOF__ | sudo tee $TARGET'etc/apt/sources.list.d/backports.list'
deb http://ftp.fr.debian.org/debian $DISTRIB-backports main contrib non-free
deb-src http://ftp.fr.debian.org/debian $DISTRIB-backports main contrib non-free
__EOF__

sudo sh -c "echo $TARGETHOST > $TARGET'etc/hostname'"

cat << __EOF__ | sudo tee $TARGET'etc/network/interfaces'
# The loopback network interface
auto lo
iface lo inet loopback
iface lo inet6 loopback

# eth0 network interface
auto eth0
allow-hotplug eth0
iface eth0 inet dhcp
__EOF__

cat << __EOF__ | sudo tee $TARGET'etc/sysctl.d/local.conf'
# automatic reboot on kernel panic (5 secs)
panic = 5

# disable IPv6
##net.ipv6.conf.all.disable_ipv6 = 1
##net.ipv6.conf.default.disable_ipv6 = 1
##net.ipv6.conf.lo.disable_ipv6 = 1
__EOF__

cat << __EOF__ | sudo tee $TARGET'etc/fstab'
LABEL=ROOTFS / ext4 errors=remount-ro,defaults,noatime,nodiratime 0 1
LABEL=BOOT /boot ext2 errors=remount-ro,defaults,noatime,nodiratime 0 1
tmpfs /tmp tmpfs nodev,nosuid,mode=1777 0 0

__EOF__


sudo sh -c "echo $MACADDR > $TARGET'etc/smsc95xx_mac_addr'"

###
# PREPARATION CIBLE INVITEE
###

sudo mount -t proc chproc $TARGET'proc'
sudo mount -t sysfs chsys $TARGET'sys'
sudo mount -t devtmpfs chdev $TARGET'dev' || mount --bind /dev $TARGET'dev'
sudo mount -t devpts chpts $TARGET'dev/pts'

echo '#!/bin/sh' | sudo tee $TARGET'usr/sbin/policy-rc.d'
echo 'exit 101' | sudo tee --append $TARGET'usr/sbin/policy-rc.d'
sudo chmod 755 $TARGET'usr/sbin/policy-rc.d'

sudo cp $(which qemu-arm-static) $TARGET'usr/bin'

DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET dpkg --configure -a

sudo wget $ADDON_URL -O $TARGET'usr/local/bin/odroid-utility.sh'
sudo chmod +x $TARGET'usr/local/bin/odroid-utility.sh'

DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET apt-get update

DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET apt-get install -y lsb-release initramfs-tools tzdata locales u-boot-tools ntp sudo openssh-server curl bash-completion fake-hwclock xz-utils

###
# OLD KERNEL HARDKERNEL LINUX IMAGE
###

##sudo wget $KERNEL_URL -O $TARGET'root/odroidu2.tar.xz'
##sudo wget $KERNEL_MD5 -O $TARGET'root/odroidu2.tar.xz.md5sum'
##LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET xz -d /root/odroidu2.tar.xz
##LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET tar xfv /root/odroidu2.tar

##sudo sh -c "cat $TARGET'etc/initramfs-tools/initramfs.conf' | sed s/'MODULES=most'/'MODULES=dep'/g > /tmp/a.conf"
##sudo mv /tmp/a.conf $TARGET'etc/initramfs-tools/initramfs.conf'

##export K_VERSION=`ls $TARGET'lib/modules/'`
##LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET update-initramfs -c -k $K_VERSION
##sudo mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n "uInitrd $K_VERSION" -d $TARGET'boot/initrd.img-'$K_VERSION $TARGET'boot/uInitrd'

###
# NEW KERNEL HARDKERNEL LINUX IMAGE
###

DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET apt-get install -y linux-image-armmp
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET apt-get install -y u-boot-tools
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET apt-get install -y flash-kernel

DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET update-initramfs -c -k all

sudo sh -c "mkdir -p $TARGET'etc/flash-kernel/'"
echo "$MACHINEID" | sudo tee $TARGET'etc/flash-kernel/machine'
##sudo cp /etc/flash-kernel/bootscript/bootscr.odroid /boot/boot.script

sudo sh -c "mkdir -p $TARGET'etc/flash-kernel/ubootenv.d/'"
echo 'setenv bootargs ${bootargs} cma=256M console=tty1 console=ttySAC1,115200n8 root=LABEL=ROOTFS panic=5 rootwait ro mem=2047M smsc95xx.turbo_mode=N' | sudo tee $TARGET'etc/flash-kernel/ubootenv.d/odroid'
cat $TARGET'etc/flash-kernel/ubootenv.d/odroid'

DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET update-initramfs -k all -c

DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET flash-kernel

###
# SYSTEM UBOOT PREPARATION
###

cat << __EOF__ | LC_ALL=C LANGUAGE=C LANG=C sudo tee $TARGET'etc/fw_env.config'
# Configuration file for fw_(printenv/setenv) utility.
# Up to two entries are valid, in this case the redundant
# environment sector is assumed present.
# Notice, that the "Number of sectors" is not required on NOR and SPI-dataflash.
# Futhermore, if the Flash sector size is ommitted, this value is assumed to
# be the same as the Environment size, which is valid for NOR and SPI-dataflash

# Block device
#/dev/mmcblk1boot0    -0x2200        0x2000
# eMMC ODROIDU3
/dev/mmcblk1            0x140000                0x1000
__EOF__

###
# CONFIGURATION DU DEMARRAGE CIBLE
###

##cat << __EOF__ | sudo tee $TARGET'boot/boot.script'
##setenv initrd_high "0xffffffff"
##setenv fdt_high "0xffffffff"
##setenv kerneladdr 0x40008000
##setenv ramdiskaddr 0x42000000
##setenv fdtaddr 0x41f00000
##setenv fdtfile "exynos4412-odroidu3.dtb"
##setenv console "console=tty1 console=ttySAC1,115200n8"
##setenv root "LABEL=ROOTFS"
##setenv bootdev 1
##setenv bootcmd "load mmc ${bootdev}:1 ${kerneladdr} zImage; load mmc ${bootdev}:1 ${ramdiskaddr} uInitrd; load mmc ${bootdev}:1 ${fdtaddr} dtbs/${fdtfile}; bootm ${kerneladdr} ${ramdiskaddr}:${filesize} ${fdtaddr}"
##setenv bootargs "console=tty1 console=ttySAC1,115200n8 root=LABEL=ROOTFS panic=5 rootwait ro mem=2047M smsc95xx.turbo_mode=N"
##boot
##__EOF__

##sudo mkimage -A ARM -T script -n "boot.scr for ROOTFS" -d $TARGET'boot/boot.script' $TARGET'boot/boot.scr'

###
# SYSTEM FINAL PREPARATION
###

LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET service ntp stop
LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET service ssh stop

sudo sh -c "cat $TARGET'etc/inittab' | sed s/'id:2:initdefault:'/'id:3:initdefault:'/g > /tmp/b.conf"
sudo mv /tmp/b.conf $TARGET'etc/inittab'

sudo sh -c "cat $TARGET'etc/inittab' | sed s/'id:1:initdefault:'/'id:3:initdefault:'/g > /tmp/b.conf"
sudo mv /tmp/b.conf $TARGET'etc/inittab'

sudo echo "T0:23:respawn:/sbin/getty -L ttyS0 115200 vt100" >> $TARGET'/etc/inittab'

sudo sed -i "s/^PermitRootLogin without-password/PermitRootLogin yes/" $TARGET'etc/ssh/sshd_config'

sudo sh -c "echo 'FSCKFIX=yes' >> $TARGET'etc/default/rcS'"

###
# SYSTEM IMAGE FINAL UPDATE
###

##cat << __EOF__ | sudo tee $TARGET'etc/apt/sources.list'
### deb http://ftp.fr.debian.org/debian/ $DISTRIBUPG main
##
##deb http://ftp.fr.debian.org/debian/ $DISTRIBUPG main contrib non-free
##deb-src http://ftp.fr.debian.org/debian/ $DISTRIBUPG main contrib non-free
##
##deb http://security.debian.org/ $DISTRIB/updates main contrib non-free
##deb-src http://security.debian.org/ $DISTRIBUPG/updates main contrib non-free
##
### $DISTRIB-updates, previously known as 'volatile'
##deb http://ftp.fr.debian.org/debian/ $DISTRIBUPG-updates main contrib non-free
##deb-src http://ftp.fr.debian.org/debian/ $DISTRIBUPG-updates main contrib non-free
##__EOF__
##
##cat << __EOF__ | sudo tee $TARGET'etc/apt/sources.list.d/backports.list'
##deb http://ftp.fr.debian.org/debian $DISTRIBUPG-backports main contrib non-free
##deb-src http://ftp.fr.debian.org/debian $DISTRIBUPG-backports main contrib non-free
##__EOF__
##
##DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET apt-get update
##DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET apt-get upgrade -y
##DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C sudo chroot $TARGET apt-get dist-upgrade -y

###
# SYSTEM FINAL CLEAN
###

# PROMPT before UNMOUNT and CLEAN
echo
if $interactivemode ; then
  read -p "UNMOUNT and CLEAN : Press any key to continue ..." -n1 -s
fi

sudo umount -v $TARGET'dev/pts'
sudo umount -v $TARGET'dev'
sudo umount -v $TARGET'sys'
sudo umount -v $TARGET'proc'

sudo losetup -d $BOOTDEV
sudo losetup -d $ROOTDEV
sudo losetup -d $TARGETDEV

sudo rm $TARGET'usr/sbin/policy-rc.d'

sudo umount -v $TARGET'boot'
sudo umount -v $TARGET

###
# NETTOYAGE DES GARBAGES RESIDUELS
###

sudo rm -vRf $TARGET

sync

###
# THATs ALL FOLKS...
###
# PROMPT de FIN

end=`date +%s`
echo "--- END @ `date`"
runtime=$((end-start))
echo "--- RUNTIME = $runtime"

echo
echo you can now dd the $TARGETNAME image to your ARM device
echo ## Enjoy...
echo ## But,
echo ## you may use at your own risks !
echo
echo THATs ALL FOLKS...

##sudo eject $TARGETIMG
