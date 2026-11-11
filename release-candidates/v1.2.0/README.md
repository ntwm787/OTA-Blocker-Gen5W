# OTA Blocker for Gen5W

Release candidate 1.2.0 for NEMESIS 1.1. A single installer selects a profile using the internal Android build and verifies the exact OTA APK and ODEX checksums before writing. It requires an IONIQ 5 Gen5W device, Android API 19, and Red Bend configuration.

| Firmware | Internal Android build |
| --- | --- |
| 260507 | `eng.vmadmin.20260507.094910` |
| 20260903 (260903) | `eng.vmadmin.20260903.161833` |

HMG-API presence is allowed. Runtime interaction with HMG-API remains unverified. The patch makes the OTA app's existing offline check return true. Independent modem/ECU updates and normal USB-update compatibility remain unverified.

## Downloads

- [USB installer](OTA%20Blocker%20USB%20Combined%201.2.0%20RC.zip?raw=true)
- [Direct NEMESIS package](gen5w.ota-blocker.zip?raw=true)
- [Source archive](OTA%20Blocker%20Source%20Combined%201.2.0%20RC.zip?raw=true)
- [SHA-256 checksums](SHA256SUMS.txt)

## Install and restore

Use a parked vehicle with Android fully started and no update in progress or awaiting restart. Extract the USB ZIP to USB root. Keep the inner ZIP intact in the NEMESIS Packages folder supplied by the wrapper. Insert the drive and confirm installation. Review the NEMESIS log before a normal head-unit restart.

The package keeps the existing package ID and selects the original backup location for each firmware. Uninstall through NEMESIS Manager to restore the checksum-verified original. Review the restore log and check app health after restart. Keep the backup while the patch is applied.

## Update an existing installation

On the same firmware, insert the combined USB and approve **Update** when NEMESIS detects the existing OTA Blocker. NEMESIS runs the previous version's restore hook first, then installs the selected profile. Keep the verified original backup available. If the previous restore fails, review the NEMESIS log before retrying. The previous version's restore hook may refuse if the vehicle firmware has changed since it was installed.

## Validation and source

Run `python build.py` to rebuild the ZIPs. See VALIDATION.md in the source archive for fixture tests and vehicle status. The custom Free Use and No Sale License covers the original scripts. The package includes small patch chunks and requires matching OEM files already on the vehicle.

## Runtime check after installation

[Download the combined Runtime Check USB](https://raw.githubusercontent.com/ntwm787/OTA-Blocker-Gen5W/main/collector/downloads/OTA%20Runtime%20Check%20Combined%20USB%201.1.0.zip) for firmware 260507 or 20260903. Run after a normal head-unit restart and return the generated `KeyBORD-OTA-Runtime-…` folder privately. The report records the OTA file checksums and captures existing matching log events. A NEMESIS success message means the report was saved.
