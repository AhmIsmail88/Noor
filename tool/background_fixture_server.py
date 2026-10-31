"""Local, generated fixture only: throttled Range server and outage controls."""
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
import time, threading

media = Path(__file__).resolve().parents[1] / 'build/background-fixture.mp4'
offline = threading.Event()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ['/offline', '/online']:
            offline.set() if self.path == '/offline' else offline.clear()
            self.send_response(200); self.end_headers(); self.wfile.write(b'ok'); return
        if offline.is_set():
            self.send_error(503); return
        size = media.stat().st_size
        start = int(self.headers.get('Range', 'bytes=0-').split('=')[1].split('-')[0])
        if start >= size:
            self.send_response(416); self.end_headers(); return
        print('NOOR_RANGE', self.path, start, flush=True)
        self.send_response(206 if start else 200)
        self.send_header('Content-Type', 'video/mp4')
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Content-Length', str(size-start))
        if start: self.send_header('Content-Range', f'bytes {start}-{size-1}/{size}')
        self.end_headers()
        try:
            with media.open('rb') as f:
                f.seek(start)
                while chunk := f.read(32768):
                    if offline.is_set(): self.close_connection=True; return
                    self.wfile.write(chunk); self.wfile.flush()
                    time.sleep(0.12)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError): pass

ThreadingHTTPServer(('127.0.0.1', 18765), Handler).serve_forever()
