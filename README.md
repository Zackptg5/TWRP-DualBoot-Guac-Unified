# TWRP-DualBoot-Guac-Unified

Modified TWRP (Mauronofrio's build) and installer script for all OP7/Pro/5G variants that re-purposes userdata for true dual booting

## Some other features/notes
* Can choose between stock layout, a/b userdata, or a/b/c userdata where 'c' is a common data partition that'll show up in both roms - good place to store zips, music, pictures, etc.
* Disables verity - fstabs are modified for dual boot and so this is a must
* Optional disable or enable forced encryption
* Choose between ext4 or f2fs - note that the kernel in your rom must support f2fs
* Option to install magisk

## Flashing Instructions
* You MUST be booted into TWRP already when flashing this zip
* Since this modifies data - the zip CANNOT be on sdcard or data at all
  * If you flash from data, the zip will copy itself to /tmp and instruct you to flash it from there
  * You could do the above or copy it to a place like /dev or /tmp and flash it from there
  * Alternatively, you can adb sideload it
* Read through ALL the prompts - there's lots of options :)

## Credits

* [Teamwin](https://github.com/TeamWin)
* [Mauronofrio](https://github.com/mauronofrio/android_device_oneplus_guacamole_unified_TWRP)
* [CosmicDan](https://github.com/CosmicDan-Android/android_system_update_engine_tissotmanager-mod)

## License

  MIT
