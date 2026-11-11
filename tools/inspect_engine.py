"""Read-only PE string/xref inventory; never load or execute the native carrier."""
from pathlib import Path
import argparse, hashlib, json, struct, sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'build/analysis-deps'))
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_32

parser=argparse.ArgumentParser()
parser.add_argument('--image',default='vendor/war3ui-1.49-9/package/plugin/wenhao_plugin.tga')
parser.add_argument('--output',default='engine-static.json')
args=parser.parse_args()
path = ROOT/args.image
data = path.read_bytes()
pe = pefile.PE(data=data)
base = pe.OPTIONAL_HEADER.ImageBase
md = Cs(CS_ARCH_X86, CS_MODE_32); md.skipdata = True
report = {'image':args.image,'sha256':hashlib.sha256(data).hexdigest(),'size':len(data),'machine':hex(pe.FILE_HEADER.Machine),
          'image_base':hex(base),'entry_rva':hex(pe.OPTIONAL_HEADER.AddressOfEntryPoint),
          'sections':[],'imports':[],'exports':[],'strings':[]}
for s in pe.sections:
    report['sections'].append({'name':s.Name.rstrip(b'\0').decode(errors='replace'),
        'rva':hex(s.VirtualAddress),'raw_offset':s.PointerToRawData,'raw_size':s.SizeOfRawData})
for dll in getattr(pe,'DIRECTORY_ENTRY_IMPORT',[]):
    report['imports'].append({'dll':dll.dll.decode(errors='replace'),
        'symbols':[(i.name or str(i.ordinal).encode()).decode(errors='replace') for i in dll.imports]})
for e in getattr(getattr(pe,'DIRECTORY_ENTRY_EXPORT',None),'symbols',[]):
    report['exports'].append({'name':(e.name or b'').decode(errors='replace'),'rva':hex(e.address)})
needles = ['jass2binary','FrameSetViewPort','FrameSetTextFont','compile_script','plugin_main',
           'SetScissorRect','D3DXCreateFont','CreateFont','Scissor','console_enable','DestroyFrame','RegisterFrameEvent']
for needle in needles:
    start = 0
    while True:
        off = data.find(needle.encode(), start)
        if off < 0: break
        start = off+len(needle)
        try: va=base+pe.get_rva_from_offset(off)
        except pefile.PEFormatError: continue
        end = data.find(b'\0',off)
        row={'text':data[off:min(end,off+120)].decode(errors='replace'),'file_offset':off,'va':hex(va),'xrefs':[]}
        packed = struct.pack('<I',va)
        for s in pe.sections:
            if not s.Characteristics & 0x20000000: continue
            chunk = s.get_data(); pos=0
            while True:
                pos=chunk.find(packed,pos)
                if pos<0: break
                lo=max(0,pos-48); hi=min(len(chunk),pos+72)
                row['xrefs'].append({'operand_va':hex(base+s.VirtualAddress+pos),
                    'disassembly':[f'{i.address:08x}: {i.mnemonic} {i.op_str}' for i in md.disasm(chunk[lo:hi],base+s.VirtualAddress+lo)]})
                pos+=4
        report['strings'].append(row)
dest=ROOT/'research/evidence'; dest.mkdir(parents=True,exist_ok=True)
(dest/args.output).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('READ-ONLY PE',hex(base),'sections',[(s['name'],s['raw_size']) for s in report['sections']])
for row in report['strings']:
    print(row['text'],row['va'],'xrefs',[r['operand_va'] for r in row['xrefs']])
