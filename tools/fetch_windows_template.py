"""Read the official remote ZIP directory and fetch only the Windows template."""
import concurrent.futures
import io
from pathlib import Path
import urllib.request
import zipfile

URL = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'


class RemoteZip(io.RawIOBase):
    def __init__(self, url):
        self.url = url
        response = urllib.request.urlopen(urllib.request.Request(url, method='HEAD'), timeout=60)
        self.url = response.url
        self.size = int(response.headers['Content-Length'])
        self.position = 0

    def seekable(self):
        return True

    def seek(self, offset, whence=0):
        self.position = offset + (0 if whence == 0 else self.position if whence == 1 else self.size)
        return self.position

    def tell(self):
        return self.position

    def chunk(self, bounds):
        start, end = bounds
        request = urllib.request.Request(self.url, headers={'Range': f'bytes={start}-{end-1}'})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    if response.status != 206:
                        raise RuntimeError(f'Expected partial response, received {response.status}')
                    data = response.read()
                    if len(data) != end-start:
                        raise RuntimeError('Incomplete template range')
                    return data
            except Exception:
                if attempt == 2:
                    raise

    def read(self, size=-1):
        if size < 0:
            size = self.size-self.position
        start, end = self.position, min(self.size, self.position+size)
        self.position = end
        if end <= start:
            return b''
        if end-start < 2*1024*1024:
            return self.chunk((start, end))
        bounds = [(i, min(end, i+1024*1024)) for i in range(start, end, 1024*1024)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
            return b''.join(executor.map(self.chunk, bounds))


target = Path(__file__).resolve().parent/'templates'
target.mkdir(exist_ok=True)
with zipfile.ZipFile(RemoteZip(URL)) as archive:
    names = [n for n in archive.namelist() if n.endswith('windows_release_x86_64.exe')]
    if len(names) != 1:
        raise RuntimeError(f'Ambiguous Windows template: {names}')
    info = archive.getinfo(names[0])
    print(f'Official Windows template: {info.compress_size:,} download bytes, {info.file_size:,} unpacked', flush=True)
    (target/'windows_release_x86_64.exe').write_bytes(archive.read(names[0]))
print('Windows release template ready', flush=True)
