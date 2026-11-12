"""Install a verified snapshot, then atomically select it. Old snapshots remain for rollback."""
from pathlib import Path
import argparse, json, shutil
from framework_package import verify, resolve

def activate(project,package):
    project=project.resolve();package=package.resolve()
    assert (project/'framework.lock.json').is_file(), 'target is not a fixed-dependency project'
    resolve(project) # Never silently replace a locally modified active dependency.
    lock=json.loads((package/'package-lock.json').read_text(encoding='utf-8'))
    verify(package,lock['version'])
    target=project/'deps/packages'/lock['version']
    if not target.exists():
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copytree(package,target)
    verify(target,lock['version'])
    selection={'path':target.relative_to(project).as_posix(),'version':lock['version']}
    temporary=project/'framework.lock.json.tmp'
    assert not temporary.exists(), 'unfinished dependency selection; inspect temporary lock'
    temporary.write_text(json.dumps(selection,indent=2)+'\n',encoding='utf-8')
    temporary.replace(project/'framework.lock.json')
    return selection

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('project',type=Path)
    parser.add_argument('package',type=Path)
    args=parser.parse_args()
    print(json.dumps(activate(args.project,args.package),indent=2))
