# DEBIAN_TOOLS
Scripts and tools for debian, mainly ARM

pour finaliser l'eMMC (8 Go) pour l'ODROID.

Voici les commandes passées :

autorisation du login root :
à faire en mode debug avec le câble USB et le PC sous minicom bien sûr
    
    nano /etc/ssh/sshd_config
++PermitRootLogin yes

ne pas oublier de remettre PermitRootLogin no après avoir créé le compte admin (sécurité) !
ssh sur l'ODROID :

    Linux DEBIANU3 4.9.0-6-armmp #1 SMP Debian 4.9.88-1+deb9u1 (2018-05-07) armv7l
    The programs included with the Debian GNU/Linux system are free software;
    the exact distribution terms for each program are described in the
    individual files in /usr/share/doc/*/copyright.
    Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
    permitted by applicable law.

configuration des locales :
    dpkg-reconfigure locales
-> sélectionner fr_FR.UTF-8

configuration langue française et clavier :

    apt install console-setup
    dpkg-reconfigure console-setup

on laisse tout avec les valeurs standards

configuration de l'horloge :

    dpkg-reconfigure tzdata
-> sélectionner Europe/Paris

bascule SD vers eMMC (/dev/mmcblk0) :

    nano /etc/fw_env.config
-> modifier pour mmcblk0

    fw_printenv

    arch=arm
    autoboot=if test -e mmc 0 boot.scr; then; run boot_script; elif test -e mmc 0 Image.itb; then; run boot_fit;elif test -e mmc 0 zImage; then; run boot_zimg;elif test -e mmc 0 uImage; then; run boot_uimg;fi;
    baudrate=115200
    board=odroid
    board_name=odroid
    boot_fit=setenv kerneladdr 0x42000000;setenv kernelname Image.itb;run loadkernel;run kernel_args;bootm ${kerneladdr}#${boardname}
    boot_script=run loadbootscript;source ${scriptaddr}
    boot_uimg=setenv kerneladdr 0x40007FC0;setenv kernelname uImage;run check_dtb;run check_ramdisk;run loadkernel;run kernel_args;bootm ${kerneladdr} ${initrd_addr} ${fdt_addr};
    boot_zimg=setenv kerneladdr 0x40007FC0;setenv kernelname zImage;run check_dtb;run check_ramdisk;run loadkernel;run kernel_args;bootz ${kerneladdr} ${initrd_addr} ${fdt_addr};
    bootargs=Please use defined boot
    bootcmd=run autoboot
    bootdelay=0
    check_dtb=if run loaddtb; then setenv fdt_addr ${fdtaddr};else setenv fdt_addr;fi;
    check_ramdisk=if run loadinitrd; then setenv initrd_addr ${initrdaddr};else setenv initrd_addr -;fi;
    console=ttySAC1,115200n8
    consoleoff=set console console=ram; save; reset
    consoleon=set console console=ttySAC1,115200n8; save; reset
    cpu=armv7
    dfu_alt_info=Please reset the board
    dfu_alt_system=uImage fat 0 1;zImage fat 0 1;Image.itb fat 0 1;uInitrd fat 0 1;exynos4412-odroidu3.dtb fat 0 1;exynos4412-odroidx2.dtb fat 0 1;boot part 0 1;platform part 0 2
    fdtaddr=40800000
    initrdaddr=42000000
    initrdname=uInitrd
    kernel_args=setenv bootargs root=/dev/mmcblk${mmcrootdev}p${mmcrootpart} rootwait ${console} ${opts}
    loadbootscript=load mmc ${mmcbootdev}:${mmcbootpart} ${scriptaddr} boot.scr
    loaddtb=load mmc ${mmcbootdev}:${mmcbootpart} ${fdtaddr} ${fdtfile}
    loadinitrd=load mmc ${mmcbootdev}:${mmcbootpart} ${initrdaddr} ${initrdname}
    loadkernel=load mmc ${mmcbootdev}:${mmcbootpart} ${kerneladdr} ${kernelname}
    mmcbootdev=0
    mmcbootpart=1
    mmcrootdev=0
    mmcrootpart=2
    scriptaddr=0x42000000
    soc=exynos
    vendor=samsung

forçage fsck si problème :

    nano /etc/flash-kernel/bootscript/bootscr.odroid
-> ajouter l'option en fin de ligne :
    setenv bootargs @@LINUX_KERNEL_CMDLINE_DEFAULTS@@ ${bootargs} @@LINUX_KERNEL_CMDLINE@@ fsck.mode=force

    flash-kernel

    Using DTB: exynos4412-odroidu3.dtb
    Installing /usr/lib/linux-image-4.9.0-6-armmp/exynos4412-odroidu3.dtb into /boot/dtbs/4.9.0-6-armmp/exynos4412-odroidu3.dtb
    Taking backup of exynos4412-odroidu3.dtb.
    Installing new exynos4412-odroidu3.dtb.
    flash-kernel: installing version 4.9.0-6-armmp
    Generating boot script u-boot image... done.
    Taking backup of boot.scr.
    Installing new boot.scr.

installation des outils réseau :

    apt install net-tools

vérification du réseau :

    ifconfig
    eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
            inet 10.3.2.212  netmask 255.255.255.0  broadcast 10.3.2.255
            inet6 fe80::68ad:16ff:fe86:58e3  prefixlen 64  scopeid 0x20<link>
            ether 6a:ad:16:86:58:e3  txqueuelen 1000  (Ethernet)
            RX packets 22848  bytes 31019737 (29.5 MiB)
            RX errors 0  dropped 0  overruns 0  frame 0
            TX packets 15014  bytes 1643871 (1.5 MiB)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

    lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
            inet 127.0.0.1  netmask 255.0.0.0
            inet6 ::1  prefixlen 128  scopeid 0x10<host>
            loop  txqueuelen 1  (Local Loopback)
            RX packets 0  bytes 0 (0.0 B)
            RX errors 0  dropped 0  overruns 0  frame 0
            TX packets 0  bytes 0 (0.0 B)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

installation des outils USB :

    apt install usbutils

création du compte admin :
selon les habitudes ...
interdiction du login root en ssh :

    nano /etc/ssh/sshd_config
->PermitRootLogin no

