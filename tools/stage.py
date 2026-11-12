"""Create a NEW MPQ payload directory; never launch a game or alter a map."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from framework_package import resolve

ROOT = Path(__file__).resolve().parents[1]
FRAMEWORK = resolve(ROOT)
VENDOR = FRAMEWORK / 'vendor' / 'war3ui-1.49-9'


def verify():
    manifest = json.loads((VENDOR / 'manifest.json').read_text(encoding='utf-8'))
    for entry in manifest['files']:
        path = VENDOR / 'package' / entry['path']
        assert path.is_file(), f'Missing vendor file: {entry["path"]}'
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], entry['path']
    return len(manifest['files'])


def stage(name, include_tests=False, include_dev=False):
    assert name and all(c.isascii() and (c.isalnum() or c in '-_') for c in name), 'ASCII stage name required'
    dst = ROOT / 'build' / name
    assert not dst.exists(), 'Output already exists: choose another stage name'
    dst.mkdir(parents=True)
    sources={p.relative_to(ROOT/'src'):p for p in (ROOT/'src').rglob('*.lua')}
    if FRAMEWORK != ROOT:
        assert not any(p.parts[0] in ('scaffold','ui','game') for p in sources), 'project cannot shadow public framework namespaces'
        sources.update({p.relative_to(FRAMEWORK/'src'):p for p in (FRAMEWORK/'src').rglob('*.lua')})
    for rel,file in sorted(sources.items()):
        if (rel.as_posix() in ('app/runtime_test.lua','app/view.lua') or rel.parts[0] == 'probes') and not include_tests:
            continue
        if rel.parts[0] == 'dev' and not include_dev:
            continue
        target = dst / (rel if rel.as_posix() in ('plugin_main.lua','jass2binary.lua') else Path('script') / rel)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file, target)
    project = json.loads((ROOT / 'project.json').read_text(encoding='utf-8'))
    project_id = project['id']
    log_folder = project.get('log_folder',project_id)
    assert log_folder and log_folder not in ('.','..') and not any(c in log_folder for c in '/\\:\r\n\0"'), 'invalid log folder'
    assert project_id and all(c.isascii() and (c.isalnum() or c in '-_') for c in project_id)
    (dst/'script/app/config.lua').write_text(
        "return {ui=true,runtime_test=false,dev=false,build_id='%s',project_id='%s',log_folder=%s}\n" % (name,project_id,json.dumps(log_folder,ensure_ascii=False)), encoding='utf-8')
    for name in ('callback', '(key)', 'wenhao_plugin.tga'):
        shutil.copy2(VENDOR / 'package' / 'plugin' / name, dst / name)
    shutil.copytree(VENDOR / 'package' / 'plugin' / 'core', dst / 'core')
    shutil.copy2(VENDOR / 'package' / 'plugin' / 'fonts.TTF', dst / 'fonts.TTF')
    write_manifest(dst)


def write_manifest(dst):
    entries = []
    for file in sorted(dst.rglob('*')):
        if file.is_file():
            entries.append({'archive': file.relative_to(dst).as_posix(),
                            'sha256': hashlib.sha256(file.read_bytes()).hexdigest()})
    # This manifest is outside the payload; importer decides MPQ/LNI placement.
    (dst.parent / (dst.name + '-manifest.json')).write_text(
        json.dumps(entries, indent=2), encoding='utf-8')
    print(f'STAGED {len(entries)} files; no map has been packed or launched')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--name', help='create build/NAME once, otherwise only verify vendor')
    args = parser.parse_args()
    print(f'VENDOR OK {verify()} files')
    if args.name:
        stage(args.name)
