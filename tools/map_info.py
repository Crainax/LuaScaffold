"""Write classic W3I v25 metadata with six explicit slots and no object overrides.
Field layout checked against w3x2lni 2.7.3 frontend/backend_w3i.lua.
"""
import struct

def build_info(source, title, author):
    assert struct.unpack_from('<I', source)[0] == 25
    pos = 12
    for _ in range(4): pos=source.index(b'\0',pos)+1
    bounds=struct.unpack_from('<8f',source,pos)
    # Camera, camera complements, playable size, flags, tileset.
    fixed=source[pos:pos+61]
    pos+=61
    # Loading screen ID + four strings, data set + four prologue strings.
    pos+=4
    for _ in range(4): pos=source.index(b'\0',pos)+1
    pos+=4
    for _ in range(4): pos=source.index(b'\0',pos)+1
    pos+=24 # fog style, three floats, color, global weather ID
    pos=source.index(b'\0',pos)+1 # sound environment
    pos+=5 # light environment, water color
    players=struct.unpack_from('<I',source,pos)[0]
    assert 1<=players<=24, 'invalid W3I source layout'
    first_strings=b'\0'.join([title.encode('utf-8'),author.encode('utf-8'),b'InnerJAPI Lua research',b'1-6',b''])
    oldpos=12
    for _ in range(4): oldpos=source.index(b'\0',oldpos)+1
    output=source[:12]+first_strings+fixed+source[oldpos+61:pos]+struct.pack('<I',6)
    for i in range(6):
        output+=struct.pack('<4I',i,1,1,1)+f'Player {i+1}'.encode()+b'\0'
        output+=struct.pack('<2f2I',i*128,0,0,63 ^ (1<<i))
    output+=struct.pack('<3I',1,3,63)+b'Lua research\0'
    output+=struct.pack('<4I',0,0,0,0)
    return output,bounds
