"""Negative controls for object semantic checks and the no-launch build gate."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,sys,tempfile,uuid
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from w2l_runtime import verify_objects

parser=argparse.ArgumentParser()
parser.add_argument('--build-name',required=True,help='an already validated OBJ or SLK build')
args=parser.parse_args()
assert args.build_name and all(c.isascii() and (c.isalnum() or c in '-_') for c in args.build_name)
baseline=root/'build'/(args.build_name+'.w3x')
assert (root/'build'/(args.build_name+'-build.json')).exists(),'complete validation of baseline first'
with tempfile.TemporaryDirectory(prefix='LuaScaffold-object-negative-') as temp:
    source=Path(temp)/'source'
    shutil.copytree(root/'build'/(args.build_name+'-lni'),source)
    file=source/'table/unit.ini'
    text=file.read_text(encoding='utf8')
    assert 'Name = "Reimu"' in text
    file.write_text(text.replace('Name = "Reimu"','Name = "CHANGED"',1),encoding='utf8')
    try:verify_objects(source,baseline,Path(temp)/'negative.log')
    except subprocess.CalledProcessError:
        assert 'unit.H001.name mismatch' in (Path(temp)/'negative.log').read_text(encoding='utf8')
    else:raise AssertionError('modified object field was accepted')

name='guard-negative-'+uuid.uuid4().hex
mapfile=root/'build'/(name+'.w3x');manifest=root/'build'/(name+'-build.json')
assert not mapfile.exists() and not manifest.exists()
results=[]
try:
    mapfile.write_bytes(b'deliberately not a map')
    data={'sha256':hashlib.sha256(mapfile.read_bytes()).hexdigest(),'config':{'test':True,'clients':3}}
    for case,expected in [('missing','missing build manifest'),('hash','Map differs'),('clients','client count/config differs')]:
        if case=='hash':
            data['sha256']='0'*64;manifest.write_text(json.dumps(data),encoding='utf8')
        if case=='clients':
            data['sha256']=hashlib.sha256(mapfile.read_bytes()).hexdigest();data['config']['clients']=6
            manifest.write_text(json.dumps(data),encoding='utf8')
        run=subprocess.run(['pwsh','-NoProfile','-File','tools/test.ps1','-Name',name,'-Clients','3'],cwd=root,capture_output=True)
        output=(run.stdout+run.stderr).decode('utf8',errors='replace')
        assert run.returncode!=0 and expected in output,(case,output)
        results.append(case)
finally:
    mapfile.unlink(missing_ok=True);manifest.unlink(missing_ok=True)
(root/'tests/evidence/build-negative.json').write_text(json.dumps({'status':'PASS','checks':['changed object field rejected',*results],'game_launched':False},indent=2)+'\n',encoding='utf8')
print('BUILD NEGATIVE PASS changed object, missing manifest, changed hash and wrong client count rejected before launch')
