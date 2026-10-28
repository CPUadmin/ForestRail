"""Publish existing ForestRail archives without storing authentication secrets.

Uses the Git credential helper already configured on this computer.
Rerunning resumes after completed releases/assets; matching files are retained.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
API = 'https://api.github.com'
REVISIONS = {'1.0.0': '348d070', '1.0.1': 'defa8b1', '1.0.2': 'b5fef81', '1.1.0': '00445bb'}
NOTES = {
    '1.0.0': 'Первая полная версия: 10 основных рейсов, свободные заказы, три машины, грузовые вагоны, депо, улучшения и сохранения. Бензин у моторной дрезины, аккумулятор и рекуперация у локомотива.',
    '1.0.1': 'Улучшены ручной привод и видимый механизм, исправлено направление вращения колёс. Добавлен задний ход с грузом без разворота состава, улучшены земля и размещение растительности.',
    '1.0.2': 'Подключён полный набор art_v3: кузова, колёса, механизм с размеченными шарнирами, многоплановый лес, путь и станции. Проверена постоянная длина шатуна и положение груза.',
    '1.1.0': 'Нижняя панель приборов: спидометр со шкалой под машину и улучшения, миникарта, бензин или заряд, масса состава и груза, уклон и тормоз. Большая карта по M или кнопке, выбор станции и список доставок. Старые сохранения совместимы.',
}


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def credentials():
    env = dict(os.environ, GIT_TERMINAL_PROMPT='0', GCM_INTERACTIVE='never')
    result = subprocess.run(['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n\n',
                            text=True, capture_output=True, env=env, timeout=45)
    fields = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
    if result.returncode or not fields.get('password'):
        raise RuntimeError('GitHub authentication is unavailable in the configured Git credential helper')
    return fields['password']


class Client:
    def __init__(self):
        self.headers = {'Authorization': 'Bearer ' + credentials(), 'Accept': 'application/vnd.github+json',
                        'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'ForestRail-publisher'}

    def request(self, path, method='GET', body=None, missing=False):
        url = path if path.startswith('https://') else API + path
        payload = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
        headers = dict(self.headers)
        if payload is not None:
            headers['Content-Type'] = 'application/json'
        for attempt in range(3):
            try:
                with urllib.request.urlopen(urllib.request.Request(url, data=payload, headers=headers, method=method), timeout=30) as response:
                    raw = response.read()
                    return json.loads(raw) if raw else None
            except urllib.error.HTTPError as error:
                if error.code == 404 and missing:
                    return None
                if error.code < 500:
                    raise RuntimeError(f'GitHub API returned HTTP {error.code} for {method} {urllib.parse.urlsplit(url).path}') from None
                if attempt == 2:
                    raise RuntimeError(f'GitHub API returned HTTP {error.code}') from None
            except (OSError, TimeoutError):
                if attempt == 2:
                    raise RuntimeError('GitHub network request failed after three attempts') from None
            time.sleep(2 * (attempt + 1))

    def upload(self, release, path):
        url = release['upload_url'].split('{')[0] + '?' + urllib.parse.urlencode({'name': path.name})
        headers = dict(self.headers, **{'Content-Type': 'application/octet-stream', 'Content-Length': str(path.stat().st_size)})
        # urllib streams the file; the archive is not embedded in a command or log.
        with path.open('rb') as stream:
            request = urllib.request.Request(url, data=stream, headers=headers, method='POST')
            with urllib.request.urlopen(request, timeout=180) as response:
                return json.load(response)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=['inspect', 'create', 'publish', 'verify'])
    parser.add_argument('--repo', default='CPUadmin/ForestRail')
    args = parser.parse_args()
    owner, name = args.repo.split('/')
    client = Client()
    account = client.request('/user')
    if account['login'].lower() != owner.lower():
        raise RuntimeError('Authenticated account does not match the requested repository owner')
    endpoint = '/repos/' + args.repo
    repo = client.request(endpoint, missing=True)
    if args.phase == 'inspect':
        print(json.dumps({'login': account['login'], 'repository_exists': repo is not None,
                          'private': repo.get('private') if repo else None}), flush=True)
        return
    if args.phase == 'create':
        if repo is None:
            # An empty repository lets the existing local history be pushed intact.
            repo = client.request('/user/repos', 'POST', {'name': name, 'private': True, 'auto_init': False,
                                  'description': 'Лесная колея — игра про лесную железную дорогу на Godot. Исходники, ассеты и все выпущенные версии.'})
        print(json.dumps({'url': repo['html_url'], 'private': repo['private']}, ensure_ascii=False), flush=True)
        return
    if repo is None:
        raise RuntimeError('Create and push the repository before publishing releases')
    if args.phase == 'publish':
        for version in REVISIONS:
            tag = 'v' + version
            release = client.request(endpoint + '/releases/tags/' + tag, missing=True)
            if release is None:
                release = client.request(endpoint + '/releases', 'POST', {
                    'tag_name': tag, 'name': 'Лесная колея ' + version, 'draft': True,
                    'body': NOTES[version] + '\n\n**Запуск:** скачайте `Windows_x64.zip`, распакуйте и откройте `ForestRail.exe`.\n\n`Source.zip` содержит исходники именно этой версии. Контрольные суммы — в `SHA256SUMS.txt`. Исходные архивы сохранены без изменений.',
                    'make_latest': 'false'})
            files = [ROOT/'release'/f'ForestRail_{version}_{suffix}.zip' for suffix in ['Windows_x64', 'Source']]
            if version == '1.1.0':
                files.append(ROOT/'release'/'ForestRail_AllHistory.bundle')
            sums = ROOT/'release'/'publication'/tag/'SHA256SUMS.txt'
            sums.parent.mkdir(parents=True, exist_ok=True)
            sums.write_text(''.join(sha256(p) + '  ' + p.name + '\n' for p in files), encoding='utf-8', newline='\n')
            files.append(sums)
            for path in files:
                expected = 'sha256:' + sha256(path)
                assets = client.request(endpoint + f'/releases/{release["id"]}/assets?per_page=100')
                existing = next((item for item in assets if item['name'] == path.name), None)
                if existing:
                    if existing['state'] == 'uploaded' and existing['size'] == path.stat().st_size and existing.get('digest') == expected:
                        print(f'RETAINED {tag} {path.name}', flush=True)
                        continue
                    if existing['state'] != 'uploaded':
                        client.request(endpoint + f'/releases/assets/{existing["id"]}', 'DELETE')
                    else:
                        raise RuntimeError('Existing release asset differs; preserving it: ' + tag + ' ' + path.name)
                print(f'UPLOADING {tag} {path.name} ({path.stat().st_size} bytes)', flush=True)
                uploaded = client.upload(release, path)
                if uploaded['size'] != path.stat().st_size or uploaded.get('digest') != expected:
                    raise RuntimeError('Uploaded size/digest did not match: ' + path.name)
                print(f'UPLOADED {tag} {path.name}', flush=True)
            client.request(endpoint + f'/releases/{release["id"]}', 'PATCH', {
                'draft': False, 'make_latest': 'true' if version == '1.1.0' else 'false'})
            print('PUBLISHED ' + release['html_url'], flush=True)
    # Verify GitHub's recorded digests against every original local archive.
    report = {'repository': repo['html_url'], 'private': repo['private'], 'releases': []}
    for version in REVISIONS:
        release = client.request(endpoint + '/releases/tags/v' + version)
        assets = client.request(endpoint + f'/releases/{release["id"]}/assets?per_page=100')
        verified = []
        for asset in assets:
            local = (ROOT/'release'/'publication'/('v'+version)/asset['name']) if asset['name'] == 'SHA256SUMS.txt' else ROOT/'release'/asset['name']
            if not local.exists() or asset.get('digest') != 'sha256:' + sha256(local) or asset['size'] != local.stat().st_size:
                raise RuntimeError('Remote asset does not match local archive: ' + asset['name'])
            verified.append({'name': asset['name'], 'bytes': asset['size'], 'digest': asset['digest']})
        expected_count = 4 if version == '1.1.0' else 3
        if release['draft'] or len(verified) != expected_count:
            raise RuntimeError('Incomplete release: ' + version)
        report['releases'].append({'version': version, 'url': release['html_url'], 'assets': verified})
    (ROOT/'qa'/'github_publication.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Never include credential-helper output or HTTP headers in diagnostics.
        print(f'{type(error).__name__}: {error}', flush=True)
        raise SystemExit(1)
