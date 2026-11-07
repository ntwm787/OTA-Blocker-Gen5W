"""Build USB/source deliverables without collecting local firmware or test results."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib

ROOT = Path(__file__).resolve().parent
USB_FILES = ['NEMESIS.data', 'NEMESIS.sh', 'OTA-COMPATIBILITY.marker',
             'VEHICLE-DETAILS.txt', 'README.md', 'LICENSE']
ARTIFACTS = [('OTA Compatibility Collector USB 1.0.0.zip', USB_FILES),
             ('OTA Compatibility Collector Source 1.0.0.zip',
              USB_FILES + ['build.py', 'tests/test_collector.py', 'VALIDATION.md'])]
for name, files in ARTIFACTS:
    with ZipFile(ROOT / name, 'w', ZIP_DEFLATED) as archive:
        for file in files:
            archive.write(ROOT / file, file)
    with ZipFile(ROOT / name) as archive:
        assert archive.testzip() is None
(ROOT / 'SHA256SUMS.txt').write_text(''.join(
    hashlib.sha256((ROOT / name).read_bytes()).hexdigest() + '  ' + name + '\n'
    for name, _ in ARTIFACTS), encoding='utf-8', newline='\n')
print('Built USB and source ZIPs; checksums updated.')
