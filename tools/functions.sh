#!/sbin/sh

chooseport() {
  while true; do
    getevent -lc 1 2>&1 | grep VOLUME | grep " DOWN" > $tmp/events
    if (`cat $tmp/events 2>/dev/null | grep VOLUME >/dev/null`); then
      break
    fi
  done
  if (`cat $tmp/events 2>/dev/null | grep VOLUMEUP >/dev/null`); then
    return 0
  else
    return 1
  fi
}

unmountAllAndRefreshPartitions() {
	mount | grep /dev/block/ | while read -r line ; do
		thispart=`echo "$line" | awk '{ print $3 }'`
		umount -f $thispart
		sleep 0.5
	done
	stop sbinqseecomd
	sleep 1
	kill `pidof qseecomd` 2>/dev/null
	blockdev --rereadpt /dev/block/sda
}

format_part() {
  local partnum=$1 partsize=$2
  [ -z "$partnum" ] && abort "Formatting error!"
  [ "$(sgdisk --print /dev/block/sda$partnum 2>/dev/null)" ] || abort "Formatting error!"
  if [ "$type" == "ext4" ]; then
    mke2fs -F -t ext4 -b 4096 /dev/block/sda$partnum $partsize
  else
    mkfs.f2fs -d1 -f -O encrypt -O quota -O verity -w 4096 /dev/block/sda$partnum $partsize
  fi
}

change_part() {
  local action=$1 partnum=$2
  [ -z "$partnum" ] && abort "Partitioning error!"
  case $action in
    "delete") sgdisk /dev/block/sda --delete $partnum;;
    "new") sgdisk /dev/block/sda --new=$partnum;;
    "change-name") sgdisk /dev/block/sda --change-name=$partnum;;
    "format") format_part $partnum;;
    *) abort "Partitioning error!";;
  esac
  [ $? -eq 0 ] || abort "Partitioning error! You'll need to fix it manually!"
}

stock_userdata() {
  metadata_b_partline=$(sgdisk --print /dev/block/sda | grep -i metadata_b)
	metadata_b_partnum=$(echo "$metadata_b_partline" | awk '{ print $1 }')

	userdata_b_partline=$(sgdisk --print /dev/block/sda | grep -i userdata_b)
	userdata_b_partnum=$(echo "$userdata_b_partline" | awk '{ print $1 }')

	if [ "$curlayout" == "a/b/c" ]; then
    metadata_c_partline=$(sgdisk --print /dev/block/sda | grep -i 'metadata2')
		metadata_c_partnum=$(echo "$metadata_c_partline" | awk '{ print $1 }')
		change_part delete $metadata_c_partnum

		userdata_c_partline=$(sgdisk --print /dev/block/sda | grep -i 'userdata2')
		userdata_c_partnum=$(echo "$userdata_c_partline" | awk '{ print $1 }')
		userdata_c_partend=$(echo "$userdata_c_partline" | awk '{ print $3 }')
		change_part delete $userdata_c_partnum
	else
		userdata_c_partend=$(echo "$userdata_b_partline" | awk '{ print $3 }')
	fi
  change_part change-name $metadata_partnum:metadata
  change_part delete $metadata_b_partnum
	change_part delete $userdata_b_partnum
	change_part delete $userdata_partnum
	change_part new $userdata_partnum:$userdata_partstart:$userdata_c_partend 
  change_part change-name $userdata_partnum:userdata
  # Update this value
  userdata_partend=$userdata_c_partend
}

slot_userdata() {
  # Metadata partition size should be 16mb
  metadata_partsize=$((16 * 1024 / 4))
	if [ "$layout" == "a/b/c" ]; then
		# Calculate size for 32 or 64gb partition with 4k logical sector size (32 if 128gb device, 64 if 256gb)
		[ $(sgdisk --print /dev/block/sda | grep -im 1 userdata | awk '{printf "%d", $4}') -ge 128 ] && userdata_newpartsize=$((64 * 1024 * 1024 / 4)) || userdata_newpartsize=$((32 * 1024 * 1024 / 4))
    userdata_a_partend=`echo $((userdata_partstart+userdata_newpartsize))`

    metadata_b_partstart=`echo $((userdata_a_partend+1))`
    metadata_b_partend=`echo $((metadata_b_partstart+metadata_partsize))`
    metadata_b_partnum=$(echo $((`sgdisk --print /dev/block/sda | awk 'END{print $1}'`+1)))

		userdata_b_partstart=`echo $((metadata_b_partend+1))`
    userdata_b_partend=`echo $((userdata_b_partstart+userdata_newpartsize))`
		userdata_b_partnum=`echo $((metadata_b_partnum+1))`

    metadata_c_partstart=`echo $((userdata_b_partend+1))`
    metadata_c_partend=`echo $((metadata_c_partstart+metadata_partsize))`
    metadata_c_partnum=`echo $((userdata_b_partnum+1))`

		userdata_c_partstart=`echo $((metadata_c_partend+1))`
		userdata_c_partnum=`echo $((metadata_c_partnum+1))`
	else
		# Cut it in half
		userdata_length=`echo $((userdata_partend-userdata_partstart))`
    userdata_newpartsize=`echo $(($((userdata_length - metadata_partsize)) / 2))`
		userdata_a_partend=`echo $((userdata_partstart+userdata_newpartsize))`

    metadata_b_partstart=`echo $((userdata_a_partend+1))`
    metadata_b_partend=`echo $((metadata_b_partstart+metadata_partsize))`
    metadata_b_partnum=$(echo $((`sgdisk --print /dev/block/sda | awk 'END{print $1}'`+1)))

		userdata_b_partstart=`echo $((metadata_b_partend+1))`
		userdata_b_partend=$userdata_partend
		userdata_b_partnum=`echo $((metadata_b_partnum+1))`
	fi
  change_part change-name $metadata_partnum:metadata_a
	change_part delete $userdata_partnum
	change_part new $userdata_partnum:$userdata_partstart:$userdata_a_partend 
  change_part change-name $userdata_partnum:userdata_a
  change_part new $metadata_b_partnum:$metadata_b_partstart:$metadata_b_partend 
  change_part change-name $metadata_b_partnum:metadata_b
	change_part new $userdata_b_partnum:$userdata_b_partstart:$userdata_b_partend
  change_part change-name $userdata_b_partnum:userdata_b
	if [ "$layout" == "a/b/c" ]; then
    change_part new $metadata_c_partnum:$metadata_c_partstart:$metadata_c_partend
    change_part change-name $metadata_c_partnum:metadata2
    change_part new $userdata_c_partnum:$userdata_c_partstart:$userdata_partend
    change_part change-name $userdata_c_partnum:userdata2
  fi  
  blockdev --rereadpt /dev/block/sda
	sleep 1
	ui_print "  Formatting new userdata and metadata partitions"
	change_part format $metadata_partnum
	change_part format $metadata_b_partnum
	change_part format $userdata_partnum
	change_part format $userdata_b_partnum
  if [ "$layout" == "a/b/c" ]; then
    change_part format $metadata_c_partnum
	  change_part format $userdata_c_partnum
  fi
  ui_print "  Userdata has been partitioned to $layout"
	blockdev --rereadpt /dev/block/sda
	sleep 0.2
	sync /dev/block/sda
	sleep 0.2
}

repartition_userdata() {
  ui_print " "
	if [ "$curlayout" == "stock" ]; then
    metadata_partline=$(sgdisk --print /dev/block/sda | grep -i 'metadata$')
		userdata_partline=$(sgdisk --print /dev/block/sda | grep -i 'userdata$')
  else
    metadata_partline=$(sgdisk --print /dev/block/sda | grep -i 'metadata_a')
		userdata_partline=$(sgdisk --print /dev/block/sda | grep -i userdata_a)
	fi
  metadata_partnum=$(echo "$metadata_partline" | awk '{ print $1 }')
	userdata_partnum=$(echo "$userdata_partline" | awk '{ print $1 }')
	userdata_partstart=$(echo "$userdata_partline" | awk '{ print $2 }')
	userdata_partend=$(echo "$userdata_partline" | awk '{ print $3 }')
	userdata_partname=$(echo "$userdata_partline" | awk '{ print $7 }')
  case $layout in 
    "stock") 
      ui_print "- Repartitioning userdata back to stock"
      stock_userdata   
      blockdev --rereadpt /dev/block/sda
      sleep 1
      ui_print "  Formatting userdata and metadata"
      change_part format $userdata_partnum
      change_part format $metadata_partnum
      ui_print "  Userdata has been repartitioned back to stock (non-ab)"
      blockdev --rereadpt /dev/block/sda
      sleep 0.2
      sync /dev/block/sda
      sleep 0.2
      ;;
    *)
      ui_print "- Repartitioning userdata to $layout"
      [ "$curlayout" == "stock" ] || stock_userdata
      slot_userdata
      ;;
  esac
  [ "$type" == "ext4" ] && e2fsdroid -e -S /file_contexts -a /data /dev/block/sda$userdata_partnum || sload.f2fs -t /data /dev/block/sda$userdata_partnum
}

format_userdata() {
  ui_print " "
  ui_print "- Formatting userdata"
  for i in userdata userdata_a userdata_b userdata2; do
    local partnum=$(sgdisk --print /dev/block/sda | grep -i "$i$" | awk '{ print $1 }')
    [ "$partnum" ] || continue
    local partsize=$(sgdisk --print /dev/block/sda | grep -i "$i$" | awk '{print $3-$2+1}')
    format_part $partnum $partsize
  done
  ui_print "  Userdata has been formatted to $type"
  blockdev --rereadpt /dev/block/sda
	sleep 0.2
	sync /dev/block/sda
	sleep 0.2
  case $layout in 
    "stock") local userdata_partnum=$(sgdisk --print /dev/block/sda | grep -i 'userdata$' | awk '{ print $1 }');;
    *) local userdata_partnum=$(sgdisk --print /dev/block/sda | grep -i 'userdata_a$' | awk '{ print $1 }');;
  esac
  [ "$type" == "ext4" ] && e2fsdroid -e -S /file_contexts -a /data /dev/block/sda$userdata_partnum || sload.f2fs -t /data /dev/block/sda$userdata_partnum
}

reset_slot() {
  slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
  test "$slot" || slot=$(grep -o 'androidboot.slot_suffix=.*$' /proc/cmdline | cut -d\  -f1 | cut -d= -f2)
  if [ ! "$slot" ]; then
    slot=$(getprop ro.boot.slot 2>/dev/null)
    test "$slot" || slot=$(grep -o 'androidboot.slot=.*$' /proc/cmdline | cut -d\  -f1 | cut -d= -f2)
    test "$slot" && slot=_$slot
  fi;
  if [ "$slot" ]; then
    case $slot_select in
      inactive)
        case $slot in
          _a) slot=_b;;
          _b) slot=_a;;
        esac
      ;;
    esac
  fi
  [ -z $slot ] && abort "Unable to determine active boot slot! Aborting!"
}

patch_sepolicy() {
  if [ "$(echo $file | awk -F '.' '{print $NF}')" == "cil" ] && [ ! "$(grep "$1" $file)" ]; then
    echo "$1" >> $file
    # Regenerate sha256sum - note that order of files matters (main file followed by mapping)
    [ "$file" == "/system/etc/selinux/plat_sepolicy.cil" ] && cat $file /system/etc/selinux/mappings/$(cat /vendor/etc/selinux/plat_sepolicy_vers.txt).cil | sha256sum -b > /system/etc/selinux/plat_sepolicy_and_mapping.sha256
  else
    magiskpolicy --load $file --save $file $2
  fi
}

patch_fstabs() {
	ui_print "  Patching fstabs:"
	for i in $FSTABS; do
		[ -f $i ] || continue
		ui_print "    $i"
    local perm="$(ls -Z $i | awk '{print $1}')"
		sed -ri "
      s/,verifyatboot|verifyatboot,|verifyatboot\b//g
      s/,verify|verify,|verify\b//g
      s/,avb_keys|avb_keys,|avb_keys\b//g
      s/,avb|avb,|avb\b//g
      s/,support_scfs|support_scfs,|support_scfs\b//g
      s/,fsverity|fsverity,|fsverity\b//g
    " "$i"
    if $KEEPFORCEENCRYPT; then
      sed -ri "s/,=(.*,keydirectory=)/,fileencryption=\1/g" $i
    else
      sed -i "s/fileencryption=/=/g" $i
    fi
    sed -ri "/data2|metadata2/d" $i
		sed -ri "/name\/userdata |name\/metadata / s/wait,slotselect/wait/" $i
    while true; do
      [ "$(tail -n1 $i)" ] && { echo " " >> $i; break; } || sed -i '$d' $i
    done
    if [ "$layout" != "stock" ]; then
      if [ "$layout" == "a/b/c" ]; then
        local ext4metaline="$(sed -n "\|^/dev/block/bootdevice/by-name/metadata */metadata *ext4|p" $i | sed -e "s|name/metadata|name/metadata2|" -e "s| /metadata|/metadatacommon|")"
        local f2fsmetaline="$(sed -n "\|^/dev/block/bootdevice/by-name/metadata */metadata *f2fs|p" $i | sed -e "s|name/metadata|name/metadata2|" -e "s| /metadata|/metadatacommon|")"
        local ext4dataline="$(sed -n "\|^/dev/block/bootdevice/by-name/userdata */data *ext4|p" $i | sed -e "s|userdata|userdata2|" -e "s|/data|/datacommon|" -e "s|/metadata/|/metadatacommon/|")"
        local f2fsdataline="$(sed -n "\|^/dev/block/bootdevice/by-name/userdata */data *f2fs|p" $i | sed -e "s|userdata|userdata2|" -e "s|/data|/datacommon|" -e "s|/metadata/|/metadatacommon/|")"
        for j in ext4metaline f2fsmetaline ext4dataline f2fsdataline; do
          [ "$(eval echo \$$j)" ] || continue
          $commonforceencrypt && echo "$(eval echo \$$j | sed -r 's/,=(.*,keydirectory=)/,fileencryption=\1/')" >> $i || echo "$(eval echo \$$j | sed 's/fileencryption=/=/')" >> $i
        done
      fi
      sed -ri "/name\/userdata |name\/metadata / s/wait,/wait,slotselect,/" $i
		fi
		chcon $perm $i
	done
}

#########################################
#
# Magisk General Utility Functions
# by topjohnwu
#
#########################################

binary_patches() { # Modified
	for dt in dtb kernel_dtb extra recovery_dtbo; do
		[ -f $dt ] && magiskboot dtb $dt patch && ui_print "    Patch fstab in $dt"
	done

	if [ -f kernel ]; then
    if $magisk; then
      # Force kernel to load rootfs
      # skip_initramfs -> want_initramfs
      magiskboot hexpatch kernel \
      736B69705F696E697472616D667300 \
      77616E745F696E697472616D667300
    else
      # want_initramfs -> skip_initramfs
      magiskboot hexpatch kernel \
      77616E745F696E697472616D6673 \
      736B69705F696E697472616D6673
    fi
	fi
}

###################
# Helper Functions
###################

toupper() {
  echo "$@" | tr '[:lower:]' '[:upper:]'
}

grep_prop() {
  local REGEX="s/^$1=//p"
  shift
  local FILES=$@
  [ -z "$FILES" ] && FILES='/system/build.prop'
  sed -n "$REGEX" $FILES 2>/dev/null | head -n 1
}

#######################
# Installation Related
#######################

find_block() {
  for BLOCK in "$@"; do
    DEVICE=`find /dev/block -type l -iname $BLOCK | head -n 1` 2>/dev/null
    if [ ! -z $DEVICE ]; then
      readlink -f $DEVICE
      return 0
    fi
  done
  # Fallback by parsing sysfs uevents
  for uevent in /sys/dev/block/*/uevent; do
    local DEVNAME=`grep_prop DEVNAME $uevent`
    local PARTNAME=`grep_prop PARTNAME $uevent`
    for BLOCK in "$@"; do
      if [ "`toupper $BLOCK`" = "`toupper $PARTNAME`" ]; then
        echo /dev/block/$DEVNAME
        return 0
      fi
    done
  done
  return 1
}

patch_dtb_partitions() { # Modified
  set +x
  local result=1
  for name in dtb dtbo; do
    local IMAGE=`find_block $name$slot`
    if [ ! -z $IMAGE ]; then
      ui_print "    $name image: $IMAGE"
      if magiskboot dtb $IMAGE patch dt.patched; then
        result=0
				$magisk && { ui_print "    Backing up stock $name image"
        cat $IMAGE > stock_${name}.img; }
        ui_print "    Flashing patched $name"
        cat dt.patched /dev/zero > $IMAGE
        rm -f dt.patched
      fi
    fi
  done
  set -x
  return $result
}

run_migrations() {
  local LOCSHA1
  local TARGET
  # Legacy app installation
  local BACKUP=/data/adb/magisk/stock_boot*.gz
  if [ -f $BACKUP ]; then
    cp $BACKUP /data
    rm -f $BACKUP
  fi

  # Legacy backup
  for gz in /data/stock_boot*.gz; do
    [ -f $gz ] || break
    LOCSHA1=`basename $gz | sed -e 's/stock_boot_//' -e 's/.img.gz//'`
    [ -z $LOCSHA1 ] && break
    mkdir /data/magisk_backup_${LOCSHA1} 2>/dev/null
    mv $gz /data/magisk_backup_${LOCSHA1}/boot.img.gz
  done

  # Stock backups
  LOCSHA1=$SHA1
  for name in boot dtb dtbo; do
    BACKUP=/data/adb/magisk/stock_${name}.img
    [ -f $BACKUP ] || continue
    if [ $name = 'boot' ]; then
      LOCSHA1=`$MAGISKBIN/magiskboot sha1 $BACKUP`
      mkdir /data/magisk_backup_${LOCSHA1} 2>/dev/null
    fi
    TARGET=/data/magisk_backup_${LOCSHA1}/${name}.img
    cp $BACKUP $TARGET
    rm -f $BACKUP
    gzip -9f $TARGET
  done
}

#################
# Module Related
#################

set_perm() {
  chown $2:$3 $1 || return 1
  chmod $4 $1 || return 1
  CON=$5
  [ -z $CON ] && CON=u:object_r:system_file:s0
  chcon $CON $1 || return 1
}

set_perm_recursive() {
  find $1 -type d 2>/dev/null | while read dir; do
    set_perm $dir $2 $3 $4 $6
  done
  find $1 -type f -o -type l 2>/dev/null | while read file; do
    set_perm $file $2 $3 $5 $6
  done
}
