#!/temp/bin/sh

###
#
# PART OF HIJACK RAMDISK
#
###
# 
# Copyright (c) 2016 Izumi Inami (droidfivex)
# 
# Permission is hereby granted, free of charge, to any person obtaining a 
# copy of this software and associated documentation files (the 
# "Software"), to deal in the Software without restriction, including 
# without limitation the rights to use, copy, modify, merge, publish, 
# distribute, sublicense, and/or sell copies of the Software, and to 
# permit persons to whom the Software is furnished to do so, subject to 
# the following conditions:
#
# The above copyright notice and this permission notice shall be 
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE 
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
###

# save PATH and set temporary bin to PATH
path=$PATH
export PATH="/temp/bin:$PATH"

# check already hijacked
if [ -f /temp/already ]; then
	exit 0
fi

CLEAN () {
	# unmount stock mountpoints
	umount -l /acct
	umount -l /cache
	umount -l /data/tombstones
	umount -l /data
	umount -l /dev/cpuctl
	umount -l /firmware
	umount -l /mnt/asec
	umount -l /mnt/idd
	umount -l /mnt/int_storage
	umount -l /mnt/obb
	umount -l /mnt/secure
	umount -l /storage/sdcard0
	umount -l /storage/sdcard1
	umount -l /storage/usbdisk
	umount -l /sys/kernel/debug
	umount -l /system
	umount -l /boot/modem_fs1
	umount -l /boot/modem_fs2

	# unmount for around double mounting
	umount -l /dev/pts
	umount -l /dev
	umount -l /proc
	umount -l /sys/fs/selinux
	umount -l /sys

	# syncronize change
	sleep 1
	sync

	# remove unneed files
	rm -f /d
	rm -f /data/bugreports
	rm -f /data/system/wpa_supplicant
	rm -f /etc
	rm -f /ext_card
	rm -f /mnt/sdcard
	rm -f /mnt/usbdisk
	rm -f /sdcard
	rm -f /sdcard1
	rm -f /tmp
	rm -f /tombstones
	rm -f /usbdisk
	rm -f /vendor
	rm -f /init* /*.rc /default.prop
	rm -f /mnt
	rm -f /sbin
	rm -f /storage
}

KILL () {
	local runningsvc
	local runningsvcname
	local runningprc
	local lockingpid
	local binary

	# kill services
	for runningsvc in $(getprop | grep -E '^\[init\.svc\..*\]: \[running\]' | grep -v ueventd)
	do
		runningsvcname=$(expr ${runningsvc} : '\[init\.svc\.\(.*\)\]:.*')
		stop $runningsvcname
		if [ -f "/system/bin/${runningsvcname}" ]; then
			pkill -f /system/bin/${runningsvcname}
		fi
	done

	# kill processes
	for runningprc in $(ps | grep /system/bin | grep -v grep | awk '{print $1}' ) 
	do
		kill -9 $runningprc
	done
	for runningprc in $(ps | grep /sbin | grep -v grep | awk '{print $1}' )
	do
		kill -9 $runningprc
	done

	# kill locking pidfile
	for lockingpid in `lsof | awk '{print $1" "$2}' | grep "/bin\|/system\|/data\|/cache" | awk '{print $1}'`
	do
		binary=$(cat /proc/${lockingpid}/status | grep -i "name" | awk -F':\t' '{print $2}')
		if [ "$binary" != "" ]; then
			killall $binary
		fi
	done

	# syncronize change
	sync
}

READY () {
	# tell already hijacked to hijack script...
	if [ "$1" = "" -o "$1" = "/" ]; then
		mkdir -p /temp
		touch /temp/already
	else
		mkdir -p $1/temp
		touch $1/temp/already
	fi
}

LED () {
	local red="/sys/class/leds/pwr-red/brightness" 
	local green="/sys/class/leds/pwr-green/brightness"
	local blue="/sys/class/leds/pwr-blue/brightness" 
	if [ "$1" = "" ]; then
		echo 0 > $red
		echo 0 > $green
		echo 0 > $blue
	else
		echo $1 > $red
		echo $2 > $green
		echo $3 > $blue
	fi
}

VIBRAT () {
	local viberator="/sys/class/timed_output/vibrator/enable"
	echo 150 > $viberator
}

SWITCH () {
	# get event
	mkdir -p /temp/event/
	local eventdev
	local suffix
	local catproc
	for eventdev in $(ls /dev/input/event*)
	do
		suffix="$(expr ${eventdev} : '/dev/input/event\(.*\)')"
		cat ${eventdev} > /temp/event/key${suffix} &
	done
	sleep 3

	# kill cat
	for catproc in $(ps | grep " cat" | grep -v grep | awk '{print $1;}')
	do
		kill -9 ${catproc}
	done

	# tell end of cat events to users / off led
	LED

	# check keys event
	hexdump /temp/event/key* | grep -e '^.* 0001 0072 .... ....$' > /temp/event/keycheck_down
	hexdump /temp/event/key* | grep -e '^.* 0001 0073 .... ....$' > /temp/event/keycheck_up
}

HIJACK () {
	LED 255 255 255
	VIBRAT

	# check warmboot
	grep 'warmboot=0x77665502' /proc/cmdline && touch /temp/warmboot

	if [ ! -f /temp/warmboot ]; then
		SWITCH
	fi

	# VOL +
	if [ \( -s /temp/event/keycheck_up -o -f /temp/warmboot \) -a -f /temp/ramdisk/ramdisk-recovery.* ]; then
		LED 0 255 255
		sleep 1
		LED
		KILL
		CLEAN
		cd /
		if [ -f /temp/ramdisk/ramdisk-recovery.img ]; then
			gzip -dc /temp/ramdisk/ramdisk-recovery.img | cpio -i
		elif [ -f /temp/ramdisk/ramdisk-recovery.cpio ]; then
			cpio -idu < /temp/ramdisk/ramdisk-recovery.cpio
		fi
		sleep 1
		READY /
		chroot / /init
	# VOL -
	elif [ -s /temp/event/keycheck_down ]; then
		LED 50 255 50
		sleep 1
		LED
		READY /
		export PATH=$path
		exec /system/bin/chargemon
	# normal
	else
		KILL
		CLEAN
		cd /
		cpio -idu < /temp/ramdisk/ramdisk.cpio
		sleep 1
		READY /
		chroot / /init
	fi
}

# prepare
cd /
mount -o remount,rw rootfs /

# do hijack!
HIJACK
