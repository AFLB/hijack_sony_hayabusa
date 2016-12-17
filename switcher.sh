#!/system/bin/sh

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

VIBRAT () {
	local viberator="/sys/class/timed_output/vibrator/enable"
	echo 150 > $viberator
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

mount -o rw,remount /
mkdir -p /switch/event
mkdir -p /switch/bin
cp /system/hijack/busybox /switch/bin/
chmod 755 /switch/bin/busybox
local cmd
for cmd in `/switch/bin/busybox --list`
do
	ln -s /switch/bin/busybox /switch/bin/$cmd
done

PATH="/switch/bin:$PATH"

VIBRAT
LED 255 255 255

for eventdev in $(ls /dev/input/event*)
do
	suffix="$(expr ${eventdev} : '/dev/input/event\(.*\)')"
	cat ${eventdev} > /switch/event/key${suffix} &
done

sleep 2
LED

# kill cat
for catproc in $(ps | grep " cat" | grep -v grep | awk '{print $1;}')
do
	kill -9 ${catproc}
done

# check keys event
hexdump /switch/event/key* | grep -e '^.* 0001 0072 .... ....$' > /switch/event/keycheck_down
hexdump /switch/event/key* | grep -e '^.* 0001 0073 .... ....$' > /switch/event/keycheck_up

if [ -s /switch/event/keycheck_down ]; then
    source /system/hijack/hijack-kicker.sh
elif [ -s /switch/event/keycheck_up ]; then
    source /system/hijack/hijack-kicker.sh
else
    source /system/etc/init.qcom.modem_links.switch.sh
fi
