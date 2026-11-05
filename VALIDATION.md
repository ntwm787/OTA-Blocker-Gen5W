# Validation - 2026-11-05

Release candidate, package version 1.0.0, descriptor format 1.1.

The upstream NEMESIS descriptor validator accepted the package. Shell syntax and workspace-only mocked execution passed for apply, repeat apply, original backup integrity, restore, APK mismatch, missing/invalid backups, corrupt patch chunks, model/API refusals, explicit root identity, preinstall with no file changes, manual-patch adoption and HMG-API exclusion. These simulations do not execute Android Dalvik or the NEMESIS Manager.

Earlier vehicle evidence: the installed identical ODEX patch rejected an observed Red Bend connection after restart with offline=true / COMMS_SOCKET_ERROR. The revised package hooks themselves have not been exercised on a head unit.

Pending before stable release: new-NEMESIS install, verification of retained original backup and patched bytes, normal restart and observed offline behavior, uninstall and original-byte restoration, normal restart and app health. USB update compatibility and independent modem update coverage remain unverified; do not trigger a real firmware update just to test blocking.

Build: `python build.py`. Local tests require Python, Git Bash on Windows, and privately supplied OEM fixtures: `python tests/test_installer.py --fixtures PATH`. That folder must contain HKMC_DMClient_OTA.apk, HKMC_DMClient_OTA.odex (stock), and patched.odex. OEM binaries are not included in source or installers. Simulations place copied fixtures under the working directory's work/simulations folder.

Reference package format: https://github.com/xwtk/hmg_nemesis/blob/main/04-Packages.md

Firmware gate validation: wrong, missing and unknown incremental builds, plus mismatched OTA APK/ODEX files on a matching build, are tested in both preinstall/check and apply modes. Refusals are checked for unchanged live bytes and absence of backup, pending replacement and remount calls. The script prints required and detected build values.
