#!/system/bin/sh
chown -R 1023:1023 /datacommon
chcon -R u:object_r:media_rw_data_file:s0 /datacommon
sleep 1
for i in $(find /datacommon -mindepth 1 -maxdepth 1 -type d); do
  case "$(basename $i)" in
    "Android"|"TWRP"|"lost+found") continue;;
  esac
  dest=/mnt/runtime/default/emulated/0/$(basename $i)
  [ -d $dest ] || mkdir $dest
  mount -t sdcardfs -o rw,nosuid,nodev,noexec,noatime,fsuid=1023,fsgid=1023,gid=9997,mask=7,derive_gid,default_normal $i $dest
done
exit 0
