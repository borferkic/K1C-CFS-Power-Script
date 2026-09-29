# CFS Power Script for the Creality K1C

> [!WARNING]
> **This project is still a work in progress. Use it at your own risk.**
> If you don't know what you're doing, don't use this script.

## About

CFS Power Script is a helper script for the **Creality K1C** running the
**CFS Upgrade Kit firmware** (tested on `2.3.5.34`). It is a fork of the
[Creality Helper Script](https://github.com/Guilouz/Creality-Helper-Script) by
Guilouz, adapted to the K1C and to the CFS firmware.

Main differences from the original Helper Script:

- **K1 series only.** Support for the Ender-3 V3, Ender-3 V3 KE and CR-10 SE has been removed; the script refuses to run on other printers.
- **[PowerScreen](https://github.com/borferkic/K1C-CFS-POWER-SCREEN)** replaces Guppy Screen as the touch screen interface (`[Customize] Menu`).
- **Custom boot animation** (Creality logo, "POWER SCRIPT" and "LOADING...") installed automatically the first time the script runs.
- **KAMP adapted to the CFS firmware** (see [KAMP and the CFS purge](#kamp-and-the-cfs-purge)).
- **Power Macros & Bed Coordinates Fix** (`[Customize] Menu`): fixes the Y axis coordinates that the CFS firmware leaves wrong and installs the Power Script `gcode_macro.cfg`, `printer_params.cfg` and `box.cfg` (your originals are backed up and can be restored), plus the `STRESS_TEST`, `PID_HOTEND` and `RELOAD_CAMERA` macros.
- **M600 Support** keeps the CFS `RESUME` untouched and opens the PowerScreen filament change menu when PowerScreen is installed.
- **Camera Support** merges *Camera Settings Control* and *USB Camera Support* into a single entry.
- Modules that duplicated PowerScreen, overlapped the Power Script configuration or did not work on the K1C were removed from the *Install* menu: *Improved Shapers Calibrations*, *Custom Boot Display*, *Guppy Screen*, *GuppyFLO*, *OctoApp Companion*, *SimplyPrint*, *Fans Control Macros* and *Useful Macros*. *Improved Shapers Calibrations*, *Fans Control Macros* and *Useful Macros* still show up in the *Remove* menu when they are installed.

## Requirements

- A Creality K1C with the CFS Upgrade Kit firmware.
- SSH access to the printer as `root`.
- Internet access from the printer to GitHub.
- The printer date and time set correctly (needed for the SSL connection to GitHub).
- A factory reset before the first installation is recommended.
- If Moonraker, Fluidd or Mainsail were installed with another script, remove them first.

## Installation

1. Connect to the printer through SSH as `root`:

   ```sh
   ssh root@YOUR_K1C_IP
   ```

2. Clone the script into `/usr/data/helper-script` (this exact path is required):

   ```sh
   git clone --depth 1 https://github.com/borferkic/K1C-CFS-Power-Script.git /usr/data/helper-script
   ```

   If cloning fails with an SSL error, run this command and clone again:

   ```sh
   git config --global http.sslVerify false
   ```

3. Run the script:

   ```sh
   sh /usr/data/helper-script/helper.sh
   ```

   After the first run, the script can also be started with the `helper` command.

## Install PowerScreen

Open the script and select:

```text
[Customize] Menu → 1) Install PowerScreen
```

PowerScreen replaces the Creality touch screen. Before installing, the script
shows a warning and asks for confirmation, because the Creality screen and the
Creality services (Creality Cloud, Creality Print LAN connection and OTA firmware
updates) are **disabled**. It then asks which build to install (`stable` or
`nightly`). Everything is backed up and restored with
`[Customize] Menu → 2) Remove PowerScreen`.

## Power Macros & Bed Coordinates Fix

Open the script and select:

```text
[Customize] Menu → 6) Install Power Macros & Bed Coordinates Fix
```

The CFS firmware leaves the Y axis coordinates wrong. This module:

- Sets `position_endstop: -0.5`, `position_min: -0.5` and `position_max: 227.5` in the `[stepper_y]` section of `printer.cfg`. Nothing else in `printer.cfg` is changed except the missing `[include gcode_macro.cfg]`, `[include printer_params.cfg]` and `[include box.cfg]` lines.
- **Replaces** `gcode_macro.cfg`, `printer_params.cfg` and `box.cfg` with the Power Script versions, which also add the `STRESS_TEST`, `PID_HOTEND` and `RELOAD_CAMERA` macros.
- Keeps `START_PRINT` disabled when KAMP is installed, because KAMP provides its own.

Requirements: *Klipper Gcode Shell Command* must be installed (`RELOAD_CAMERA` needs it). Before replacing anything, the first copy of each file is saved in `/usr/data/helper-script-backup/power-config/` and never overwritten.
`[Customize] Menu → 7) Remove Power Macros & Bed Coordinates Fix` restores those originals.

## Updates

The script checks for a new version every time it starts and offers to update
itself. Installed components with an update manager entry can also be updated
from Fluidd or Mainsail (**Settings → Software Updates**).

## Menus

| Menu | Content |
|---|---|
| `[Install]` | Moonraker and Nginx, Fluidd, Mainsail, Entware, Klipper Gcode Shell Command, KAMP, Buzzer Support, Nozzle Cleaning Fan Control, Save Z-Offset Macros, Screws Tilt Adjust Support, M600 Support, Git Backup, Moonraker Timelapse, Camera Support (camera settings and optional USB camera), OctoEverywhere, Moonraker Obico and Mobileraker Companion |
| `[Remove]` | Removal of every installable module |
| `[Customize]` | Install / remove PowerScreen, remove / restore the Creality Web Interface, Creality Dynamic Logos for Fluidd, install / remove Power Macros & Bed Coordinates Fix |
| `[Backup & Restore]` | Klipper configuration files and Moonraker database |
| `[Tools]` | Klipper configuration updates, printing G-code files from folders, camera settings, service restarts, Entware updates, cache and log cleanup, firmware restore and factory reset |
| `[Information]` / `[System]` | Installed components and system status |

## Known issues

### KAMP and the CFS purge

The CFS firmware purges as part of the `START_PRINT` routine, but with the CFS
the filament is often not loaded yet at that point. The KAMP module splits the
purge from `START_PRINT` so the printer does not try to purge before loading
filament. To purge, add `ADAPT_PURGE_MOD` to the end of the slicer start G-code.
Enabling a skirt in the slicer is also recommended to prime the nozzle.

### Repository error when installing Moonraker

To avoid a repository warning when installing Moonraker, mark it as a safe Git
directory:

```sh
git config --global --add safe.directory /usr/data/moonraker/moonraker
```

## Credits

- [Guilouz](https://github.com/Guilouz) — author of the original
  [Creality Helper Script](https://github.com/Guilouz/Creality-Helper-Script)
  and its [Wiki](https://guilouz.github.io/Creality-Helper-Script-Wiki/).
- [Nik-oli](https://github.com/Nik-oli) — CFS firmware adaptations
  ([Creality-Helper-Script-K1-CFS](https://github.com/Nik-oli/Creality-Helper-Script-K1-CFS)).

## License

This project is licensed under the GNU General Public License v3.0. See
[LICENSE](LICENSE).
