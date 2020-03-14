# TWRP-DualBoot-Guac-Unified

Modified TWRP (Mauronofrio's build) and installer script for all OP7/Pro/5G variants that re-purposes userdata for true dual booting

## Disclaimer
* I am not responsible for anything bad that happens to your device. Only experienced users should be using this mod
* This is no walk in the park mod. Although I have extensively tested it, there is always the possibility of a brick with anything that involves repartitioning. 
Make sure you have a backup and know how to reparititon your phone back to stock (there's a guide at the end of this readme with the basics)
* **YOU'VE BEEN WARNED - Use at your own risk**

## Some other features/notes
* Can choose between stock layout, a/b userdata, or a/b/c userdata where 'c' is a common data partition that'll show up in both roms - it's quite handy
* Disables verity - fstabs are modified for dual boot and so this is a must unless you choose stock layout in which case it's optional
* Option to disable forced encryption
* Option to install magisk - this is mandatory with a/b/c layout

## Common Data
* If you choose a/b/c layout - you'll have a/b userdata, but you'll also get a 3rd userdata partition I call 'Common Data'
* The name 'Common Data' gives away its purpose - to store files that you'll access on both slots/roms. So stuff like zips, pictures, music, TWRP backups, etc.
* In TWRP, this shows up as another storage option for backup/restore and on your pc as well - your phone will have 'Common Storage' and 'Internal Storage'
* In order to be accessible when booted, some parts of the system are modified so that the it'll be accessible WITHOUT root by the following mechanisms:
  * The common data partition is mounted to /sdcard/CommonData
  * Furthermore, if your use case is like mine where my music files are in common data, all FOLDERS are mounted over top of sdcard. So for example:<br/>
  /datacommon/Music -> /sdcard/Music
    * This of course overwrites anything there so make sure that you don't have the same folder in both datacommon and regular data
    * Note that there are 3 exceptions to this folder mounting rule:
      * Android
      * lost+found
      * TWRP
    * The reasoning should be obvious - each data partition has it's own TWRP folder, lost+found isn't something you should need to mess with, and Android is for regular data partition only - that's OS specific and should be on separate slots

## Flashing Instructions
* You MUST be booted into TWRP already when flashing this zip ([you can grab a bootable twrp image from here](https://forum.xda-developers.com/oneplus-7/oneplus-7--7-pro-cross-device-development/recovery-unofficial-twrp-recovery-t3932943))
* Since this modifies data - the zip CANNOT be on sdcard or data at all
  * If you flash from data, the zip will copy itself to /tmp and instruct you to flash it from there
  * You could do the above or copy it to a place like /dev or /tmp and flash it from there
  * Alternatively, you can adb sideload it
* Read through ALL the prompts - there's lots of options :)

## How to Flash Roms
* Nothing changes here except ONLY FLASH IN TWRP
  * Roms always flash to the opposite slot. Keep that in mind and you'll be fine
  * So don't take an OTA while booted - boot into twrp, switch slots, reboot into twrp, flash rom
* Normal flash procedure:
  * Boot into twrp
  * reboot into twrp selecting slot you do NOT want rom installed to
  * Flash rom
  * Flash this zip
  * Reboot into twrp
  * Flash everything else

## Help! I Can't Boot!
* Usually this is because you switched roms without formatting data first. This should be flashing 101 but we all forget sometimes. Plus this slot stuff can get confusing
* If it only happens with a/b/c and not any other layout, there's a good chance it's selinux related. Try setting selinux to permissive at kernel level [with this mod](https://zackptg5.com/android.php#ksp) ([source here](https://github.com/Zackptg5/Kernel-Sepolicy-Patcher)).


## How to Manually Repartition Back to Stock
* In the event any step in the repartioning fails, the entire installer aborts. The good news is that this prevents a potential brick. The bad is that you need to manually revert back
* Boot into twrp. If sgdisk is not present in sbin, grab it from this zip (in tools) and adb push it to /sbin and chmod +x it
* `sgdisk /dev/block/sda --print` Note that /dev/block/sda is the block that userdata and metadata are stored on - no other block is touched by this mod. 
This will show up the current partition scheme. Stock looks something like this (on OP7 Pro):
```
Number  Start (sector)    End (sector)  Size       Code  Name
   1               6               7   8.0 KiB     FFFF  ssd
   2               8            8199   32.0 MiB    FFFF  persist
   3            8200            8455   1024.0 KiB  FFFF  misc
   4            8456            8711   1024.0 KiB  FFFF  param
   5            8712            8839   512.0 KiB   FFFF  keystore
   6            8840            8967   512.0 KiB   FFFF  frp
   7            8968           74503   256.0 MiB   FFFF  op2
   8           74504           77063   10.0 MiB    FFFF  oem_dycnvbk
   9           77064           79623   10.0 MiB    FFFF  oem_stanvbk
  10           79624           79879   1024.0 KiB  FFFF  mdm_oem_dycnvbk
  11           79880           80135   1024.0 KiB  FFFF  mdm_oem_stanvbk
  12           80136           80263   512.0 KiB   FFFF  config
  13           80264          969095   3.4 GiB     FFFF  system_a
  14          969096         1857927   3.4 GiB     FFFF  system_b
  15         1857928         1883527   100.0 MiB   FFFF  odm_a
  16         1883528         1909127   100.0 MiB   FFFF  odm_b
  17         1909128         1913223   16.0 MiB    FFFF  metadata
  18         1913224         1945991   128.0 MiB   FFFF  rawdump
  19         1945992        61409274   226.8 GiB   FFFF  userdata
```
You may have different size userdata - mine is 256gb - depending on your device but that doesn't matter. You just need to see where they're located<br/>
Take note of the **number** (I'll call *userdata_num* for the sake of this tutorial) and **start sector** (*userdata_start*) for the first partition AFTER rawdump, and the **end sector** (*userdata_end*) of the last parititon on sda

* `sgdisk /dev/block/sda --change-name=17:metadata` - renames metadata partition back to non-ab stock
* `sgdisk /dev/block/sda --delete=19` - this deletes the entire partition - use this command for each user/metadata partition after rawdump (ones generated by this zip)
* `sgdisk /dev/block/sda --new=$userdata_num:$userdata_start:$userdata_end` - this creates the new userdata partition
* Final step is to format the new userdata partition: `mke2fs -t ext4 -b 4096 /dev/block/sda$userdata_num $userdata_size` - where *userdata_size* can be calculated with this shell command: `sgdisk /dev/block/sda --print | grep "^ *$userdata_num" | awk '{print $3-$2+1}'`
* Run `sgdisk /dev/block/sda --print` again to make sure everything is correct and then reboot back into twrp

## Credits

* [Teamwin](https://github.com/TeamWin)
* [Mauronofrio](https://github.com/mauronofrio/android_device_oneplus_guacamole_unified_TWRP)
* [CosmicDan](https://github.com/CosmicDan-Android/android_system_update_engine_tissotmanager-mod)
* [TopJohnWu](https://github.com/topjohnwu/Magisk)

## License

  MIT
