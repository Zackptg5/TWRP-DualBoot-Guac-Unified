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
for i in $(find /datacommon -mindepth 1 -maxdepth 1 -type d); do
  case "$(basename $i)" in
    "Android"|"TWRP"|"lost+found") continue;;
  esac
  dest=/mnt/runtime/default/emulated/0/$(basename $i)
  [ -d $dest ] || mkdir $dest
  mount -t sdcardfs -o rw,nosuid,nodev,noexec,noatime,fsuid=1023,fsgid=1023,gid=9997,mask=7,derive_gid,default_normal $i $dest
done
exit 0
