#!/system/bin/sh
chown -R 1023:1023 /datacommon
chcon -R u:object_r:media_rw_data_file:s0 /datacommon
until [ -d /storage/emulated/0/Android ]; do
  sleep 1
done
# Make one folder that has everything in it - for files not in a folder
mkdir /storage/emulated/0/CommonData
mount -t sdcardfs -o rw,nosuid,nodev,noexec,noatime,fsuid=1023,fsgid=1023,gid=9997,mask=7,derive_gid,default_normal /datacommon /storage/emulated/0/CommonData
# Mount folders over top - sdcardfs only supports directory mounting
[ -f /datacommon/mounts.txt ] || exit 0
while IFS="" read -r i || [ -n "$i" ]; do
  [ -d "/datacommon/$i" 2>/dev/null ] || continue
  case "$i" in
    "Android"|"lost+found") continue;;
  esac
  dest="/mnt/runtime/default/emulated/0/$i"
  [ -d "$dest" ] || mkdir -p "$dest"
  mount -t sdcardfs -o rw,nosuid,nodev,noexec,noatime,fsuid=1023,fsgid=1023,gid=9997,mask=7,derive_gid,default_normal "/datacommon/$i" "$dest"
done < /datacommon/mounts.txt
exit 0
