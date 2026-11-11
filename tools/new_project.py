"""Copy this template to a new, non-existing directory; never copies build or .git."""
from pathlib import Path
import argparse, json, shutil

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('destination')
parser.add_argument('--id', required=True)
parser.add_argument('--title')
args=parser.parse_args()
assert args.id and len(args.id)<=32 and all(c.isascii() and (c.isalnum() or c in '-_') for c in args.id), 'ASCII project ID required'
dest=Path(args.destination).resolve()
assert not dest.exists(), 'Destination must not exist'
assert not dest.is_relative_to(root), 'Create new projects outside this template'
dest.mkdir(parents=True)
for name in ('src','assets','vendor','tools','integration','examples','tests','docs','.agents','.vscode','research'):
    shutil.copytree(root/name, dest/name, ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
for name in ('README.md','AGENTS.md','.gitignore','.gitattributes','project.json'):
    if (root/name).exists(): shutil.copy2(root/name,dest/name)
project={'id':args.id,'title':args.title or args.id,'version':'0.1.0'}
(dest/'project.json').write_text(json.dumps(project,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('NEW PROJECT READY; edit src/app and run python tools/build.py --name first-build')
