"""Serve only the built demonstration on a loopback-only random port."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json, os
root = Path(__file__).resolve().parent.parent
web = root / 'build' / 'web'
if not (web / 'index.html').exists():
    raise SystemExit('Execute flutter build web antes de iniciar a prévia.')
server = ThreadingHTTPServer(('127.0.0.1', 0), partial(SimpleHTTPRequestHandler, directory=str(web)))
address = f'http://127.0.0.1:{server.server_port}'
(root / '.tools').mkdir(exist_ok=True)
(root / '.tools' / 'preview.json').write_text(json.dumps({'url': address, 'pid': os.getpid()}), encoding='utf-8')
print(address, flush=True)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
