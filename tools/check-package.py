"""Verify release contents, source fidelity, dependencies and SHA-256."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import re
import zipfile

ROOT = Path(__file__).resolve().parent.parent
PREFIX = 'apps/lua/RetroUI/'
ASSETS = {'assets/notification-qqv87.wav', 'assets/notification-d4s3s.wav'}


def verify(path):
    version = re.search(r'^VERSION = (\d+\.\d+\.\d+)$', (ROOT / 'manifest.ini').read_text(), re.M).group(1)
    assert path.name == f'RetroUI-v{version}.zip', 'Package and manifest versions must match'
    expected = {p.relative_to(ROOT).as_posix(): p for folder in ('src', 'ui', 'modules')
                for p in (ROOT / folder).rglob('*.lua')}
    for name in ('app.lua', 'RetroUI.lua', 'manifest.ini', 'LICENSE', 'THIRD_PARTY_NOTICES.md',
                 'CHANGELOG.md', 'modules/relative/classes.ini', 'modules/leaderboard/classes.ini',
                 'docs/settings.md', *ASSETS):
        expected[name] = ROOT / name
    expected['README.md'] = ROOT / 'docs/user-guide.md'
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        assert len(names) == len(set(names)), 'Duplicate ZIP entries'
        assert all(n.startswith(PREFIX) and '..' not in PurePosixPath(n).parts and '\\' not in n for n in names), 'Invalid install path'
        actual = {n[len(PREFIX):] for n in names}
        assert actual == set(expected), f'Unexpected or missing files: {actual ^ set(expected)}'
        assert archive.testzip() is None, 'Corrupt ZIP entry'
        for name, source in expected.items():
            content = archive.read(PREFIX + name)
            assert content == source.read_bytes(), f'Package differs from source: {name}'
            if name.endswith('.lua'):
                text = content.decode('utf-8-sig')
                for module in re.findall(r"require\(['\"]([^'\"]+)['\"]\)", text):
                    assert f'{module}.lua' in actual, f'Missing dependency {module} in {name}'
                for asset in re.findall(r"['\"](assets/[^'\"]+)['\"]", text):
                    assert asset in actual, f'Missing runtime asset {asset}'
    checksum = Path(str(path) + '.sha256').read_text(encoding='ascii').split()
    assert checksum == [hashlib.sha256(path.read_bytes()).hexdigest(), path.name], 'Invalid checksum'
    print(f'Package verified: {len(expected)} files, {path.stat().st_size / 1024:.1f} KiB, version {version}, source fidelity and SHA-256')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('package', type=Path)
    verify(parser.parse_args().package.resolve())
