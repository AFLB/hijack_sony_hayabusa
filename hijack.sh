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

PATH="/temp/bin:$PATH"

CLEAN () {
	# unmount stock mountpoints
	umount /acct
	umount /cache
	umount /data
	umount /dev/cpuctl
	umount /firmware
	umount /mnt/asec
	umount /mnt/idd
	umount /mnt/int_storage
	umount /mnt/obb
	umount /mnt/secure
	umount /storage/sdcard1
	umount /storage/usbdisk
	umount /sys/kernel/debug
	umount /system
	umount /tombstones

	# remove unneed folders
	rm -r /sbin
	rm -r /storage
	rm -r /mnt
	rm -f sdcard sdcard1 ext_card init* *.rc
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
	for runningprc in $(ps | grep /system/bin | grep -v grep | grep -v chargemon | awk '{print $1}' ) 
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
}

LED () {
	local red="/sys/class/leds/*-red/brightness" 
	local green="/sys/class/leds/*-green/brightness"
	local blue="/sys/class/leds/*-blue/brightness" 
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

HIJACK () {
	# declaration
	local eventdev
	local suffix
	local catproc

	LED 255 255 255
	VIBRAT

	# get event
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

	# kill / clean stock something
	KILL
	CLEAN

	# VOL +
	if [ -s /temp/event/keycheck_up ]; then
		LED 0 255 255
		VIBRAT
		gzip -dc /temp/ramdisk/ramdisk-recovery.img | cpio -i
	else
		cpio -idu < /temp/ramdisk/ramdisk.cpio
	fi

	sleep 1
	LED

	# kick!
	chroot / /init
}

MAIN () {
	cd /
	mount -o remount,rw rootfs /
	mkdir -p /temp/event/

	HIJACK
}

MAIN