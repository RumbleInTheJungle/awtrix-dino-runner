#!/usr/bin/env python3
"""Install/update Dino Runner, preserving an existing Matrix selection, and upload its sounds."""
import argparse
import hashlib
import json
import pathlib
import re
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOUNDS = ROOT / 'sounds'

def request(base, path, method='GET', body=None, content_type='application/json'):
    data = body.encode() if isinstance(body, str) else body
    req = urllib.request.Request(base + path, data=data, method=method,
                                 headers={'Content-Type': content_type})
    with urllib.request.urlopen(req, timeout=30) as response:
        raw = response.read().decode()
        return json.loads(raw) if 'json' in response.headers.get('Content-Type', '') else raw

def install(base, name, backup_dir, send=request):
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,32}', name):
        raise ValueError('Script name must contain 1–32 letters, numbers, underscores or hyphens')
    parsed = urllib.parse.urlsplit(base)
    if parsed.scheme not in ('http', 'https') or not parsed.netloc or parsed.query or parsed.fragment:
        raise ValueError('Use a device URL such as http://192.168.1.20')
    base = base.rstrip('/')
    old_matrix = False
    source_path = '/api/v1/apps/script/' + name
    config_path = '/api/v1/apps/' + name + '/config'
    try:
        source = send(base, source_path)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        error.close()
    else:
        config = send(base, config_path)
        old_matrix = any(f.get('key') == 'matrix' and f.get('value') is True
                         for f in config.get('fields', []))
        # Save a local source/settings backup before replacing anything.
        backup_dir.mkdir(parents=True, exist_ok=True)
        (backup_dir / (name + '.be')).write_text(source)
        (backup_dir / (name + '-settings.json')).write_text(json.dumps(config, indent=2)+'\n')
    answer = send(base, source_path, 'PUT', (ROOT / 'dino_runner.be').read_text(), 'text/plain')
    check_answer(answer)
    if old_matrix:
        answer = send(base, config_path, 'PATCH', json.dumps({'world_mode': 'fixed', 'fixed_world': '10'}))
        check_answer(answer)
    return old_matrix

def multipart(filename, data):
    """A multipart/form-data body with one file field, and its content type."""
    boundary = 'dino-' + hashlib.sha256(data).hexdigest()[:24]
    body = (f'--{boundary}\r\n'
            f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
            'Content-Type: audio/mpeg\r\n\r\n').encode() + data + f'\r\n--{boundary}--\r\n'.encode()
    return body, 'multipart/form-data; boundary=' + boundary

def sync_sounds(base, name, send=request, sounds_dir=SOUNDS):
    """Upload the script's MP3s that the clock does not already hold unchanged.

    The script must be installed first. Returns the names of the uploaded files.
    """
    base = base.rstrip('/')
    files = sorted(sounds_dir.glob('*.mp3'))
    if not files:
        return []
    path = '/api/v1/apps/script/' + name + '/sounds'
    listing = send(base, path)
    held = {f.get('name'): f.get('sha256') for f in listing.get('files', [])}
    uploaded = []
    for file in files:
        data = file.read_bytes()
        if held.get(file.name) == hashlib.sha256(data).hexdigest():
            continue
        body, content_type = multipart(file.name, data)
        check_answer(send(base, path, 'POST', body, content_type))
        uploaded.append(file.name)
    return uploaded

def check_answer(answer):
    if not isinstance(answer, dict) or answer.get('ok') is not True or answer.get('error'):
        raise RuntimeError('Device did not confirm a successful update: ' + str(answer))

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('device', help='Device base URL, for example http://192.168.1.20')
    p.add_argument('--name', default='dino_runner', help='Use the existing script name when updating')
    p.add_argument('--backup-dir', type=pathlib.Path, default=ROOT/'backups')
    a = p.parse_args()
    migrated = install(a.device, a.name, a.backup_dir)
    uploaded = sync_sounds(a.device, a.name)
    print('Installed. Open the device menu → Scripts → Dino Runner.')
    if uploaded:
        print('Uploaded sounds: ' + ', '.join(uploaded))
    if migrated:
        print('Preserved Matrix mode as fixed world 10.')

if __name__ == '__main__':
    main()
