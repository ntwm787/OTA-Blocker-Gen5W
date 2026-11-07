"""Workspace-only simulations; never execute the collector against a vehicle."""
from pathlib import Path
import hashlib
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BASH = Path('C:/Program Files/Git/usr/bin/bash.exe')
SCRATCH = Path.cwd() / 'work' / 'collector-tests'
SCRATCH.mkdir(parents=True, exist_ok=True)


def unix(path):
    path = path.resolve()
    return '/' + path.drive[0].lower() + path.as_posix()[2:]


def snapshot(unit):
    return {str(p.relative_to(unit)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in unit.rglob('*') if p.is_file()}


def run_case(mode='normal', present=True):
    case = Path(tempfile.mkdtemp(prefix=mode + '-', dir=SCRATCH))
    unit, usb = case / 'unit', case / 'usb'
    usb.mkdir()
    unit.mkdir()
    (usb / 'OTA-COMPATIBILITY.marker').write_text('test')
    details = 'Make: Test\nModel: Fixture\nModel year: 2024\n'
    (usb / 'VEHICLE-DETAILS.txt').write_text(details)
    files = {
        'system/app/HKMC_DMClient_OTA.apk': b'fake-OTA-APK',
        'system/app/HKMC_DMClient_OTA.odex': b'fake-OTA-ODEX',
        'system/priv-app/Updater/Updater.apk': b'newer-updater',
        'system/priv-app/Updater/oat/arm/Updater.vdex': b'newer-vdex',
        'system/framework/core.odex': b'fake-framework',
        'data/app/renamed/base.apk': b'package-manager-found-code',
        'data/nemesis/backup/keybord.ota-app-offline/original.odex': b'backup-code',
        'data/hmgapi/uninstall.sh': b'presence-only-do-not-copy',
        'data/private/secret.apk': b'DO NOT COLLECT',
        'system/app/Unrelated.apk': b'DO NOT COLLECT',
    }
    if not present:
        files = {'data/private/secret.apk': b'DO NOT COLLECT'}
    for name, data in files.items():
        path = unit / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    before = snapshot(unit)
    script = (ROOT / 'NEMESIS.sh').read_text()
    script = script.replace('export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin',
                            'export PATH=/usr/bin:/bin')
    guard = next(line for line in script.splitlines() if line.startswith('case "$USB" in'))
    script = script.replace(guard, ': # test-only USB location')
    # Redirect every head-unit source root into the fake unit, including allowlists.
    for source_root in ['system', 'vendor', 'product', 'system_ext', 'data']:
        script = script.replace('/' + source_root + '/', unix(unit) + '/' + source_root + '/')
    mock = '''
id() { echo 'uid=0(root) gid=0(root)'; }
getprop() {
 [ "$#" = 1 ] || return 1
 case "$1" in
 sys.boot_completed) echo 1 ;;
 ro.product.device) echo wp_daudioplus_neev24_us ;;
 ro.build.version.sdk) echo 19 ;;
 ro.build.version.incremental) echo eng.vmadmin.20260507.094910 ;;
 ro.product.ota) echo redbend ;;
 ro.*) echo fixture ;;
 *) return 1 ;;
 esac
}
pm() {
 [ "$*" = 'list packages -f' ] || return 1
 echo 'package:UNIT/data/app/renamed/base.apk=com.hkmc.ota'
 echo 'package:UNIT/system/app/HKMC_DMClient_OTA.apk=com.hkmc.dmclient.ota'
 echo 'package:UNIT/data/private/secret.apk=com.unrelated'
 echo 'package:UNIT/system/../data/private/secret.apk=com.ota.traversal'
}
'''.replace('UNIT', unix(unit))
    if mode != 'traversal':
        mock = '\n'.join(line for line in mock.splitlines() if 'com.ota.traversal' not in line)
    if not present:
        mock += '\npm() { return 0; }\n'
    if mode == 'nonroot':
        mock += '\nid() { echo "uid=2000(shell) gid=2000(shell)"; }\n'
    if mode == 'booting':
        mock = mock.replace('sys.boot_completed) echo 1', 'sys.boot_completed) echo 0')
    if mode == 'copyfailure':
        mock += '\ncp() { case "$1" in */HKMC_DMClient_OTA.apk) return 1 ;; esac; command cp "$@"; }\n'
    if mode == 'changed':
        mock += '\ncp() { command cp "$@" || return; case "$1" in */HKMC_DMClient_OTA.apk) printf changed >> "$1" ;; esac; }\n'
    if mode == 'nohash':
        mock += '\ncommand() { case "$*" in "-v sha256sum"|"-v sha1sum"|"-v md5sum"|"-v md5") return 1 ;; esac; builtin command "$@"; }\n'
    if mode == 'limits':
        script = script.replace('MAX_FILE_BYTES=67108864', 'MAX_FILE_BYTES=5')
    script = script.replace('umask 077', 'umask 077\n' + mock)
    executable = usb / 'NEMESIS.sh'
    executable.write_text(script, newline='\n')
    result = subprocess.run([str(BASH), unix(executable)], capture_output=True, text=True,
                            env={**os.environ, 'MSYS_NO_PATHCONV': '1'}, timeout=30)
    outputs = list(usb.glob('OTA-Compatibility-*'))
    if mode in ['nonroot', 'booting']:
        assert result.returncode != 0
        assert not outputs
    else:
        assert result.returncode == 0, (result.stdout, result.stderr)
        assert len(outputs) == 1
        out = outputs[0]
        status = (out / 'STATUS.txt').read_text().strip()
        assert status == ('COMPLETE' if mode == 'normal' and present else 'PARTIAL'), status
        manifest = (out / 'files.tsv').read_text()
        assert 'secret.apk' not in manifest
        assert 'Unrelated.apk' not in manifest
        assert 'uninstall.sh' not in manifest
        assert (out / 'VEHICLE-DETAILS.txt').read_text() == details
        if mode == 'normal' and present:
            rows = manifest.splitlines()[1:]
            assert len(rows) == 7, rows
            for row in rows:
                state, size, source, destination, digest = row.split('\t')
                assert state == 'VERIFIED'
                data = (out / destination).read_bytes()
                assert len(data) == int(size)
                assert hashlib.sha256(data).hexdigest() == digest
            assert 'Updater.vdex' in manifest
            assert 'renamed/base.apk' in manifest
            assert (out / 'known-file-state.txt').read_text().endswith('unknown-requires-code-inspection\n')
        if mode == 'changed':
            assert 'UNVERIFIED_OR_CHANGED' in manifest
        if mode == 'copyfailure':
            assert 'COPY_FAILED' in manifest
    if mode != 'changed':
        assert snapshot(unit) == before, 'Collector changed source files'
    print('PASS:', mode, 'with OTA files' if present else 'without OTA files')


subprocess.run([str(BASH), '-n', str(ROOT / 'NEMESIS.sh')], check=True)
for scenario in ['normal', 'nonroot', 'booting', 'copyfailure', 'changed', 'nohash', 'limits', 'traversal']:
    run_case(scenario)
run_case(present=False)
print('All collector simulations passed; no vehicle or host system files were used.')
