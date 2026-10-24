#!/usr/bin/env python3
import json
import mimetypes
import os
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit


FILE_ROOT = Path(os.environ.get("FILE_ROOT", "/workspaces/chromerdp-files"))
MAX_UPLOAD_BYTES = 1_000_000_000
CHUNK_SIZE = 1024 * 1024


def safe_filename(value):
    if not value or value in {".", ".."} or "/" in value or "\\" in value or "\0" in value:
        return None
    return value


class FileTransferHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        request = urlsplit(self.path)

        if request.path == "/":
            page = Path(__file__).with_name("files.html").read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(page)))
            self.end_headers()
            self.wfile.write(page)
            return

        if request.path == "/api/files":
            files = [
                {"name": path.name, "size": path.stat().st_size}
                for path in FILE_ROOT.iterdir()
                if path.is_file() and not path.is_symlink()
            ]
            body = json.dumps(files).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if request.path.startswith("/files/"):
            name = safe_filename(unquote(request.path[len("/files/"):]))
            path = FILE_ROOT / name if name else None
            if not path or not path.is_file() or path.is_symlink():
                self.send_error(404, "File not found")
                return
            size = path.stat().st_size
            self.send_response(200)
            self.send_header("Content-Type", mimetypes.guess_type(path.name)[0] or "application/octet-stream")
            self.send_header("Content-Length", str(size))
            self.send_header("Content-Disposition", f"attachment; filename*=UTF-8''{quote(path.name)}")
            self.end_headers()
            with path.open("rb") as source:
                while chunk := source.read(CHUNK_SIZE):
                    self.wfile.write(chunk)
            return

        self.send_error(404, "Not found")

    def do_PUT(self):
        request_path = urlsplit(self.path).path
        if not request_path.startswith("/upload/"):
            self.send_error(404, "Not found")
            return

        name = safe_filename(unquote(request_path[len("/upload/"):]))
        if not name:
            self.send_error(400, "Invalid filename")
            return

        try:
            length = int(self.headers.get("Content-Length", ""))
        except ValueError:
            self.send_error(411, "A valid Content-Length is required")
            return
        if length < 0 or length > MAX_UPLOAD_BYTES:
            self.send_error(413, "File exceeds the 1 GB upload limit")
            return

        temporary_path = None
        try:
            descriptor, temporary_name = tempfile.mkstemp(prefix=".upload-", dir=FILE_ROOT)
            temporary_path = Path(temporary_name)
            remaining = length
            with os.fdopen(descriptor, "wb") as destination:
                while remaining:
                    chunk = self.rfile.read(min(CHUNK_SIZE, remaining))
                    if not chunk:
                        raise ConnectionError("Upload ended before all bytes arrived")
                    destination.write(chunk)
                    remaining -= len(chunk)
            os.link(temporary_path, FILE_ROOT / name)
            temporary_path.unlink()
        except FileExistsError:
            if temporary_path:
                temporary_path.unlink(missing_ok=True)
            self.send_error(409, "A file with that name already exists")
            return
        except (OSError, ConnectionError) as error:
            if temporary_path:
                temporary_path.unlink(missing_ok=True)
            self.send_error(500, f"Could not save upload: {error}")
            return

        self.send_response(201)
        self.send_header("Content-Length", "0")
        self.end_headers()


if __name__ == "__main__":
    FILE_ROOT.mkdir(parents=True, exist_ok=True)
    ThreadingHTTPServer(("0.0.0.0", 6081), FileTransferHandler).serve_forever()
