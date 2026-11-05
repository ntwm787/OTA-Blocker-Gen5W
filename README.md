# OTA Blocker for Gen5W

**Firmware-specific: requires build `eng.vmadmin.20260507.094910` (260507) and exact matching OTA APK/ODEX files. Other firmware is refused.**

Standalone NEMESIS 1.1 package for users without HMG-API. No HMG-API runtime or code is bundled. The descriptor excludes its NEMESIS package ID `hmgapi`.

## Downloads

Get the USB installer, direct NEMESIS package, source and checksums from [Releases](https://github.com/ntwm787/OTA-Blocker-Gen5W/releases).

## Firmware identifiers

| Identifier | Value | Source |
| --- | --- | --- |
| Hyundai software version | `NEEV23.USA.S5W_M.V015.012.260507` | Reported by the owner; recorded as user-provided in the diagnostic report. |
| Head-unit identifier | `NE1AE.S5BMC.US` | Reported by the owner; recorded as user-provided in the diagnostic report. |
| Internal Android build | `eng.vmadmin.20260507.094910` | Read directly from the head unit's `ro.build.version.incremental` property. |

The Hyundai software version is the user-facing identifier. The installer checks the internal Android build and the exact OTA APK/ODEX file hashes. The reported Hyundai version and head-unit identifier are documented for reference, not additional checks performed by the script. A matching `260507` date alone does not establish compatibility.

## Supported target
IONIQ 5 Gen5W, Android API 19, incremental build `eng.vmadmin.20260507.094910`, Red Bend OTA configuration, and the exact inspected HKMC_DMClient_OTA APK/ODEX hashes. The script accepts recognized IONIQ 5 device identifiers across model years but rejects different binaries. ccNC and other firmware are unsupported. Compatibility metadata is advisory; script hash checks are mandatory.

The patch modifies compiled OTA-app code. A matching firmware date alone does not establish compatibility: the APK and ODEX must pass the exact file checks. Support for another firmware version requires inspecting its files and validating a matching patch. Do not bypass the build or checksum checks.

## Behavior and evidence
The patch makes OTAClient's existing app-local offline check return true. The previous vehicle capture showed offline=true and a rejected Red Bend connection with COMMS_SOCKET_ERROR after restart. The NEMESIS 1.1 install/uninstall integration has only local validation so far. It does not establish complete OTA blocking, independent modem/ECU protection, cancellation of staged updates, or normal USB-update compatibility.

No firewall, modem setting, global offline flag, native service, APK enabled state, or automatic-update preference is changed. No process is stopped and no restart is triggered. Already running code can remain loaded until a normal head-unit restart.

## Install
Park the car and run only when no update is downloading, preparing, installing, or awaiting restart. If that state is uncertain, do not install. Keep functioning NEMESIS/root access and a recovery route.

Extract the USB wrapper to USB root. Keep `packages/gen5w.ota-blocker.zip` intact. Insert the USB and confirm installation in NEMESIS. Review the NEMESIS log before any normal restart; a package listing alone is not proof of successful patching. Do not trigger a firmware update as a test.

Direct package installation is also supported. Android must be fully started. Before installation, the preinstall hook displays the required and detected firmware build and checks identity, platform and exact file checksums without modification. Missing or mismatched firmware or OTA files stop installation before backup or patching. The apply script repeats these checks before making changes; postinstall saves the original and applies checked patch chunks atomically. A failed postinstall may leave a package entry; retain logs and inspect before retrying or uninstalling.

## Uninstall and existing manual patch
Uninstall OTA Blocker from NEMESIS Manager. The preuninstall hook restores only the checked original from this unit's backup. If the file or backup differs, it refuses rather than overwriting unknown data. Do not force uninstall after a restore failure.

The legacy backup location `/data/nemesis/backup/keybord.ota-app-offline/original.odex` is intentionally preserved. A matching manual patch can be adopted only with a valid original backup. Uninstall then restores stock, including when adopting that manual patch. The backup is retained after uninstall. Do not wipe NEMESIS or remove the backup while patched. Restoration requires functioning root/NEMESIS and is not recovery for a nonbooting unit.

## License and source
Original scripts: Copyright (C) 2026 ntwm787 and contributors. Free to use, modify and share under the custom [Free Use and No Sale License](LICENSE). Selling copies, paid access and paid distribution of modified versions are prohibited. This is source available, with a no-sale restriction. Adapted from the KeyBORD OTA offline v4 scripts. Only small patch chunks are included, not a complete OEM APK/ODEX. OEM software retains its ownership. NEMESIS is separate AGPL-3.0 software: https://github.com/xwtk/hmg_nemesis


## Build and local checks

Run `python build.py` from a source checkout to generate the direct package, USB wrapper, source ZIP and SHA256SUMS.txt. Editable package scripts are in `package/scripts/`. See [VALIDATION.md](VALIDATION.md) for local checks, private test fixture requirements and remaining vehicle validation. No OEM APK/ODEX files are distributed.
