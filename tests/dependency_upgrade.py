"""Real copied project, A -> B -> A builds; fixture probes are not production modules."""
from pathlib import Path
import json, subprocess, sys, tempfile, shutil, os
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from framework_package import export,verify,resolve
from framework_dependency import activate

with tempfile.TemporaryDirectory(prefix='LuaDependency-') as temp:
    base=Path(temp);project=base/'Game';fixture=base/'fixture'
    subprocess.run([sys.executable,'tools/new_project.py',str(project),'--id','DependencyTest'],cwd=root,check=True,capture_output=True)
    export(root,fixture)
    probe=fixture/'src/scaffold/revision_probe.lua'
    probe.write_text("return 'A'\n",encoding='utf-8')
    a=export(fixture,base/'A')
    probe.write_text("return 'B'\n",encoding='utf-8')
    b=export(fixture,base/'B')
    assert a['version']!=b['version']
    versions=[]
    for number,label in enumerate(('A','B','A')):
        selection=activate(project,base/label)
        dep=resolve(project)
        env=os.environ.copy();env['LUA_PATH']=str(dep/'src/?.lua')+';;'
        subprocess.run(['lua','-e',"assert(require('scaffold.revision_probe')=='"+label+"')"],cwd=project,env=env,check=True)
        result=subprocess.run([sys.executable,'tools/build.py','--name','dependency-'+str(number),'--keep-work'],cwd=project,capture_output=True,text=True,errors='replace')
        assert result.returncode==0,result.stdout+result.stderr
        staged=project/'build'/('dependency-'+str(number))/'script/scaffold/revision_probe.lua'
        assert staged.read_text()=="return '"+label+"'\n"
        versions.append(selection['version'])
    assert versions[0]==versions[2]!=versions[1]
    selected=resolve(project);original=(selected/'src/scaffold/revision_probe.lua').read_bytes()
    (selected/'src/scaffold/revision_probe.lua').write_bytes(original+b'-- modified\n')
    before=(project/'framework.lock.json').read_bytes()
    try:activate(project,base/'B')
    except AssertionError:pass
    else:raise AssertionError('modified active dependency was accepted')
    assert before==(project/'framework.lock.json').read_bytes()
    (selected/'src/scaffold/revision_probe.lua').write_bytes(original)
    extra=selected/'unexpected.lua';extra.write_text('return true\n')
    try:resolve(project)
    except AssertionError:pass
    else:raise AssertionError('extra dependency file was accepted')
    extra.unlink();resolve(project)
    # A malformed incoming package must not change the selected version.
    bad=base/'B/src/scaffold/revision_probe.lua';bad.write_text("return 'corrupt'\n")
    try:activate(project,base/'B')
    except AssertionError:pass
    else:raise AssertionError('corrupt incoming package was accepted')
    assert before==(project/'framework.lock.json').read_bytes()
    report={'status':'PASS','versions':versions,'builds':3,'checks':['A-B-A behavior and MPQ payload verification','modified active dependency rejected','extra file rejected','corrupt incoming package rejected before selection','lock unchanged after failure'],'scope':'synthetic revision probe in real public-runtime snapshots; no game run'}
(root/'tests/evidence/dependency-upgrade.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('DEPENDENCY UPGRADE/ROLLBACK AND INTEGRITY PASS')
