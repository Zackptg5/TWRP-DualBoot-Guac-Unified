ui_print "  Installing Magisk $(grep_prop MAGISK_VER $tmp/magiskcommon/util_functions.sh | sed 's/"//g')"
MAGISKBIN=/data/adb/magisk
$mountdata && magiskdata=true || magiskdata=false
[ "$layout" == "stock" ] && [ "$slot_select" == "inactive" ] && magiskdata=false

# Copy required files
if $magiskdata; then
  rm -rf $MAGISKBIN/* 2>/dev/null
  mkdir -p $MAGISKBIN 2>/dev/null
  cp -af $tools/magisk* $tmp/magiskcommon/* $tools/busybox $MAGISKBIN
  chmod -R 755 $MAGISKBIN
  magiskinit -x magisk $MAGISKBIN/magisk
fi

# addon.d
if [ -d /system/addon.d ]; then
  ui_print "    Adding addon.d survival script"
  ADDOND=/system/addon.d/99-magisk.sh
  cp -f $tmp/magiskcommon/addon.d.sh $ADDOND
  chmod 755 $ADDOND
fi

### install_magisk/boot_script.sh
[ -f recovery_dtbo ] && RECOVERYMODE=true

## Ramdisk restores
# Always stock boot (ramdisk replaced by twrp one)
magiskboot repack boot.img $MAGISKBIN/stock_boot.img
SHA1=`magiskboot sha1 "$MAGISKBIN/stock_boot.img" 2>/dev/null`
cp -af ramdisk.cpio ramdisk.cpio.orig 2>/dev/null

## Ramdisk patches
ui_print "    Patching ramdisk"

echo "KEEPVERITY=$KEEPVERITY" > config
echo "KEEPFORCEENCRYPT=$KEEPFORCEENCRYPT" >> config
echo "RECOVERYMODE=$RECOVERYMODE" >> config
echo "SHA1=$SHA1" >> config
cp -f config /data/.magisk

magiskboot cpio ramdisk.cpio \
"add 750 init $tools/magiskinit" \
"patch" \
"backup ramdisk.cpio.orig" \
"mkdir 000 .backup" \
"add 000 .backup/.magisk config"

if [ $((STATUS & 4)) -ne 0 ]; then
  ui_print "    Compressing ramdisk"
  magiskboot cpio ramdisk.cpio compress
fi

rm -f ramdisk.cpio.orig config
