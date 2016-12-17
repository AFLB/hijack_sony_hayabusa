#!/system/bin/sh

#
# ramdisk hijack for Xperia SP 4.3 version
# by Peter Nyilas - dh.harald@XDA
#
# credits
# 2nd-init: https://github.com/a853/a853_2nd_init/
# idea: KeiranFTW@XDA
# recoveries for Xperia SP: cray_Doze, davidmarco, dssmex
# root/recovery ramdisk: CyanogenMod team
#
# To enter recovery: press vol- during blue light
# Default: hijacks rootfs, and extract CM ramdisk for CM10.2
# 
# Use: copy files to /system/bin and fix permissions...
#

#
# 26/02/14 keiranFTW - changes for busybox
#
# 20/03/14 154@2ch - modified to work on Xperia TX 4.3 with stock ramdisk
#
# 10/05/14 154@2ch - modified to work on Xperia TX 4.3 with CM11 ramdisk
#
# 17/11/14 154@2ch - modified to work on Xperia TX 4.3 with CM12 ramdisk
#

set +x
export PATH=/system/xbin:/system/bin:/sbin/:bin
mount -o remount,rw /
insmod /system/lib/modules/wlan.ko
insmod /system/lib/modules/cfg80211.ko
insmod /system/lib/modules/f2fs.ko
mkdir /temp/
mkdir /temp/ramdisk/
mkdir /temp/ramdisk/sbin
mkdir /temp/log/
cp /system/bin/hijack/hijack.sh /temp/
cp /system/bin/hijack/busybox /temp/
cp /system/bin/hijack/ramdisk.cpio /temp/
cp /system/bin/hijack/overlay/* /temp/ramdisk/
cp /system/bin/hijack/overlay/sbin/* /temp/ramdisk/sbin
chmod 0755 /temp/hijack.sh
chmod 0755 /temp/busybox
chmod -R 0755 /temp/ramdisk
cd /temp
for i in `busybox --list` ; do ln -s /temp/busybox $i ; done
exec /temp/sh -c /temp/hijack.sh
