"""Read-only reproduction of this pinned plugin's font-function lookup in this Game.dll."""
from pathlib import Path
import hashlib,json,sys,struct
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'build/analysis-deps'))
import pefile
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
plugin=pefile.PE(str(root/'build/engine-pe/pe-60ae0.dll'))
pattern=plugin.get_data(0x64caf4,13)
game_path=Path('D:/Program Files (x86)/Warcraft III Frozen Throne/Game.dll')
data=game_path.read_bytes();game=pefile.PE(data=data);base=game.OPTIONAL_HEADER.ImageBase
md=Cs(CS_ARCH_X86,CS_MODE_32)
report={'game_sha256':hashlib.sha256(data).hexdigest(),'game_base':hex(base),'lookup_pattern':pattern.hex(),'matches':[]}
assert report['game_sha256']=='e04d1716603c075eb0c8e1e21cf1093a664adc5249efab396bfa08d7b09d0c3a','Game.dll changed'
start=0
while True:
 off=data.find(pattern,start)
 if off<0:break
 start=off+1;address=base+game.get_rva_from_offset(off)
 row={'file_offset':hex(off),'va':hex(address),'references':[]}
 for section in game.sections:
  if not section.Characteristics & 0x20000000:continue
  chunk=section.get_data();pos=0
  while True:
   pos=chunk.find(struct.pack('<I',address),pos)
   if pos<0:break
   va=base+section.VirtualAddress+pos
   if pos>=24:
    displacement=struct.unpack_from('<i',chunk,pos-0x17)[0]
    target=va-0x13+displacement
    ref={'operand_va':hex(va),'call_opcode_before':hex(chunk[pos-0x18]),'candidate_font_function':hex(target),
     'site':[f'{i.address:08x}: {i.mnemonic} {i.op_str}' for i in md.disasm(chunk[pos-0x20:pos+20],va-0x20)]}
    if chunk[pos-0x18]==0xe8 and 0<=target-base<game.OPTIONAL_HEADER.SizeOfImage:
     instructions=[]
     for ins in md.disasm(game.get_data(target-base,600),target):
      instructions.append(f'{ins.address:08x}: {ins.mnemonic} {ins.op_str}')
      if ins.mnemonic=='ret':break
     ref['function']=instructions
    row['references'].append(ref)
   pos+=4
 report['matches'].append(row)
report['downstream']={}
for rva,extent in [(0x99ac0,48),(0x17f870,400),(0x78a260,14),(0xcebd0,260),(0xda530,255),(0xd0310,100)]:
 report['downstream'][hex(base+rva)]=[f'{i.address:08x}: {i.mnemonic} {i.op_str}' for i in md.disasm(game.get_data(rva,extent),base+rva)]
report['clamp_constant']={'va':'0x6f950d8c','float32':struct.unpack('<f',game.get_data(0x950d8c,4))[0]}
report['conversion_constant']={'va':'0x6f97b498','float32':struct.unpack('<f',game.get_data(0x97b498,4))[0]}
out=root/'research/evidence/game-font-trace.json';out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'conversion':report['downstream']['0x6f0d0310'],'constants':[report['clamp_constant'],report['conversion_constant']]},indent=2))
