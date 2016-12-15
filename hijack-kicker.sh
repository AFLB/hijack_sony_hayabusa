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
####
#
# call hijack.sh from root shell
# and initialize before using hijack.
#
# put this file instead of
# exist unused shell file or unused binary file.
#
# original SONY ramdisk call avobes:
#  * /system/etc/init.qcom.modem_links.sh
#  * /system/bin/taimport
# etc...
#
# you can use at stock system
# by appending it to
# execute shell scripts called by ramdisk.
#  * /system/etc/init.qcom.modem_links.sh
# etc...
#
###

PREPARE_HIJACK () {
    ###
    # prepare
    ###
    mount -o remount,rw rootfs /
    mkdir -p /temp
    mkdir -p /temp/bin
    mkdir -p /temp/script
    mkdir -p /temp/ramdisk

    ###
    # copy busybox
    ###
    # why? - to use high-functioning busybox
    # stock ramdisk has only minimal busybox...
    ###
    cp /system/hijack/busybox /temp/bin/
    chmod 755 /temp/bin/busybox
    local cmd
    for cmd in `/temp/bin/busybox --list`
    do
        ln -s /temp/bin/busybox /temp/bin/$cmd
    done

    ###
    # copy scripts
    ###
    cp /system/hijack/hijack.sh /temp/script/
    chmod 755 /temp/script/*.sh

    ###
    # copy ramdisk images
    ###
    cp /system/hijack/ramdisk-recovery.img /temp/ramdisk/
    cp /system/hijack/ramdisk.cpio /temp/ramdisk/

    ###
    # kick hijack script
    ###
    exec /temp/bin/sh -c /temp/script/hijack.sh
}

PREPARE_HIJACK
