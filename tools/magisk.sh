ui_print "  Installing magisk 20.3"
MAGISKBIN=/data/adb/magisk
magiskdata=true
$stock && [ "$slot_select" == "inactive" ] && magiskdata=false

# Copy required files
if $magiskdata; then
  rm -rf $MAGISKBIN/* 2>/dev/null
  mkdir -p $MAGISKBIN 2>/dev/null
  cp -af $tools/magiskboot $tools/magiskinit $tmp/magiskcommon/. $tools/busybox $MAGISKBIN
  chmod -R 755 $MAGISKBIN
  # Extract magisk if doesn't exist
  [ -e $MAGISKBIN/magisk ] || magiskinit -x magisk $MAGISKBIN/magisk
fi

# addon.d
if [ -d /system/addon.d ]; then
  ui_print "    Adding addon.d survival script"
  ADDOND=/system/addon.d/99-magisk.sh
  cat <<EOF > $ADDOND
#!/sbin/sh
# ADDOND_VERSION=2

mount /data 2>/dev/null

if [ -f /data/adb/magisk/addon.d.sh ]; then
  exec sh /data/adb/magisk/addon.d.sh "\$@"
else
  OUTFD=\$(ps | grep -v 'grep' | grep -oE 'update(.*)' | cut -d" " -f3)
  ui_print() { echo -e "ui_print \$1\nui_print" >> /proc/self/fd/\$OUTFD; }

  ui_print "************************"
  ui_print "* Magisk addon.d failed"
  ui_print "************************"
  ui_print "! Cannot find Magisk binaries - was data wiped or not decrypted?"
  ui_print "! Reflash OTA from decrypted recovery or reflash Magisk"
fi
EOF
  chmod 755 $ADDOND
fi

### install_magisk/boot_script.sh
[ -f recovery_dtbo ] && RECOVERYMODE=true

## Ramdisk restores
# Patch status is always stock
if $magiskdata; then
  magiskboot repack boot.img $MAGISKBIN/stock_boot.img
  SHA1=`magiskboot sha1 "$MAGISKBIN/stock_boot.img" 2>/dev/null`
fi
cp -af ramdisk.cpio ramdisk.cpio.orig

## Ramdisk patches
ui_print "    Patching ramdisk"

echo "KEEPVERITY=$KEEPVERITY" > config
echo "KEEPFORCEENCRYPT=$KEEPFORCEENCRYPT" >> config
echo "RECOVERYMODE=$RECOVERYMODE" >> config
[ ! -z $SHA1 ] && echo "SHA1=$SHA1" >> config

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
