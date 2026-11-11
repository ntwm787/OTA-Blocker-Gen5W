#!/system/bin/sh
# Copyright (C) 2026 ntwm787 and contributors
# SPDX-License-Identifier: LicenseRef-Free-Use-No-Sale
# Read-only sources; all writes go to the new USB result directory.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib
umask 077
case "$0" in /*) USB=${0%/*} ;; *) USB=$(pwd) ;; esac
case "$USB" in /storage/usb[0-9]*|/mnt/media_rw/usb[0-9]*) ;; *) echo 'Run this collector from the NEMESIS USB root.'; exit 1 ;; esac
[ -f "$USB/OTA-COMPATIBILITY.marker" ] || { echo 'Collector marker missing.'; exit 1; }
for CMD in mkdir date; do
 command -v "$CMD" >/dev/null 2>&1 || { echo "Missing required tool: $CMD"; exit 1; }
done
OUT="$USB/OTA-Compatibility-$(date +%Y%m%d-%H%M%S)-$$"
mkdir "$OUT" || exit 1
exec > "$OUT/collector.log" 2>&1
echo 'OTA Compatibility Collector 1.0.2'
echo "USB root: $USB"
printf 'RUNNING\n' > "$OUT/STATUS.txt" || exit 1
trap 'rc=$?; if [ "$rc" -ne 0 ]; then echo "Collection failed (exit $rc)."; printf "FAILED\n" > "$OUT/STATUS.txt"; fi' EXIT
IDENTITY=$(id 2>&1) || { echo "Could not read execution identity: $IDENTITY"; exit 1; }
case "$IDENTITY" in uid=0\(*|'uid=0 '*) ;; *) echo 'Root execution required; collection not started.'; exit 1 ;; esac
[ "$(getprop sys.boot_completed)" = 1 ] || { echo 'Wait until Android has fully started.'; exit 1; }
echo "Identity: $IDENTITY"
echo 'Only the new USB result directory is written. No update is requested.'
trap 'echo "Collection interrupted; retain partial results."; exit 1' HUP INT TERM
for CMD in cp ls; do
 command -v "$CMD" >/dev/null 2>&1 || { echo "Missing required tool: $CMD"; exit 1; }
done
file_size() (
 set -f
 if command -v wc >/dev/null 2>&1 && SIZE_LINE=$(wc -c < "$1"); then
  set -- $SIZE_LINE
  BYTES=$1
 else
  SIZE_LINE=$(ls -ln "$1") || return 1
  set -- $SIZE_LINE
  # KitKat toolbox has no hard-link-count column. GNU/Toybox include it.
  case "$1" in -*) ;; *) return 1 ;; esac
  case "$5" in
   ????-??-??) BYTES=$4 ;;
   *) BYTES=$5 ;;
  esac
 fi
 case "$BYTES" in ''|*[!0123456789]*) return 1 ;; esac
 printf '%s\n' "$BYTES"
)
PARTIAL=0
COUNT=0
TOTAL=0
OTA_COUNT=0
MAX_FILES=100
MAX_FILE_BYTES=67108864
MAX_TOTAL_BYTES=201326592
HASH_TOOL=
for CMD in sha256sum sha1sum md5sum md5; do
 if command -v "$CMD" >/dev/null 2>&1; then HASH_TOOL=$CMD; break; fi
done
case "$HASH_TOOL" in sha256sum) HASH_ALGORITHM=sha256; HASH_LENGTH=64 ;; sha1sum) HASH_ALGORITHM=sha1; HASH_LENGTH=40 ;; md5sum|md5) HASH_ALGORITHM=md5; HASH_LENGTH=32 ;; *) HASH_ALGORITHM=unavailable; HASH_LENGTH=0; PARTIAL=1 ;; esac
printf '%s\n' "$HASH_ALGORITHM" > "$OUT/HASH-ALGORITHM.txt" || exit 1
printf 'result\tbytes\tsource\tdestination\tdigest\n' > "$OUT/files.tsv" || exit 1
: > "$OUT/seen.txt" || exit 1
if [ -f "$USB/VEHICLE-DETAILS.txt" ] && [ ! -L "$USB/VEHICLE-DETAILS.txt" ]; then
 if DETAILS_SIZE=$(file_size "$USB/VEHICLE-DETAILS.txt") && [ "$DETAILS_SIZE" -le 4096 ]; then
  cp "$USB/VEHICLE-DETAILS.txt" "$OUT/VEHICLE-DETAILS.txt" || exit 1
 else echo 'Vehicle details size unavailable or exceeds 4 KiB.'; PARTIAL=1; fi
fi
digest() {
 [ -n "$HASH_TOOL" ] || return 1
 HASH_OUTPUT=$("$HASH_TOOL" "$1") || return 1
 for TOKEN in $HASH_OUTPUT; do
  case "$TOKEN" in *[!0123456789abcdefABCDEF]*|'') continue ;; esac
  if [ "${#TOKEN}" = "$HASH_LENGTH" ]; then printf '%s\n' "$TOKEN"; return 0; fi
 done
 return 1
}
note() { printf '%s\n' "$*" >> "$OUT/notes.txt" || exit 1; }
known_state() {
 case "$1" in
 c8facf373f015b042ab3fa89f14686f713e059726172c463107174abeeb1e4a3|49aceffd478aa993fec24933a78f4a451d80521a|588064a3c0e03cd56ed94bf0a4851d4b) echo known-stock-260507 ;;
 6eee1a24a91aa90a8747a38c06989e3a5debeadcd6758e8d6dca792e2c4540bc|fb12ca5eff247a49901a8f5fa756f28c6e8618ea|12ca0438d1d9f222758c82f767b67d0c) echo known-app-offline-patch-260507 ;;
 *) echo unknown-requires-code-inspection ;;
 esac
}
copy_file() {
 SRC=$1
 [ -f "$SRC" ] || return
 case "$SRC" in */../*|*/./*|*/..|*/.) note 'Refused path traversal.'; PARTIAL=1; return ;; esac
 case "$SRC" in /system/*|/vendor/*|/product/*|/system_ext/*|/data/app/*|/data/nemesis/backup/keybord.ota-app-offline/original.odex) ;; *) note "Refused source outside code roots: $SRC"; PARTIAL=1; return ;; esac
 # Reject unusual path characters; never interpret source names as commands.
 case "$SRC" in *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/._+@=-]*) note 'Skipped an unusual code path.'; PARTIAL=1; return ;; esac
 [ ! -L "$SRC" ] || { note "Skipped symlink: $SRC"; PARTIAL=1; return; }
 # Also refuse symlinked parent directories, including /data/app aliases.
 PARENT=${SRC%/*}
 while [ "$PARENT" != / ] && [ -n "$PARENT" ]; do
  [ ! -L "$PARENT" ] || { note "Skipped symlinked parent: $SRC"; PARTIAL=1; return; }
  PARENT=${PARENT%/*}
 done
 while IFS= read -r PREVIOUS; do [ "$PREVIOUS" != "$SRC" ] || return; done < "$OUT/seen.txt"
 printf '%s\n' "$SRC" >> "$OUT/seen.txt" || exit 1
 SIZE=$(file_size "$SRC") || { note "Cannot size: $SRC"; PARTIAL=1; return; }
 if [ "$SIZE" -gt "$MAX_FILE_BYTES" ] || [ "$COUNT" -ge "$MAX_FILES" ] || [ "$((TOTAL + SIZE))" -gt "$MAX_TOTAL_BYTES" ]; then
  note "Collection size limit: $SRC ($SIZE bytes)"; PARTIAL=1; return
 fi
 REL="files$SRC"
 DEST="$OUT/$REL"
 mkdir -p "${DEST%/*}" || exit 1
 BEFORE=$(digest "$SRC") || BEFORE=unavailable
 if ! cp "$SRC" "$DEST"; then
  printf 'COPY_FAILED\t%s\t%s\t%s\t-\n' "$SIZE" "$SRC" "$REL" >> "$OUT/files.tsv" || exit 1
  PARTIAL=1; return
 fi
 COUNT=$((COUNT + 1))
 TOTAL=$((TOTAL + SIZE))
 COPIED=$(digest "$DEST") || COPIED=unavailable
 AFTER=$(digest "$SRC") || AFTER=unavailable
 RESULT=VERIFIED
 if [ "$BEFORE" = unavailable ] || [ "$BEFORE" != "$COPIED" ] || [ "$BEFORE" != "$AFTER" ]; then RESULT=UNVERIFIED_OR_CHANGED; PARTIAL=1; fi
 printf '%s\t%s\t%s\t%s\t%s\n' "$RESULT" "$SIZE" "$SRC" "$REL" "$COPIED" >> "$OUT/files.tsv" || exit 1
 case "$SRC" in *[Oo][Tt][Aa]*.apk|*[Oo][Tt][Aa]*.odex|*[Dd][Mm][Cc]lient*.apk|*[Dd][Mm][Cc]lient*.odex) OTA_COUNT=$((OTA_COUNT + 1)) ;; esac
 case "$SRC" in */HKMC_DMClient_OTA.odex)
  printf '%s\t%s\n' "$SRC" "$(known_state "$COPIED")" >> "$OUT/known-file-state.txt" || exit 1 ;;
 esac
}
copy_bundle() {
 BUNDLE=$1
 copy_file "$BUNDLE"
 # Original ODEX and newer oat layouts, without assuming an Android version.
 copy_file "${BUNDLE%.apk}.odex"
 for SIDE in "${BUNDLE%/*}"/oat/*/*.odex "${BUNDLE%/*}"/oat/*/*.vdex "${BUNDLE%/*}"/oat/*/*.art; do copy_file "$SIDE"; done
}
printf 'property\tvalue\n' > "$OUT/build.tsv" || exit 1
for PROP in ro.product.manufacturer ro.product.brand ro.product.model ro.product.device ro.product.name ro.board.platform ro.hardware ro.build.version.release ro.build.version.sdk ro.build.version.incremental ro.build.id ro.build.display.id ro.build.fingerprint ro.product.ota ro.product.cpu.abi ro.product.cpu.abi2; do
 VALUE=$(getprop "$PROP") || { VALUE=READ_FAILED; PARTIAL=1; }
 printf '%s\t%s\n' "$PROP" "$VALUE" >> "$OUT/build.tsv" || exit 1
done
printf 'component\tpresent\n' > "$OUT/blockers.tsv" || exit 1
for FILE in /data/hmgapi/uninstall.sh /data/nemesis/apps/hmgapi/NEMESIS.data /data/nemesis/apps/gen5w.ota-blocker/NEMESIS.data /data/nemesis/backup/keybord.ota-app-offline/original.odex; do
 if [ -f "$FILE" ]; then PRESENT=yes; else PRESENT=no; fi
 printf '%s\t%s\n' "$FILE" "$PRESENT" >> "$OUT/blockers.tsv" || exit 1
done
# Shell globs avoid find, which was absent on the earlier head unit.
for BASE in /system/app /system/priv-app /vendor/app /vendor/priv-app /product/app /product/priv-app /system_ext/app /system_ext/priv-app; do
 for APP in "$BASE"/*.apk "$BASE"/*/*.apk; do
  case "${APP##*/}" in *[Oo][Tt][Aa]*|*[Dd][Mm][Cc]lient*|*[Ff][Oo][Tt][Aa]*|*[Uu]pdat*) copy_bundle "$APP" ;; esac
 done
done
if command -v pm >/dev/null 2>&1; then
 # Keep only matching package lines; do not save the installed-app inventory.
 if PACKAGE_OUTPUT=$(pm list packages -f 2>/dev/null); then
  printf '%s\n' "$PACKAGE_OUTPUT" | while IFS= read -r LINE; do
   case "$LINE" in *[Oo][Tt][Aa]*|*[Dd][Mm][Cc]lient*|*[Ff][Oo][Tt][Aa]*|*[Uu]pdat*) printf '%s\n' "$LINE" ;; esac
  done > "$OUT/target-packages.txt" || exit 1
  while IFS= read -r LINE; do
   case "$LINE" in package:*=*) PATH_AND_ID=${LINE#package:}; APP_PATH=${PATH_AND_ID%=*}; case "$APP_PATH" in *.apk) copy_bundle "$APP_PATH" ;; esac ;; esac
  done < "$OUT/target-packages.txt"
 else note 'Package manager query failed; filesystem scan still attempted.'; PARTIAL=1; fi
else note 'Package manager unavailable; filesystem scan still attempted.'; PARTIAL=1; fi
# Include the exact legacy code backup if present, never app data directories.
copy_file /data/nemesis/backup/keybord.ota-app-offline/original.odex
# Common framework dependencies for subsequent offline ODEX inspection.
for NAME in core core-libart conscrypt okhttp bouncycastle ext framework framework2 telephony-common voip-common ims-common mms-common android.policy services; do
 copy_file "/system/framework/$NAME.jar"
 copy_file "/system/framework/$NAME.odex"
done
for FILE in /system/framework/arm/boot*.oat /system/framework/arm64/boot*.oat; do copy_file "$FILE"; done
if [ "$OTA_COUNT" = 0 ]; then note 'No matching OTA APK/ODEX found. This is not proof the vehicle has no OTA.'; PARTIAL=1; fi
printf 'copied_files=%s\ncopied_bytes=%s\nota_candidates=%s\n' "$COUNT" "$TOTAL" "$OTA_COUNT" > "$OUT/summary.txt" || exit 1
echo 'A capture is evidence for inspection, not proof of blocker compatibility.' > "$OUT/INTERPRETATION.txt" || exit 1
if [ "$PARTIAL" = 0 ]; then STATUS=COMPLETE; else STATUS=PARTIAL; fi
printf '%s\n' "$STATUS" > "$OUT/STATUS.txt" || exit 1
echo "Collection $STATUS: $COUNT files, $TOTAL bytes."
echo 'ZIP this result folder on your computer and share privately for inspection. No restart needed.'
exit 0
