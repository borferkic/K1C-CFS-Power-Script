# Changelog

All notable changes to the CFS Power Script. Each release on GitHub carries the entry of its version.

## v1.3.5

### Changed
- **CFS DIAGNOSTICS window of the Fluidd card:** the name of each row is now followed by a colon and a gap before its state (`Service:     Running`), instead of both words running together.

### Documentation
- **Double purge on color changes (OrcaSlicer):** new section in *Known issues* with the picture of the flushing volumes dialog. The CFS purges in whole rounds, so a flushing volume above about 240 mm³ makes the printer purge twice; setting 235 mm³ in every pair and disabling the automatic calculation of the flushing volumes in the Orca preferences keeps a single round.
- **Camera off and on:** the README explains the `CAMERA_OFF` / `CAMERA_ON` macros and the camera icon at the top right of PowerScreen (with a picture of it), and that the camera shares the USB hub with the CFS adapter, which is being investigated as a possible factor in the disconnections (not proven).
- **CFS Diagnostics** is described as the monitor of the work of the CFS, with its log controls in the Fluidd card.

## v1.3.4

### Fixed
- **CFS Diagnostics: stopping and starting the service right away left it running but reported as stopped.** The old process takes up to a poll interval to react to the stop signal and, when it finally did, it deleted the PID file of the new one. Now a stopping service only removes its own PID file, and `stop` waits until the process is gone. This is what the *Stop* and *Start* buttons of the new CFS DIAGNOSTICS window do.

## v1.3.3

### Added
- **CFS DIAGNOSTICS button in the CFS card of Fluidd:** opens a window to turn the diagnostics service, its log and the USB auto-recovery on and off, to download the log (and the previous one) and to delete it, without SSH. The service writes its state to `cfs_diag.status` (only when it changes) for the card to read.
- **`CFS_DIAG_LOG_ON` / `CFS_DIAG_LOG_OFF` macros (`cfs_diag.sh logging on|off`):** stop and resume writing the log while the watcher and the USB auto-recovery keep running. The setting survives a reboot.

### Fixed
- **CFS card showed an emptied slot as loaded:** the box keeps the color and material of the last spool of a slot, so a slot with no filament (`vender: none`) was drawn with a spool. It is now shown as empty; a spool without an RFID tag (`vender: unknown`) is not affected.

## v1.3.2

### Added
- **CAMERA_OFF and CAMERA_ON macros (Power Macros):** turn the camera off and on from the Fluidd *Macros* panel or the console, without SSH. `CAMERA_OFF` stops the camera service (`cam_app` and `mjpg_streamer`), so the camera stops using the USB hub it shares with the CFS adapter; `CAMERA_ON` starts it again (the same as `RELOAD_CAMERA`). There are no timelapse photos while the camera is off. PowerScreen uses them: tap the camera icon of its title bar to switch the camera. Install the Power Macros again (Install menu, option 6) to get them.

## v1.3.1

### Changed
- **Customize & PowerScreen menu:** the options are now grouped in pairs. *Install CFS Panel for Fluidd* and *Remove CFS Panel for Fluidd* (options 7 and 8) have their own group, apart from the Creality Dynamic Logos and the PowerUI Theme (options 5 and 6). The menu screenshots of the README are the ones of this version.

## v1.3.0

### Added
- **CFS Panel for Fluidd (Customize menu, options 7 and 8):** a card in the Fluidd dashboard, with the look of Fluidd's own cards, that shows the four slots of the CFS (a spool in the real color, the material, the remaining filament and the loaded slot) and the humidity and temperature of the box. Click a spool to change its material and color: it sends the same two commands as the Creality interface and PowerScreen (`BOX_MODIFY_TN_DATA`), checks that the CFS reports the change and refuses to edit while printing. The card can be undocked into a floating card that is dragged anywhere, and docked again; its mode, position and collapsed state are kept in the browser. It talks to Moonraker only, so it does not need the Creality web server. It is added with one script tag in Fluidd's `index.html`, and the module also updates the revision of that page in Fluidd's service worker (`sw.js`) so that the browsers load it; if a Fluidd update replaces those files, the script puts the card back the next time it starts.
- **CFS Custom Filaments (Install menu, option 21):** most spools have no RFID tag, so the CFS does not know what they are. This module adds filaments of your own to the material database of the K1C (brand, name, material, temperatures and color, with the ids `90001` to `99999`), from the **New filament** button in the editor of a spool of the CFS card, or with the macros `CFS_ADD_MATERIAL`, `CFS_REMOVE_MATERIAL` and `CFS_LIST_MATERIALS`. PowerScreen and the card show them (PowerScreen after it restarts). The first time, a copy of the original `material_database.json` and `material_option.json` is kept in `/usr/data/backup-cfs-materials`; your list is kept in the config folder and put back the next time the script starts if a firmware update restores the original database. It requires *Klipper Gcode Shell Command*; removing the module keeps your filaments.

### Changed
- The *Diagnostics* section of the Install, Remove and Information menus is now called *CFS*, because it also holds CFS Custom Filaments.
- *Klipper Gcode Shell Command* cannot be removed while CFS Custom Filaments is installed.

## v1.2.0

### Added
- **CFS Diagnostics with USB auto-recovery (Install menu, option 20) - BETA:** the random disconnection of the CFS is a **critical fault of the printer with the CFS**: the box shows as disconnected, the print can fail and sometimes only unplugging the USB cable brings it back. This module was created to record it and to recover from it automatically, and it is in **beta**: the recovery is proven by hand and in simulation, and it still has to be confirmed on real drops. It is a service that logs each CFS box disconnection with its probable cause and, when the box stays disconnected for 20 seconds while the USB adapter is present and the printer is not printing, resets the USB adapter by software (max 3 attempts per event, 60 seconds apart, 6 per hour). The cause behind the drops is the USB-serial adapter (the hub disabling its port, or its read channel stalling) and the Creality firmware does not recover from it. Macros: `CFS_DIAG_STATUS`, `CFS_DIAG_SUMMARY`, `CFS_DIAG_SNAPSHOT`, `CFS_DIAG_CLEAN`, `CFS_DIAG_AUTORECOVER_ON`, `CFS_DIAG_AUTORECOVER_OFF`, `CFS_DIAG_ENABLE`, `CFS_DIAG_DISABLE`. It requires *Klipper Gcode Shell Command*; the install starts the service and turns the auto-recovery on, and the removal turns it off and keeps the log.

### Changed
- **Power Macros, CFS purge:** `box.cfg` now purges 100 mm once per color change (`box_first_clean_length`, `box_need_clean_length`, `box_need_clean_length_max` and every `Tn_extrude` at 100) instead of 140 mm twice. Reapply *Power Macros* from the Install menu to get it.
- **Bed Coordinates Fix, nozzle wipe:** the wipe on the brush is now 25 mm long (X 59 to X 84) at 70 mm/s (`clr_noz_len_x` 25, `clr_xy_quick_spd` 70). It is applied on the next run of the script, also on printers that already had the fix; the original speed is backed up.

## v1.1.9

### Fixed
- **PowerScreen removal message:** removing PowerScreen from the menu showed the same warning as installing it ("the following will be disabled"). It now shows its own message: what is restored (the Creality screen and its services: Creality Cloud, Creality Print LAN connection and OTA firmware updates) and what is removed (PowerScreen, its configuration and its Moonraker Update Manager entry).

## v1.1.8

### Changed
- **Boot animation:** the final "LOADING..." no longer lasts as long: its dots cycle twice instead of six times, so the whole animation goes from about 11.5 to about 7 seconds. It is applied once on the next run of the script, also on printers that already had the previous animation.

## v1.1.7

### Changed
- **PowerUI Theme for Fluidd:** the theme is now called **PowerUI** (it was "Power Script" in 1.1.6; the old preset is replaced). The logo watermark now uses Fluidd's own *background logo* setting, which draws the logo of the selected theme over the page, as the Creality theme does. The `custom.css` file in the `.theme` folder is no longer used or created, so the theme no longer depends on that folder. Reinstall it from *Customize & PowerScreen* option 6 to turn the background logo on.

## v1.1.6

### Added
- **Power Script Theme for Fluidd:** new Fluidd theme with the Power Script logo, the Power Script green and a faint logo watermark over the page background (`custom.css` in the `.theme` folder of the Klipper configuration). It is applied and selected by default every time Fluidd is installed from the script, and it can be installed or reapplied from *Customize & PowerScreen* → option 6. The Creality theme and the other Fluidd themes are kept, and the theme is added back after a Fluidd update that replaces `config.json`.

## v1.1.5

### Changed
- **Boot animation:** new Power Script boot animation. A lightning bolt strikes the Creality logo, the Power Script logo flashes in, "POWER" assembles, the bolt glows twice, "SCRIPT" is typed and "LOADING..." with its cycling dots moves to the top right. It is applied once on the next run of the script, also on printers that already had the previous animation (the original Creality one stays backed up).
- **README:** new Power Script logo in the title and a boot animation preview before the screenshots.

## v1.1.4

### Changed
- **Power Macros:** the last Spanish texts in the configuration are now in English: the inherited comments of `gcode_macro.cfg` and the value comments of `box.cfg`. No behavior change; reapply *Power Macros* from the Install menu to get them.

## v1.1.3

### Changed
- **Power Macros:** the descriptions and the internal comments of the manual filament macros (`PS_NOCFS_UNLOAD_FILAMENT`, `PS_NOCFS_LOAD_FILAMENT`, `PS_NOCFS_CLEAN_BRUSH`) are now in English. No behavior change.

## v1.1.2

### Changed
- **Power Macros:** the alert messages of the manual filament macros are now in English (`The printer must be homed before loading filament.` and `PS_NOCFS_CLEAN_BRUSH: The toolhead must be at X148.5 Y225.`). Reapply *Power Macros* from the Install menu to get them.

## v1.1.1

### Fixed
- **Power Macros:** the manual filament macros could not be called from the console (`Unknown command: K1`), because Klipper reads a letter followed by a digit at the start of a name as a G-code command. They are now `PS_NOCFS_UNLOAD_FILAMENT`, `PS_NOCFS_LOAD_FILAMENT` and `PS_NOCFS_CLEAN_BRUSH`. Reapply *Power Macros* from the Install menu to get the new names.

## v1.1.0

### Added
- **Reapply installed modules:** *Power Macros* (Install 6), *Bed Coordinates Fix* (Install 7) and *Creality Dynamic Logos for Fluidd* (Customize 5) now offer to **reapply** when they are already installed, instead of just saying "already installed". Useful to refresh the configuration after a script update without uninstalling.

## v1.0.9

### Fixed
- **KAMP:** the bed mesh type (adaptive, full or none) and the purge line type (adaptive or classic) are now saved and restored when Klipper starts. Before, they went back to *adaptive* on every restart. The choice is stored in `variables.cfg`, the same file Save Z-Offset uses. Until you choose something, the defaults stay adaptive.

## v1.0.8

### Changed
- **Fluidd theme:** a single theme called **Creality**, with the Creality logo in the Creality green (`#8EB631`). The *Creality V1* theme and its logo are gone. Existing installations are migrated on startup, and the theme is added back if a Fluidd update removes it.

## v1.0.7

### Changed
- The Creality V2 Fluidd theme uses the Creality green (`#8EB631`, measured on the official Creality boot image) instead of blue, in the theme preset and in the selected theme.

## v1.0.6

### Changed
- **Bed Coordinates Fix:** `clr_noz_start_y` is set to a single `223` (the firmware only used the first value of `223#205#210#223`), and the bed mesh is `mesh_min: 1,1` and `mesh_max: 220,215` (Y stops at 215 because the toolhead collides at 220).
- README: explains the bed leveling change.

## v1.0.5

### Fixed
- **Creality Dynamic Logos for Fluidd:** the themes are merged into the existing Fluidd `config.json` instead of replacing it (a Fluidd update no longer removes them), and the Creality theme is selected automatically through the Moonraker database.
- The Klipper/Moonraker check of the PowerScreen install option used the system `curl`, which does not accept `-s` on the K1C. It now uses the script's `curl`.

## v1.0.4

### Added
- **Bed Coordinates Fix:** sets the bed mesh area (`mesh_min: 1,1`, `mesh_max: 220,220`) so the mesh covers the whole bed. Existing installations receive it on startup.

## v1.0.3

### Added
- **Bed Coordinates Fix:** corrects the nozzle wipe position on the brush (`clr_noz_start_x: 59`, `clr_noz_len_x: 36`, from X 59 to X 95). Removing the fix restores `printer.cfg` exactly.

## v1.0.2

### Changed
- **Bed Coordinates Fix** is its own option (Install/Remove 7), independent from **Power Macros** (6). Installations from v1.0.x are migrated automatically.
- The Customize menu is now **Customize & PowerScreen**. Install and Remove have 19 entries.

## v1.0.1

### Added
- Power Macros & Bed Coordinates Fix in the Install and Remove menus. It also sets `gcode_position_max: 220` in `[stepper_y]`.
- Startup migrations: fix the Moonraker update manager warning (`not permitted to restart service CFS-Power-Script`).

### Changed
- Module description boxes aligned with the menu frame, typo fixes, the System menu removed, the main menu title names the K1C.
- PowerScreen removal recommends restarting the printer.

## v1.0.0

First release of the CFS Power Script for the Creality K1C with the CFS firmware.

- PowerScreen install and remove (stable or nightly).
- Power Macros & Bed Coordinates Fix: Y axis coordinates and the Power Script macros.
- M600 Support that keeps the CFS `RESUME` and opens the PowerScreen filament change menu.
- Camera Support and a custom boot animation.
- Removed the modules that duplicated PowerScreen or did not fit the K1C.
