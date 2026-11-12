"""Copy this template to a new, non-existing directory; never copies build or .git."""
from pathlib import Path
import argparse, json, shutil
from framework_package import export, resolve, PUBLIC

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('destination')
parser.add_argument('--id', required=True)
parser.add_argument('--title')
parser.add_argument('--copy-framework', action='store_true', help='legacy independent-copy mode; default uses a locked dependency')
args=parser.parse_args()
assert args.id and len(args.id)<=32 and all(c.isascii() and (c.isalnum() or c in '-_') for c in args.id), 'ASCII project ID required'
dest=Path(args.destination).resolve()
assert not dest.exists(), 'Destination must not exist'
assert not dest.is_relative_to(root), 'Create new projects outside this template'
dest.mkdir(parents=True)
for name in ('src','assets','vendor','tools','integration','examples','tests','docs','.agents','.vscode','research','maps','config'):
    if name=='vendor':continue
    if name=='src':
        shutil.copytree(root/name,dest/name,ignore=lambda path,names: ['scaffold','ui','game'] if Path(path)==root/'src' else [])
        continue
    def ignore(path,names):
        excluded=shutil.ignore_patterns('__pycache__','*.pyc')(path,names)
        if Path(path)==root/'tests':excluded.add('evidence')
        return excluded
    shutil.copytree(root/name, dest/name, ignore=ignore)
if args.copy_framework:
    for prefix in PUBLIC:
        if (resolve(root)/prefix).exists():shutil.copytree(resolve(root)/prefix,dest/prefix)
if not args.copy_framework:
    lock=export(resolve(root),dest/'deps/lua-scaffold')
    (dest/'framework.lock.json').write_text(json.dumps({'path':'deps/lua-scaffold','version':lock['version']},indent=2)+'\n',encoding='utf-8')
for name in ('README.md','AGENTS.md','.gitignore','.gitattributes','project.json'):
    if (root/name).exists(): shutil.copy2(root/name,dest/name)
project={'id':args.id,'title':args.title or args.id,'version':'0.1.0'}
(dest/'project.json').write_text(json.dumps(project,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('NEW PROJECT READY; edit src/app and run python tools/build.py --name first-build')
