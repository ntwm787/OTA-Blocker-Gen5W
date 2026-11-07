# OTA Compatibility Collector 1.0.0

A read-only diagnostic script for collecting the evidence needed to investigate OTA-blocker support on additional vehicles and firmware builds. It runs once through NEMESIS; it is not an installer or blocker.

The collector has no model or firmware lock. Collection on another vehicle does **not** establish compatibility with our blocker. Gen5W is the initial investigation target; ccNC and other platforms require separate code analysis and may use files this collector does not discover.

## Run from USB

1. Park the vehicle. Wait until Android and NEMESIS are fully started. Do not run during a firmware update, preparation, installation, or pending update restart; this collector does not determine whether an update is active.
2. Back up the USB's existing `NEMESIS.data` and `NEMESIS.sh` on your computer. Extract **OTA Compatibility Collector USB 1.0.0.zip** to the USB root. Keep `NEMESIS.data`, `NEMESIS.sh`, and `OTA-COMPATIBILITY.marker` together. There is no inner package ZIP. Do not add `NEMESIS.emergency`.
3. Optionally fill in `VEHICLE-DETAILS.txt`, especially make/model/year, sales region, displayed software version, NEMESIS version, and existing OTA modifications. Do not enter personal identifiers.
4. Insert the USB and confirm script execution in NEMESIS. Root execution is required. No restart is needed.
5. After the script finishes, copy the entire new `OTA-Compatibility-YYYYMMDD-HHMMSS-PID` folder to your computer before inspecting it. ZIP that local folder and return it privately for inspection. Retain incomplete results as well.

The descriptor uses NEMESIS's `type=execute` USB workflow, including the newer NEMESIS interface. This is not installed into My Packages. Restore your previous USB files after collection if desired.

## Submit your capture to the maintainer

Send the results privately to **ntwm787**, the maintainer of OTA-Blocker-Gen5W:

1. Copy the generated `OTA-Compatibility-...` folder from USB to your computer.
2. ZIP that entire folder, including `STATUS.txt`, manifests, collected files and any partial-result notes.
3. Include your make, model, model year, sales region, displayed software version, NEMESIS version, and any existing OTA modifications. The optional `VEHICLE-DETAILS.txt` form captures these details.
4. Send the ZIP through the private channel agreed with the maintainer. If you do not already have one, [open an issue asking how to submit privately](https://github.com/ntwm787/OTA-Blocker-Gen5W/issues/new), without attaching the capture or OEM code.

Do not upload captures, APK/ODEX files, or private download links to public issues. The collector does not send anything automatically. The maintainer will inspect the files to decide whether an existing patch matches or a new patch is required. Submission does not guarantee support or make an unsupported build safe to patch.

## What it collects

- An explicit allowlist of build/product/platform properties, including Android API level, incremental build and fingerprint. It does not dump all properties.
- Matching OTA, FOTA, DMClient and updater APKs from standard system/vendor/product app locations and their adjacent ODEX/OAT-directory code companions.
- Matching installed-package code paths, to help find renamed APKs, plus common framework JAR/ODEX dependencies and bounded boot OAT files for offline code inspection.
- Presence of HMG-API and our blocker; the exact legacy original OTA ODEX backup if present. HMG-API scripts and general app data are not copied.
- Per-file checksums before copying, on the copy, and again on the source. `files.tsv` reports copied files and verification results; `HASH-ALGORITHM.txt` identifies the available checksum algorithm.
- A known-file classification for `HKMC_DMClient_OTA.odex`: known stock 260507, known offline patch 260507, or unknown. This classification applies only to that file and never approves the vehicle or firmware for installation.

The script avoids `find`, BusyBox, on-unit ZIP tools, full system logs, VIN/serial queries, accounts, contacts, navigation history and app configuration databases. OEM code and targeted package paths are included, so share result folders privately rather than publishing firmware captures in GitHub issues.

## What it changes

Only a newly created result folder on the USB is written. The script does not patch files, remount partitions, change settings, stop services, disable packages, send modem commands, trigger/cancel updates, reboot, or upload anything. An existing OTA blocker is left untouched.

The capture is not an atomic system snapshot. Source files may change during collection; detected changes are reported rather than treated as valid patch evidence.

## Limits and result status

Maximum 100 code files, 64 MiB per file and 192 MiB total code. Allow extra free space for metadata. Large or unreadable files, missing hash tools, failed copies, or a lack of recognizable OTA APK/ODEX candidates produce `PARTIAL`. Missing optional files are normal. A folder left with `RUNNING` indicates interrupted or failed collection.

`COMPLETE` means the selected files were collected and verified; it does not mean every update component was found. `PARTIAL` can still be useful. NEMESIS may display success for a completed partial capture, so inspect `STATUS.txt`, `collector.log` and `notes.txt`. If execution is refused before the folder is created, retain the NEMESIS error message.

Symlinked files/directories and unusual paths are skipped. APK scan depth is bounded to conventional layouts; split APK dependencies and newer optimized-code layouts may need a later targeted collection. Native/modem OTA paths are not assessed by this capture. USB-update compatibility and runtime blocking require separate testing after a matching patch is developed.

## Source and local verification

Editable source, build tool and mock tests are included in the separate source ZIP. Build with `python build.py`. On Windows, `python tests/test_collector.py` uses Git Bash and fake vehicle files under `work/collector-tests`; it never connects to a car. Local simulation is not vehicle validation.

Copyright (C) 2026 ntwm787 and contributors. Original collector source uses this repository's custom Free Use and No Sale License; see LICENSE. Free to use, modify and share; sale and paid access are prohibited. No OEM APK/ODEX or NEMESIS executable is bundled. OEM software remains owned by its respective owners. NEMESIS is separately obtained AGPL-3.0 software: https://github.com/xwtk/hmg_nemesis
