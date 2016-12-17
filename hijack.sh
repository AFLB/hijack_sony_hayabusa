#!/temp/sh

set +x
_PATH="$PATH"
export PATH="/temp:/system/xbin:/system/bin:/sbin"

LED_RED="/sys/class/leds/pwr-red/brightness"
LED_BLUE="/sys/class/leds/pwr-blue/brightness"
LED_GREEN="/sys/class/leds/pwr-green/brightness"


boot_recovery (){
    mount -o remount,rw /
    cd /
    export TZ="$(getprop persist.sys.timezone)"
    /system/bin/time_daemon
    sleep 5
    kill -9 $(ps | grep time_daemon | grep -v grep | awk -F' ' '{print $1}')

	for SVCRUNNING in $(getprop | grep -E '^\[init\.svc\..*\]: \[running\]' | grep -v ueventd)
	do
		SVCNAME=$(expr ${SVCRUNNING} : '\[init\.svc\.\(.*\)\]:.*')
		stop ${SVCNAME}
	done

	for RUNNINGPRC in $(ps | grep /system/bin | grep -v grep | grep -v chargemon | awk '{print $1}' ) 
	do
		kill -9 $RUNNINGPRC
	done

	for RUNNINGPRC in $(ps | grep /sbin/ | grep -v grep | awk '{print $1}' )
	do
		kill -9 $RUNNINGPRC
	done

    rm -r /sbin
    rm sdcard etc init* uevent* default*

    echo on init > /tz.conf
    echo export TZ "$(getprop persist.sys.timezone)" >> /tz.conf
    chmod 750 /tz.conf
    tar cf /zoneinfo.tar /system/usr/share/zoneinfo
}
boot_rom () {
	mount -o remount,rw rootfs /
	cd /

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
	rm -f /init* /*.rc default.prop
	rm -f /mnt
	rm -f /sbin
	rm -f /storage
}

for EVENTDEV in $(ls /dev/input/event*)
do
	SUFFIX="$(expr ${EVENTDEV} : '/dev/input/event\(.*\)')"
	cat ${EVENTDEV} > /temp/keyevent${SUFFIX} &
done

sleep 3

for CATPROC in $(ps | grep cat | grep -v grep | awk '{print $2;}')
do
	kill -9 ${CATPROC}
done

sleep 1

hexdump /temp/keyevent* | grep -e '^.* 0001 0073 .... ....$' > /temp/keycheck_up
hexdump /temp/keyevent* | grep -e '^.* 0001 0072 .... ....$' > /temp/keycheck_down

# vol-, boot recovery
if [ -s /temp/keycheck_down -o -e /cache/recovery/boot ]
then

	# Show red led
	echo '0' > $LED_BLUE
	echo '0' > $LED_GREEN
	echo '255' > $LED_RED

	sleep 1

	# turn off leds
	echo '0' > $LED_BLUE
	echo '0' > $LED_GREEN
	echo '0' > $LED_RED
    echo "======= Hijack: boot recovery =======" > /dev/kmsg
	# Return path variable to default
	export PATH="${_PATH}"
	sleep 1
	exec /system/bin/chargemon
elif [ -e /temp/hijacked ]
then
	rm /temp/hijacked
	# Return path variable to default
	export PATH="${_PATH}"
	sleep 1
	exec /system/etc/init.qcom.modem_links.orig.sh
else
    echo "======= Hijack: boot ramdisk =======" > /dev/kmsg
	touch /temp/hijacked
	boot_rom
	cd /
	cpio -idu < /temp/ramdisk.cpio
	sync
	sleep 2
	cp /temp/ramdisk/* /
	cp /temp/ramdisk/sbin/* /sbin
	#dmesg > /temp/log/post_hijack_dmesg.txt
	ls -laR > /temp/log/post_hijack_ls.txt
	chroot / /init
	sleep 3
fi
	
