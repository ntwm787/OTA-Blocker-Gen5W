# Validation

Both profiles reuse the inspected OTA APK/ODEX hashes and patch chunks from the firmware-specific builds. Local simulations exercise both profiles, checksum refusal, cross-profile refusal, repeat installation, corrupt patch refusal, HMG-API presence, and byte-for-byte restoration.

Run the tests with private fixtures for the selected firmware:
- `python tests/test_installer.py --profile 260507 --fixtures PATH`
- `python tests/test_installer.py --profile 20260903 --fixtures PATH`

The 20260903 standalone candidate was reported to install successfully. The 260507 standalone patch rejected an observed Red Bend connection after restart. The combined package still needs vehicle validation, including the upgrade path from an existing standalone installation.

The same-firmware upgrade simulation runs the previous restore, combined preflight and apply, then combined restoration. Pass `--previous-package PATH` to the prior version’s unpacked package directory. The 260507 test uses the v1.0.0 engine verified against its GitHub tag. A NEMESIS Manager upgrade on the vehicle remains pending.
