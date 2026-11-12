"""Read-only, hash-pinned InnerJAPI / local DZ implementation comparison."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build/analysis-deps'))
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_32

SAMPLES = [
    ('inner', ROOT / 'build/engine-pe/pe-60ae0.dll',
     '5c44196eb2b82a11ccf8754a259193db86dc4c823140887b0442741d48132a8c', [
         ('create-registration', 0x102527b2, 0x102527c9),
         ('viewport-registration', 0x10252dbd, 0x10252dd4),
         ('create-wrapper', 0x10249740, 0x102497a5),
         ('create-body', 0x102492e0, 0x10249736),
         ('viewport', 0x1024bdd0, 0x1024bdf3),
         ('game-fdf-locator', 0x102485b0, 0x1024868e),
     ]),
    ('dz-local', Path('D:/War3/tools/LanTest/runtime/WE/plugin/warcraft3/kkapi_local_plugin.dll'),
     '346aa2fa320b7919d95e7cd56792858331f6c224c5459652e166f36c832c8ee3', [
         ('create-by-tag-body', 0x10084690, 0x1008484e),
         ('type-factory', 0x10073c40, 0x10073d60),
         ('clip-registration-func-name-signature', 0x10089f99, 0x10089fba),
         ('clip-setter', 0x10086900, 0x10086920),
         ('cliprect-registration-func-name-signature', 0x1008a104, 0x1008a125),
         ('cliprect-global-setter', 0x10084a50, 0x10084a90),
     ]),
]

report = {'scope': 'disk static analysis only; no runtime execution or UI validation', 'samples': []}
lines = []
for label, path, expected, ranges in SAMPLES:
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    assert digest == expected, f'Unrecognized image: {path}'
    pe = pefile.PE(data=data)
    base = pe.OPTIONAL_HEADER.ImageBase
    md = Cs(CS_ARCH_X86, CS_MODE_32)
    row = {'label': label, 'path': str(path), 'sha256': digest, 'image_base': hex(base),
           'ranges': [], 'string_presence': {}}
    for name in ['FrameSetViewPort', 'DzFrameSetViewPort', 'JAPI::GUI::DzCreateFrameByTagName']:
        row['string_presence'][name] = (name.encode() + b'\0') in data
    for name, start, end in ranges:
        row['ranges'].append({'name': name, 'start_va': hex(start), 'end_va_exclusive': hex(end)})
        lines.append(f'[{label}] {name} VA {start:#x}..{end:#x}')
        lines.extend(f'{i.address:08x}: {i.mnemonic} {i.op_str}'.rstrip()
                     for i in md.disasm(pe.get_data(start-base, end-start), start))
    report['samples'].append(row)
dest = ROOT / 'research/evidence'
(dest / 'ui-native-comparison.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
(dest / 'ui-native-comparison.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print('Verified both image hashes; wrote static comparison evidence. No DLL loaded.')
