"""Prune only completed, manifest-owned builds; never sweep arbitrary folders."""
from pathlib import Path
import json
import shutil
import stat


def safe_target(build, path):
    build = Path(build).absolute()
    path = Path(path).absolute()
    if path.parent != build or path.resolve().parent != build.resolve():
        raise ValueError('cleanup target must be a direct child of build')
    for item in [build, path, *(path.rglob('*') if path.is_dir() else [])]:
        if item.exists() and (item.is_symlink() or
                getattr(item.lstat(), 'st_file_attributes', 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT):
            raise ValueError('cleanup refuses links/reparse points: '+str(item))
    return path


def cleanup(build, current, keep=3):
    build = Path(build)
    if keep < 1:
        raise ValueError('keep must be positive')
    if (build/'runtime-guard-active.json').exists():
        print('CLEANUP SKIPPED: runtime guard active')
        return
    records = []
    for file in build.glob('*-build.json'):
        name = file.name.removesuffix('-build.json')
        if not name or not all(c.isascii() and (c.isalnum() or c in '-_') for c in name):
            continue
        # Reserved research/dependency directories can never be cleanup targets.
        if name in ('analysis-deps', 'engine-pe', 'tool-cache'):
            continue
        try:
            data = json.loads(file.read_text(encoding='utf8'))
            if data['map'] != name+'.w3x' or not data.get('files'):
                continue
            records.append((file.stat().st_mtime_ns, name, data))
        except (ValueError, KeyError, OSError):
            continue
    retained = {name for _, name, _ in sorted(records, reverse=True)
                if (build/(name+'.w3x')).is_file()}
    ordered = [name for _, name, _ in sorted(records, reverse=True) if name in retained]
    retained = set(([current] + [name for name in ordered if name != current])[:keep])
    for _, name, data in records:
        if data.get('config', {}).get('keep_work'):
            continue
        targets = [build/name, build/(name+'-lni')]
        if name not in retained:
            targets.append(build/(name+'.w3x'))
        for target in targets:
            try:
                target = safe_target(build, target)
                if target.is_dir():
                    shutil.rmtree(target)
                    print('CLEANUP removed '+target.name)
                elif target.is_file():
                    target.unlink()
                    print('CLEANUP removed '+target.name)
            except (OSError, ValueError) as error:
                print('CLEANUP WARNING: '+str(error))
