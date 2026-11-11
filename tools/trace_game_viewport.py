"""Locate candidate consumers of the frame viewport bit in the pinned Game.dll (read only)."""
from pathlib import Path
import hashlib,json,sys,re
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'build/analysis-deps'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
p=Path('D:/Program Files (x86)/Warcraft III Frozen Throne/Game.dll')
data=p.read_bytes();pe=pefile.PE(data=data);base=pe.OPTIONAL_HEADER.ImageBase
assert hashlib.sha256(data).hexdigest()=='e04d1716603c075eb0c8e1e21cf1093a664adc5249efab396bfa08d7b09d0c3a'
md=Cs(CS_ARCH_X86,CS_MODE_32);md.skipdata=True
rows=[]
register_rows=[]
for section in pe.sections:
 if not section.Characteristics & 0x20000000:continue
 history=[]
 for address,size,mnemonic,op in md.disasm_lite(section.get_data(),base+section.VirtualAddress):
  line=f'{address:08x}: {mnemonic} {op}'
  if mnemonic=='test' and '+ 0xc]' in op and op.endswith(', 1') and '[esp' not in op and '[ebp' not in op:
   rows.append({'address':hex(address),'before':history[-6:],'instruction':line,
    'after':[f'{i.address:08x}: {i.mnemonic} {i.op_str}' for i in md.disasm(pe.get_data(address-base+size,85),address+size)]})
  if mnemonic in ('test','and') and op.endswith(', 1'):
   register=op.split(',')[0]
   aliases={'al':'eax','cl':'ecx','dl':'edx','bl':'ebx'}
   full=aliases.get(register,register)
   if any(re.search(r'mov '+full+r', .*\+ 0xc\]',h) for h in history):
    register_rows.append({'address':hex(address),'before':history[:],'instruction':line,
     'after':[f'{i.address:08x}: {i.mnemonic} {i.op_str}' for i in md.disasm(pe.get_data(address-base+size,85),address+size)]})
  history.append(line)
  if len(history)>6:history.pop(0)
(root/'research/evidence/game-viewport-candidates.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
(root/'research/evidence/game-viewport-register-candidates.json').write_text(json.dumps(register_rows,indent=2)+'\n',encoding='utf-8')
print('memory candidates',len(rows),'register candidates',len(register_rows))
print(json.dumps([r for r in register_rows if int(r['address'],16)<0x6f200000],indent=2))
