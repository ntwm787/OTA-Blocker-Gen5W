from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
root=Path(__file__).resolve().parent
pkg=root/'package'
with ZipFile(root/'gen5w.ota-blocker.zip','w',ZIP_DEFLATED) as z:
 for p in sorted(pkg.rglob('*')):
  if p.is_file(): z.write(p,p.relative_to(pkg).as_posix())
with ZipFile(root/'OTA Blocker USB 1.0.0 RC.zip','w',ZIP_DEFLATED) as z:
 z.writestr('NEMESIS.data','[nemesis]\nversion=1.0\ntype=install\npath=packages/gen5w.ota-blocker.zip\n')
 z.write(root/'gen5w.ota-blocker.zip','packages/gen5w.ota-blocker.zip')
 z.write(pkg/'README.md','README.md')
 z.write(pkg/'LICENSE','LICENSE')
with ZipFile(root/'OTA Blocker Source 1.0.0 RC.zip','w',ZIP_DEFLATED) as z:
 for folder in ['package','tests']:
  for p in sorted((root/folder).rglob('*')):
   if p.is_file() and '__pycache__' not in p.parts: z.write(p,p.relative_to(root).as_posix())
 z.write(root/'build.py','build.py')
 for name in ['README.md','LICENSE','.gitignore','.gitattributes']:
  if (root/name).is_file(): z.write(root/name,name)
 if (root/'VALIDATION.md').is_file(): z.write(root/'VALIDATION.md','VALIDATION.md')
(root/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in sorted(root.glob('*.zip'))),encoding='utf-8')
