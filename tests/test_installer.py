from pathlib import Path
import subprocess,tempfile,shutil,hashlib,os
root=Path(__file__).resolve().parent.parent/'package'
import argparse
args=argparse.ArgumentParser();args.add_argument('--fixtures',type=Path,required=True);fixture=args.parse_args().fixtures

original=(fixture/'HKMC_DMClient_OTA.odex').read_bytes()
patched=(fixture/'patched.odex').read_bytes()
apk=(fixture/'HKMC_DMClient_OTA.apk').read_bytes()
bash='C:/Program Files/Git/usr/bin/bash.exe'
def unix(p):return '/'+p.drive[0].lower()+p.as_posix()[2:]
def setup():
 scratch=Path.cwd()/'work'/'simulations';scratch.mkdir(parents=True,exist_ok=True)
 p=Path(tempfile.mkdtemp(dir=scratch,prefix='ota-blocker-test-'))
 for f in root.glob('patch-*.bin'):shutil.copyfile(f,p/f.name)
 (p/'KEYBORD-OTA-OFFLINE.marker').write_text('test')
 (p/'live.odex').write_bytes(original);(p/'live.apk').write_bytes(apk)
 (p/'mounts').write_text('/dev/mock /system ext4 rw 0 0\n')
 return p
mock=r"""
id() { if [ "$#" != 0 ]; then return 1; fi; echo "${KBO_TEST_IDENTITY:-uid=0(root) gid=0(root)}"; }
getprop() { case "$1" in ro.product.device) echo "${KBO_TEST_DEVICE:-wp_daudioplus_neev24_us}" ;; ro.build.version.incremental) if [ "${KBO_TEST_BUILD:-}" != __EMPTY__ ]; then echo "${KBO_TEST_BUILD-eng.vmadmin.20260507.094910}"; fi ;; ro.build.version.sdk) echo "${KBO_TEST_SDK:-19}" ;; ro.product.ota) echo redbend ;; sys.boot_completed) echo 1 ;; esac; }
getenforce() { echo Permissive; }
nemesis() { touch "$USB/remount-called"; return 0; }
"""
def run(p,mode):
 s=(root/'scripts/engine.sh').read_text().replace('MODE=$1','MODE='+mode).replace('export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin','export PATH=/usr/bin:/bin')
 s=s.replace('USB=$(pwd)', 'USB="'+unix(p)+'"')
 s=s.replace('umask 077','umask 077\n'+mock)
 s=s.replace('-f /data/hmgapi/uninstall.sh', '-f "'+unix(p)+'/hmgapi-installed"')
 s=s.replace('LIVE=/system/app/HKMC_DMClient_OTA.odex',f'LIVE="{unix(p)}/live.odex"')
 s=s.replace('APK=/system/app/HKMC_DMClient_OTA.apk',f'APK="{unix(p)}/live.apk"')
 s=s.replace('BASE=/data/nemesis/backup/keybord.ota-app-offline',f'BASE="{unix(p)}/backup"')
 s=s.replace('TEMP="/system/app/.keybord-ota-offline-$$.tmp"',f'TEMP="{unix(p)}/live-pending.tmp"')
 s=s.replace('done < /proc/mounts',f'done < "{unix(p)}/mounts"')
 file=p/'NEMESIS.sh';file.write_text(s,newline='\n')
 return subprocess.run([bash,unix(file)],capture_output=True).returncode
for file in (root/'scripts').glob('*.sh'):subprocess.run([bash,'-n',str(file)],check=True)
p=setup();assert run(p,'apply')==0;assert (p/'live.odex').read_bytes()==patched;assert (p/'backup/original.odex').read_bytes()==original
assert run(p,'apply')==0;assert (p/'live.odex').read_bytes()==patched
assert run(p,'restore')==0;assert (p/'live.odex').read_bytes()==original
q=setup();(q/'live.apk').write_bytes(b'wrong');assert run(q,'apply')!=0;assert (q/'live.odex').read_bytes()==original
r=setup();(r/'live.odex').write_bytes(patched);assert run(r,'restore')!=0;assert (r/'live.odex').read_bytes()==patched
t=setup();(t/'backup').mkdir();(t/'backup/original.odex').write_bytes(b'wrong');assert run(t,'apply')!=0;assert (t/'live.odex').read_bytes()==original
u=setup();(u/'patch-0.bin').write_bytes(b'wrong');assert run(u,'apply')!=0;assert (u/'live.odex').read_bytes()==original
print('PASS: syntax; mocked apply, backup integrity, repeat apply, restore, APK mismatch refusal, missing-backup refusal, invalid-backup refusal, corrupt-payload refusal. No car interaction or system partition changes.')

for device in ['wp_daudioplus_neev23_us','wp_daudioplus_neev24_us','wp_daudioplus_neev25_us','wp_daudioplus_neev26_us','wp_daudioplus_neev27_us','wp_daudioplus_neev_us']:
 os.environ['KBO_TEST_DEVICE']=device
 p=setup();assert run(p,'apply')==0,device
 assert run(p,'restore')==0,device
for device,sdk in [('wp_daudioplus_other_model_us','19'),('ccnc_neev25_us','34'),('wp_daudioplus_neev24_us','34')]:
 os.environ['KBO_TEST_DEVICE']=device;os.environ['KBO_TEST_SDK']=sdk
 p=setup();assert run(p,'apply')!=0,(device,sdk)
 assert (p/'live.odex').read_bytes()==original
 assert not (p/'backup').exists()
print('PASS: IONIQ 5 family accepted across year identifiers; other model/platform/API rejected before backup or modification. Firmware and hashes remain required.')

os.environ.pop('KBO_TEST_DEVICE',None);os.environ.pop('KBO_TEST_SDK',None)
for identity in ['uid=2000(shell) gid=2000(shell)','uid=1000(system) gid=1000(system)','uid=00(root)','unrecognized','prefix uid=0(root)']:
 os.environ['KBO_TEST_IDENTITY']=identity
 p=setup();assert run(p,'apply')!=0,identity
 assert (p/'live.odex').read_bytes()==original
 assert not (p/'backup').exists()
os.environ['KBO_TEST_IDENTITY']='uid=0 gid=0'
p=setup();assert run(p,'apply')==0
assert run(p,'restore')==0
print('PASS: plain id used without options; explicit UID 0 accepted, non-root/malformed identities refused before backup or modification.')

os.environ.pop('KBO_TEST_IDENTITY',None)
p=setup(); assert run(p,'check')==0; assert not (p/'backup').exists(); assert (p/'live.odex').read_bytes()==original
(p/'live.odex').write_bytes(b'unknown'); assert run(p,'check')!=0; assert not (p/'backup').exists()
p=setup();(p/'live.odex').write_bytes(patched);assert run(p,'check')!=0
(p/'backup').mkdir();(p/'backup/original.odex').write_bytes(original);assert run(p,'check')==0;assert run(p,'apply')==0;assert run(p,'restore')==0
print('PASS: preinstall checks make no changes; manual patch adoption requires original backup and restores it.')

p=setup();(p/'hmgapi-installed').write_text('test');assert run(p,'check')!=0;assert run(p,'apply')!=0;assert not (p/'backup').exists()
print('PASS: HMG-API installation refuses check/apply before backup or patch.')

# Firmware refusal must precede backup, staging, remount, and live writes.
for build in ['eng.vmadmin.20260401.000000','eng.vmadmin.20260507.094911','', 'unknown']:
 os.environ['KBO_TEST_BUILD']=build if build else '__EMPTY__'
 for mode in ['check','apply']:
  p=setup();assert run(p,mode)!=0,(build,mode)
  assert (p/'live.odex').read_bytes()==original
  assert not (p/'backup').exists()
  assert not (p/'live-pending.tmp').exists()
  assert not (p/'remount-called').exists()
os.environ.pop('KBO_TEST_BUILD',None)
for target in ['live.apk','live.odex']:
 for mode in ['check','apply']:
  p=setup();(p/target).write_bytes(b'unsupported firmware file')
  before=(p/'live.odex').read_bytes()
  assert run(p,mode)!=0
  assert (p/'live.odex').read_bytes()==before
  assert not (p/'backup').exists()
  assert not (p/'remount-called').exists()
print('PASS: wrong/missing firmware and same-build file mismatches stop check/apply before backup, remount or live modification.')
