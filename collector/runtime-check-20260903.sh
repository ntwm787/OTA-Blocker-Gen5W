#!/system/bin/sh
# Copyright (C) 2026 ntwm787 and contributors
# SPDX-License-Identifier: GPL-3.0-only
# Read-only inspection. Does not launch OTAClient, request an update, or reboot.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib
umask 077
case "$0" in /*) USB=${0%/*} ;; *) USB=$(pwd) ;; esac
case "$USB" in /storage/usb[0-9]|/mnt/media_rw/usb[0-9]) ;; *) echo 'ERROR: Run from USB root.'; exit 1 ;; esac
[ -f "$USB/KEYBORD-OTA-RUNTIME.marker" ] || exit 1
OUT="$USB/KeyBORD-OTA-Runtime-$(date +%Y%m%d-%H%M%S)-$$"
mkdir "$OUT" || exit 1
{
 echo 'OTA runtime inspection for 20260903'
 echo 'Snapshot only: no claim of complete OTA protection.'
 echo '=== Identity / boot ==='
 id
 date
 cat /proc/uptime
 for KEY in ro.product.device ro.build.version.incremental ro.product.ota sys.boot_completed; do echo "$KEY=$(getprop "$KEY")"; done
 echo '=== OTA app and backup file checks ==='
 echo 'Expected 20260903 patched ODEX MD5: 36391261a1ccac309d40d04fb795e208'
 TOOL=
 for CMD in sha256sum sha1sum md5sum md5; do
  if command -v "$CMD" >/dev/null 2>&1; then TOOL=$CMD; break; fi
 done
 if [ -n "$TOOL" ]; then
  echo "Checksum tool: $TOOL"
  for FILE in /system/app/HKMC_DMClient_OTA.apk /system/app/HKMC_DMClient_OTA.odex /data/nemesis/backup/gen5w.ota-blocker-20260903/original.odex; do
   "$TOOL" "$FILE" || echo "UNKNOWN: cannot checksum $FILE"
  done
 else
  echo 'UNKNOWN: no supported checksum utility'
 fi
 echo '=== System mount / labels ==='
 grep ' /system ' /proc/mounts
 getenforce
 ls -lZ /system/app/HKMC_DMClient_OTA.odex
 echo '=== Relevant processes ==='
 ps | grep -i -E 'OTAClient|DMClient|otaagent|uagent|ModemFoTA'
 echo '=== OTA app service snapshot ==='
 dumpsys activity services com.hkmc.system.app.OTAClient
 echo '=== Package code state ==='
 dumpsys package com.hkmc.system.app.OTAClient | grep -i -E 'codePath|resourcePath|versionCode|versionName|userId|enabled=|stopped=|pkgFlags|dataDir'
 echo '=== Native service state (read only) ==='
 for KEY in init.svc.otaagentd init.svc.uagentd; do echo "$KEY=$(getprop "$KEY")"; done
 echo 'End of snapshot. An absent process or error does not prove OTA is blocked.'
} > "$OUT/report.txt" 2>&1
if [ ! -s "$OUT/report.txt" ]; then echo 'ERROR: Could not save a report to USB.'; exit 1; fi
# A finite snapshot of existing buffers only; never clear logs or start an app.
# Filtering is intentionally broad enough to catch Dalvik loading failures.
logcat -d -v threadtime 2> "$OUT/logcat-errors.txt" | grep -i -E 'OTAClient|HKMC_DMClient_OTA|COMMS_SOCKET_ERROR|VdmRawConnection|VdmException|VerifyError|DexOpt|Unable to (open|optimize).*dex|Class ref in pre-verified class|FATAL EXCEPTION' > "$OUT/relevant-logcat.txt"
if [ ! -s "$OUT/relevant-logcat.txt" ]; then
 echo 'No matching runtime events were captured. Inspect logcat-errors.txt for diagnostic errors.' >> "$OUT/report.txt"
fi
echo 'Read-only snapshot saved:' 
echo "$OUT"
echo 'Some diagnostic commands may be unsupported; retain all result files.'
echo 'This does not establish OTA blocking or USB-update compatibility.'
exit 0
