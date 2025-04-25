# Creality Helper Script for K1 Series with CFS Upgrade Kit Firmware

> [!WARNING]
> **THIS REPOSITORY IS STILL VERY MUCH AN ACTIVE WORK IN PROGRESS! PROCEED AT YOUR OWN RISK!**

---

## About

This script is a fork of Guilouz awesome Creality Helper Script with modifications to accomodate new code as found in the new K1 series CFS Upgrade Kit firmware (v2.3.5.33).  
This script is intended for use on Creality **K1 Series** printers with **CFS Upgrade Kit Firmware** and my modifcations are mainly for the START_PRINT macro routine.

Some modules currently untested so use at your own risk.  
If you encounter errors please uninstall any modules you installed and factory reset your printer as per the original Guilouz Helper Script Wiki.

**If you don't know what you're doing, I don't recommend using this helper script.**

Currently the CFS firmware has an instruction to perform a purge as part of the START_PRINT routine but when using a CFS filament is often not loaded before the purge process.  

As a result KAMP is *somewhat working* on the CFS firmware, however, it should be noted that if filament is not pre-loaded to the extruder before starting a print no filament will be extruded during the purge line process or fallback Creality purge.  
I expect there will be a fix for this but I am by no means any kind of expert when it comes to code/scripts and the modifications found in this repository are purely based off comparing the helper script data to the new CFS upgrade kit firmware data, if you are aware of an effective and simple way to fix this please do feel free to let me know.  

In the meantime I would advise enabling skirt/skirt loops in your slicer to purge and prime the nozzle before the print starts.

---

## Known Issues / Workarounds for K1 Series CFS Firmware

### Git is Broken  
Git seems to be broken on the K1 series CFS upgrade kit firmware and as a result you will need to install it manually as follows...  
*Credit to [@A-Void-Me](https://github.com/A-Void-Me) for the workaround (https://github.com/Guilouz/Creality-Helper-Script-Wiki/discussions/787#discussioncomment-12924972)*

1. SSH into the machine.
2. Install Entware:
```
wget http://bin.entware.net/mipselsf-k3.4/installer/generic.sh -O - | sh
```
3. Add Entware to your path:
```
export PATH=/opt/bin:/opt/sbin:$PATH
```
4. Update and install Git:
```
opkg update
opkg install git-http
opkg install git  # (Optional, if git is missing)
```

Git will now be installed and the Helper Script can be Git cloned to your printer as per the Helper Script Wiki.

> [!NOTE]
> The following commands will install this forked version with modifications.  
> If you wish to use Guilouz original Helper Script then use the instructions [here](https://guilouz.github.io/Creality-Helper-Script-Wiki/helper-script/helper-script-installation/)

5. Clone the script:
```
git clone --depth 1 https://github.com/Nik-oli/Creality-Helper-Script-K1-CFS.git /usr/data/helper-script
```
6. Run the script:
```
sh /usr/data/helper-script/helper.sh
```

- If you encounter an issue to clone Helper Script repository, enter this command before cloning:  
```
git config --global http.sslVerify false
```

---

### Repo error thrown when installing Moonraker  
To prevent seeing an error about the repository when installing Moonraker run the following command to add Moonraker to Git as safe:
```
git config --global --add safe.directory /usr/data/moonraker/moonraker
```

---

### Currently tested modules  
The following modules have been tested on a K1 and seem to be working ok for me but as always use as your own risk.
- Moonraker and Nginx
- Fluidd
- Klipper Gcode Shell Command
- KAMP (Modification has been made to START_PRINT gcode as found in the new CFS kit firmware.)
- Save Z Offset Macros

---

**All credit goes to Guilouz who created the Creality Helper Script.**  
**Minor modifications have been made purely to facilitate the new routines found in the CFS upgrade kit firmware.**  

---

## Original Helper Script Wiki by Guilouz:  
[Wiki](https://guilouz.github.io/Creality-Helper-Script-Wiki/)

<br />
