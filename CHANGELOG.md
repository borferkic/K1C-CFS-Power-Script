# Changelog

All notable changes to the CFS Power Script. Each release on GitHub carries the entry of its version.

## v1.1.0

### Added
- **Reapply installed modules:** *Power Macros* (Install 6), *Bed Coordinates Fix* (Install 7) and *Creality Dynamic Logos for Fluidd* (Customize 5) now offer to **reapply** when they are already installed, instead of just saying "already installed". Useful to refresh the configuration after a script update without uninstalling.

### Removed
- Dead Guppy Screen code: `scripts/guppy_screen.sh`, `files/guppy-screen/`, the unused upstream `README.original.md`, the `GUPPY_*` variables, the legacy Guppy lines in Information and Remove, and the `guppyscreen` entry in `moonraker.asvc`.

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
