#!/system/bin/sh
# Copyright (C) 2026 ntwm787 and contributors
# SPDX-License-Identifier: LicenseRef-Free-Use-No-Sale
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib
umask 077
MODE=$1
case "$MODE" in apply|restore|check) ;; *) echo 'Invalid operation'; exit 1 ;; esac
USB=$(pwd)
if [ "$MODE" != restore ] && [ -f /data/hmgapi/uninstall.sh ]; then
 echo 'HMG-API is installed; use its update controls instead.'
 exit 1
fi
fail() { echo "ERROR: $*"; exit 1; }
echo 'OTA Blocker 1.0.0 - app-local offline patch'
echo "Operation=$MODE"
# Android toolbox variants may not support id -u. Require explicit UID 0.
IDENTITY=$(id 2>&1) || fail "Cannot read execution identity: $IDENTITY"
echo "Execution identity: $IDENTITY"
case "$IDENTITY" in
 uid=0\(*|'uid=0 '*) ;;
 *) fail 'Root required: execution identity does not report UID 0.' ;;
esac
DEVICE=$(getprop ro.product.device)
echo "Device=$DEVICE"
# Recognized IONIQ 5 Gen5W device family; accept any two-digit model year.
case "$DEVICE" in
 wp_daudioplus_neev[0-9][0-9]_*|wp_daudioplus_neev_*) ;;
 *) fail 'Not a recognized IONIQ 5 Gen5W device identifier.' ;;
esac
[ "$(getprop ro.build.version.sdk)" = 19 ] || fail 'Not the inspected Gen5W Android API level.'
REQUIRED_BUILD=eng.vmadmin.20260507.094910
BUILD=$(getprop ro.build.version.incremental) || fail 'Cannot read firmware build; no changes made.'
echo "Firmware check: required=$REQUIRED_BUILD detected=${BUILD:-unknown}"
[ "$BUILD" = "$REQUIRED_BUILD" ] || fail "Unsupported firmware: requires $REQUIRED_BUILD (260507); detected ${BUILD:-unknown}. No changes made."
[ "$(getprop ro.product.ota)" = redbend ] || fail 'Not the inspected Red Bend configuration.'
[ "$(getprop sys.boot_completed)" = 1 ] || fail 'Android must be fully started.'
for CMD in cp mv chmod dd grep cat mkdir rm sync; do command -v "$CMD" >/dev/null 2>&1 || fail "Missing $CMD"; done
command -v nemesis >/dev/null 2>&1 || fail 'NEMESIS command missing.'
HASH_TOOL=
for CMD in sha256sum sha1sum md5sum md5; do
 if command -v "$CMD" >/dev/null 2>&1; then HASH_TOOL=$CMD; break; fi
done
[ -n "$HASH_TOOL" ] || fail 'No supported checksum utility; no changes made.'
check_hash() {
 [ -f "$1" ] || return 1
 case "$HASH_TOOL" in
  sha256sum) EXPECTED=$2 ;;
  sha1sum) EXPECTED=$3 ;;
  md5sum|md5) EXPECTED=$4 ;;
 esac
 ACTUAL=$("$HASH_TOOL" "$1") || return 1
 echo "$ACTUAL" | grep -F "$EXPECTED" >/dev/null 2>&1
}
is_stock() { check_hash "$1" c8facf373f015b042ab3fa89f14686f713e059726172c463107174abeeb1e4a3 49aceffd478aa993fec24933a78f4a451d80521a 588064a3c0e03cd56ed94bf0a4851d4b; }
is_patched() { check_hash "$1" 6eee1a24a91aa90a8747a38c06989e3a5debeadcd6758e8d6dca792e2c4540bc fb12ca5eff247a49901a8f5fa756f28c6e8618ea 12ca0438d1d9f222758c82f767b67d0c; }
is_apk() { check_hash "$1" a1e2f1dfe79cbe3f733a5a4c32208c564dfaa0ff34bca5621791f0ae87fcdf6f c71b59360288a768093f91b403a7eaeee5333f94 9372387c5accde692cc9416cfeeacccf; }
LIVE=/system/app/HKMC_DMClient_OTA.odex
APK=/system/app/HKMC_DMClient_OTA.apk
BASE=/data/nemesis/backup/keybord.ota-app-offline
BACKUP="$BASE/original.odex"
STAGE="$BASE/stage-$$.odex"
TEMP="/system/app/.keybord-ota-offline-$$.tmp"
REMOUNTED=0
PUBLISHED=0
cleanup() {
 [ ! -f "$STAGE" ] || rm "$STAGE"
 if [ "$REMOUNTED" = 1 ]; then
  [ ! -f "$TEMP" ] || rm "$TEMP"
  nemesis remount ro || echo 'ERROR: Could not restore /system read-only state.'
 fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
is_apk "$APK" || fail 'Unsupported OTA APK: file checksum does not match the supported 260507 version; no changes made.'
if [ "$MODE" = check ]; then
 if is_stock "$LIVE"; then
  if [ -e "$BACKUP" ]; then is_stock "$BACKUP" || fail 'Invalid existing backup.'; fi
 elif is_patched "$LIVE"; then
  is_stock "$BACKUP" || fail 'Existing patch requires valid original backup.'
 else fail 'Unsupported ODEX; no changes made.'; fi
 echo 'PASS: supported firmware and exact OTA files verified; preflight made no changes.'
 exit 0
fi
if [ "$MODE" = apply ]; then
 if is_patched "$LIVE"; then
  is_stock "$BACKUP" || fail 'Patched file found but original backup is unavailable; preserve files and stop.'
  echo 'Already patched; verified original backup retained; no file changes made.'
  exit 0
 fi
 is_stock "$LIVE" || fail 'ODEX is not the exact inspected original; no changes made.'
 mkdir -p "$BASE" || fail 'Cannot create backup directory.'
 if [ -e "$BACKUP" ]; then
  is_stock "$BACKUP" || fail 'Existing backup is not the expected original; refusing to overwrite it.'
 else
  cp -p "$LIVE" "$BASE/backup-pending-$$.odex" || fail 'Original backup copy failed.'
  is_stock "$BASE/backup-pending-$$.odex" || fail 'Original backup checksum failed.'
  mv "$BASE/backup-pending-$$.odex" "$BACKUP" || fail 'Cannot finalize backup.'
 fi
 cp -p "$BACKUP" "$STAGE" || fail 'Cannot create staging copy.'
 dd if="$USB/patch-0.bin" of="$STAGE" bs=1 seek=48 conv=notrunc || fail 'Patch application failed; live file unchanged.'
 dd if="$USB/patch-1.bin" of="$STAGE" bs=1 seek=759329 conv=notrunc || fail 'Patch application failed; live file unchanged.'
 is_patched "$STAGE" || fail 'Patched staging checksum mismatch; live file unchanged.'
else
 if is_stock "$LIVE"; then echo 'Original file already present; no file changes made.'; exit 0; fi
 is_patched "$LIVE" || fail 'Live file differs from both expected versions; refusing to overwrite it.'
 is_stock "$BACKUP" || fail 'Valid original backup not found; no changes made.'
 cp -p "$BACKUP" "$STAGE" || fail 'Cannot stage restoration.'
 is_stock "$STAGE" || fail 'Restoration staging hash mismatch.'
fi
# Preserve the original mount state. Refuse an unrecognized layout.
MOUNT_KNOWN=0
WAS_RW=0
while read DEVICE MOUNTPOINT FSTYPE OPTIONS REST; do
 if [ "$MOUNTPOINT" = /system ]; then
  MOUNT_KNOWN=1
  case ",$OPTIONS," in *,rw,*) WAS_RW=1 ;; esac
 fi
done < /proc/mounts
[ "$MOUNT_KNOWN" = 1 ] || fail 'Separate /system mount not identified; live file unchanged.'
# Do not publish a replacement with unverified SELinux labels.
command -v getenforce >/dev/null 2>&1 || fail 'Cannot determine SELinux mode; live file unchanged.'
SELINUX=$(getenforce)
case "$SELINUX" in
 Enforcing) command -v restorecon >/dev/null 2>&1 || fail 'restorecon required under enforcing SELinux.' ;;
 Permissive|Disabled) ;;
 *) fail 'Unknown SELinux mode; live file unchanged.' ;;
esac
if [ "$WAS_RW" = 0 ]; then
 nemesis remount rw || fail 'Cannot remount /system.'
 REMOUNTED=1
fi
cp -p "$STAGE" "$TEMP" || fail 'Cannot stage replacement beside live file.'
# cp -p retains original owner/mode/time; do not impose guessed ownership.
if [ "$SELINUX" = Enforcing ]; then restorecon "$TEMP" || fail 'Cannot label replacement.'; fi
if [ "$MODE" = apply ]; then is_patched "$TEMP" || fail 'Final staged hash failed.'; else is_stock "$TEMP" || fail 'Final restore hash failed.'; fi
mv "$TEMP" "$LIVE" || fail 'Atomic replacement failed.'
PUBLISHED=1
sync
if [ "$MODE" = apply ]; then is_patched "$LIVE" || fail 'Post-replacement hash failed; run restore tool.'; else is_stock "$LIVE" || fail 'Restored file hash failed.'; fi
if [ "$SELINUX" = Enforcing ]; then restorecon "$LIVE" || fail 'Post-replacement label check failed; run restore tool.'; fi
if [ "$REMOUNTED" = 1 ]; then
 nemesis remount ro || fail 'Replacement complete but /system could not be returned read-only.'
 REMOUNTED=0
fi
cleanup
trap - EXIT HUP INT TERM
echo "VERIFIED: expected $MODE file bytes are on disk. Backup retained at $BACKUP."
echo 'No app/service was stopped and no reboot was triggered.'
echo 'The existing process may still run old code until a subsequent normal head-unit restart.'
echo 'This verifies file bytes only, not Dalvik runtime behavior, OTA blocking, or USB update compatibility.'
exit 0
