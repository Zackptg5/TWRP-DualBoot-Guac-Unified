#!/system/bin/sh
mount_dir(){
  case "$1" in
    "Android"|"lost+found") continue;;
  esac
  dest="/mnt/runtime/default/emulated/0/$1"
  [ -d "$dest" ] || mkdir -p "$dest" 2>/dev/null
  mount -t sdcardfs -o rw,nosuid,nodev,noexec,noatime,fsuid=1023,fsgid=1023,gid=9997,mask=7,derive_gid,default_normal "/datacommon/$1" "$dest"
}
mount -t <type> -o <flags> /dev/block/by-name/userdata2 /datacommon
touch /datacommon/.nomedia
chown -R 1023:1023 /datacommon
chcon -R u:object_r:media_rw_data_file:s0 /datacommon
until [ -d /storage/emulated/0/Android ]; do
  sleep 1
done
# Make one folder that has everything in it - for files not in a folder
mkdir /storage/emulated/0/CommonData 2>/dev/null
if [ -f "/system/etc/init/hw/init.rc" ]; then
  mount -t sdcardfs -o rw,nosuid,nodev,noexec,noatime,fsuid=1023,fsgid=1023,gid=9997,mask=7,derive_gid,default_normal /datacommon /mnt/pass_through/0/emulated/0/CommonData
else
  mount -t sdcardfs -o rw,nosuid,nodev,noexec,noatime,fsuid=1023,fsgid=1023,gid=9997,mask=7,derive_gid,default_normal /datacommon /storage/emulated/0/CommonData
fi
# Mount folders over top - sdcardfs only supports directory mounting
[ -f /datacommon/mounts.txt ] || exit 0
if [ "$(head -n1 /datacommon/mounts.txt | tr '[:upper:]' '[:lower:]')" == "all" ]; then
  for i in $(find /datacommon -mindepth 1 -maxdepth 1 -type d); do
    mount_dir "$(basename "$i")"
  done
else
  while IFS="" read -r i || [ -n "$i" ]; do
    mount_dir "$i"
  done < /datacommon/mounts.txt
fi
exit 0
