# Validation

Local validation only; the collector has not yet been run on a head unit.

The shell script passes Git Bash syntax checking. Mocked execution covers conventional Gen5W-style APK/ODEX files, a nested updater with a VDEX companion, a renamed APK located through the package manager, deduplication, framework code and the existing original backup. Manifest hashes are verified against copied bytes.

Refusal/incomplete cases cover non-root execution, Android not fully started, failed copy, a source changing during copying, unavailable checksum tools, size limits and no recognizable OTA files. Snapshots verify source files are unchanged except in the deliberately injected concurrent-change test. Unrelated apps, private app data, traversal paths and the HMG-API uninstall script are excluded.

Tests use fake bytes, not proprietary firmware. They validate collection behavior, not Android runtime compatibility, shell-tool availability on every unit, comprehensive update coverage, or OTA blocking.

Version 1.0.1 passed a simulation with wc unavailable and KitKat toolbox ls output. The reported vehicle still needs a retry to confirm its failure cause.
