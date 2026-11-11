"""Reproduce embedded-PE extraction and selected x86 disassembly; no DLL execution."""
from pathlib import Path
import hashlib,json,sys,struct
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'build/analysis-deps'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
carrier=root/'vendor/war3ui-1.49-9/package/plugin/wenhao_plugin.tga'
data=carrier.read_bytes();out=root/'build/engine-pe';out.mkdir(exist_ok=True)
report={'carrier_sha256':hashlib.sha256(data).hexdigest(),'images':[]}
pos=0
while True:
    pos=data.find(b'MZ',pos)
    if pos<0:break
    try:
        candidate=pefile.PE(data=data[pos:],fast_load=True)
        size=max(s.PointerToRawData+s.SizeOfRawData for s in candidate.sections)
        if size<=0 or pos+size>len(data):raise ValueError('invalid extent')
        image=data[pos:pos+size];name=f'pe-{pos:x}.dll';(out/name).write_bytes(image)
        report['images'].append({'offset':hex(pos),'size':size,'sha256':hashlib.sha256(image).hexdigest(),'file':name})
    except (pefile.PEFormatError,ValueError):pass
    pos+=2
evidence=root/'research/evidence';evidence.mkdir(parents=True,exist_ok=True)
(evidence/'embedded-images.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
image=(out/'pe-60ae0.dll').read_bytes();pe=pefile.PE(data=image);base=pe.OPTIONAL_HEADER.ImageBase
assert hashlib.sha256(image).hexdigest()=='5c44196eb2b82a11ccf8754a259193db86dc4c823140887b0442741d48132a8c'
md=Cs(CS_ARCH_X86,CS_MODE_32);md.skipdata=True
lines=[]
for name,start,end in [('viewport',0x1024bdd0,0x1024bdf3),('font',0x1024adf0,0x1024aef5),
                       ('destroy-frame',0x102491a0,0x102491d6),('register-frame-event',0x1024e4e0,0x1024e633),
                       ('frame-table-remove-a',0x102542a0,0x10254330),('frame-table-remove-b',0x10253ed0,0x10253f60),
                       ('j2b-loader',0x10299150,0x10299440)]:
    offset=pe.get_offset_from_rva(start-base)
    lines.append(f'{name} VA {start:#x} file offset {offset:#x}')
    lines += [f'{i.address:08x}: {i.mnemonic} {i.op_str}' for i in md.disasm(image[offset:offset+end-start],start)]
(evidence/'selected-native-disassembly.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')
# Candidate flag consumers only: offsets can refer to unrelated classes.
candidates=[]
for section in pe.sections:
    if not section.Characteristics & 0x20000000:continue
    history=[]
    for address,size,mnemonic,op in md.disasm_lite(section.get_data(),base+section.VirtualAddress):
        row=f'{address:08x}: {mnemonic} {op}'
        if mnemonic=='test' and '+ 0xc]' in op and op.endswith(', 1'):
            candidates.append({'address':hex(address),'context':history[-8:]+[row]})
        history.append(row)
        if len(history)>12:history.pop(0)
(evidence/'viewport-flag-candidates.json').write_text(json.dumps(candidates,indent=2)+'\n',encoding='utf-8')
print('PE extraction/disassembly complete; candidate flag consumers:',len(candidates))
