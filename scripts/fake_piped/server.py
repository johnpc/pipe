#!/usr/bin/env python3
"""A fake Piped backend for pipe: deterministic JSON plus real, playable media.

Why this exists
  * CI: acceptance scenarios tagged @fake-server launch the app with
    `--uitest-instance http://127.0.0.1:<port>` and play actual audio/video
    end to end — strict assertions ("position passes 0:02"), no live
    YouTube, no skips.
  * App Store review: `--export-static DIR --base-url https://…` writes the
    same API as plain files (S3/CloudFront static hosting serves them as-is)
    so a reviewer can point Settings → Piped instance at it and exercise
    every screen on synthetic, licence-free media instead of proxied YouTube.
  * Local development against a backend that never changes.

What it serves (mirrors the Piped API the app calls, see PipedAPI*.swift)
  /search?q=…            → Fixtures/search.json
  /trending?region=…     → Fixtures/trending.json
  /channel/<id>          → Fixtures/channel.json
  /channels/tabs?data=…  → channelTab.json, or channelPlaylistTab.json when
                            the data token contains "playlist"
  /nextpage/channel/<id> → an empty page (ends pagination)
  /playlists/<id>        → Fixtures/playlist.json
  /comments/<id>         → Fixtures/comments.json
  /streams/<id>          → Fixtures/streams.json personalised for <id> (title,
                            uploader, duration, thumbnail — same rule as the
                            app's in-process FixtureCatalog), with every
                            stream URL pointing at this server's media.
  /media/…               → the synthetic clip (HLS master + renditions, muxed
                            MP4, video-only MP4, audio M4A, thumbnail), with
                            HTTP Range support as AVPlayer requires.
  /healthz               → {"ok": true}

Only the Python standard library is used (the CI Mac has nothing else).
Binds 127.0.0.1 by default — this is a dev/test server; reach it from a device
through an SSH port-forward rather than a wider bind.
"""
import argparse
import json
import mimetypes
import os
import re
import shutil
import sys
import threading
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

sys.path.insert(0, str(Path(__file__).resolve().parent))
import demo_catalog  # noqa: E402  (sibling module; stdlib-only)

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
DEFAULT_FIXTURES = REPO / "pipe" / "Fixtures"
DEFAULT_MEDIA = HERE / "media"

CONTENT_TYPES = {
    ".m3u8": "application/vnd.apple.mpegurl",
    ".m4s": "video/iso.segment",
    ".mp4": "video/mp4",
    ".m4a": "audio/mp4",
    ".jpg": "image/jpeg",
    ".json": "application/json",
}

CATALOG_SOURCES = ["search", "trending", "channel", "channelTab", "playlist", "streams"]
WATCH_RE = re.compile(r"/watch\?v=([^&]+)")


class Fixtures:
    """Fixture JSON plus the per-id catalogue, independent of HTTP.

    `catalog` is "fixtures" (real captured titles, what the UI tests assert on)
    or "demo" (plainly-labelled placeholders, what a reviewer or demo user sees;
    the static export always uses this)."""

    def __init__(self, fixtures_dir: Path, catalog: str = "fixtures"):
        self.dir = fixtures_dir
        self.catalog = catalog

    @property
    def demo(self) -> bool:
        return self.catalog == "demo"

    def load(self, name: str):
        path = self.dir / f"{name}.json"
        if not path.exists():
            return None
        with path.open(encoding="utf-8") as f:
            return json.load(f)

    @staticmethod
    def videos(doc):
        """Video rows wherever Piped puts them (same rule as FixtureCatalog.swift)."""
        if isinstance(doc, list):
            rows = doc
        elif isinstance(doc, dict):
            rows = doc.get("items") or doc.get("relatedStreams") or doc.get("content") or []
        else:
            rows = []
        out = []
        for row in rows:
            if not isinstance(row, dict):
                continue
            m = WATCH_RE.search(row.get("url") or "")
            if not m or not row.get("title"):
                continue
            out.append({
                "videoId": m.group(1),
                "title": row["title"],
                "uploader": row.get("uploaderName") or "",
                "duration": row.get("duration") or 0,
                "thumbnail": row.get("thumbnail") or "",
            })
        return out

    def video(self, video_id: str):
        for name in CATALOG_SOURCES:
            doc = self.load(name)
            if doc is None:
                continue
            for v in self.videos(doc):
                if v["videoId"] == video_id:
                    return v
        return None

    def all_video_ids(self):
        seen = []
        for name in CATALOG_SOURCES:
            doc = self.load(name)
            for v in self.videos(doc) if doc is not None else []:
                if v["videoId"] not in seen:
                    seen.append(v["videoId"])
        return seen


def rewrite_images(node, thumb_url: str):
    """Point every absolute http(s) string (thumbnails, avatars, banners) at the
    local placeholder, so a demo build never fetches YouTube's image CDN. Stream
    URLs are replaced separately in `streams_for`."""
    if isinstance(node, dict):
        return {k: rewrite_images(v, thumb_url) for k, v in node.items()}
    if isinstance(node, list):
        return [rewrite_images(v, thumb_url) for v in node]
    if isinstance(node, str) and node.startswith(("http://", "https://")):
        return thumb_url
    return node


def streams_for(fixtures: Fixtures, video_id: str, base: str):
    """The streams template personalised for `video_id`, playing our media."""
    doc = fixtures.load("streams") or {}
    video = fixtures.video(video_id)
    if video:
        doc["title"] = video["title"]
        doc["uploader"] = video["uploader"]
        if video["duration"]:
            doc["duration"] = video["duration"]
    if fixtures.demo:
        doc = demo_catalog.demoize_streams(doc, video_id)
    doc = rewrite_images(doc, f"{base}/media/thumb.jpg")
    doc["duration"] = 30  # the synthetic clip's real length, so end-of-item is genuine
    doc["hls"] = f"{base}/media/hls/master.m3u8"
    doc["audioStreams"] = [{
        "url": f"{base}/media/audio.m4a", "bitrate": 32000, "mimeType": "audio/mp4",
        "audioTrackLocale": "en", "audioTrackType": "ORIGINAL",
    }]
    doc["videoStreams"] = [
        {"url": f"{base}/media/video.mp4", "quality": "144p", "mimeType": "video/mp4", "videoOnly": False},
        {"url": f"{base}/media/video_only.mp4", "quality": "144p", "mimeType": "video/mp4", "videoOnly": True},
    ]
    doc["subtitles"] = []
    doc["chapters"] = doc.get("chapters") or []
    return doc


def route(fixtures: Fixtures, path: str, query: str, base: str):
    """(status, json-serialisable body) for an API path, or None if not an API path."""
    qs = parse_qs(query)
    thumb = f"{base}/media/thumb.jpg"

    def doc(name, transform=None):
        loaded = fixtures.load(name)
        if fixtures.demo:
            loaded = transform(loaded) if transform else demo_catalog.demoize(loaded)
        return rewrite_images(loaded, thumb)

    if path == "/healthz":
        return 200, {"ok": True}
    if path.startswith("/search"):
        return 200, doc("search")
    if path.startswith("/trending"):
        return 200, doc("trending")
    if path.startswith("/channels/tabs"):
        data = (qs.get("data") or [""])[0]
        return 200, doc("channelPlaylistTab" if "playlist" in data else "channelTab")
    if path.startswith("/nextpage/"):
        return 200, {"content": [], "nextpage": None}
    if path.startswith("/channel/"):
        return 200, doc("channel", demo_catalog.demoize_channel)
    if path.startswith("/playlists/"):
        playlist_id = unquote(path[len("/playlists/"):])
        return 200, doc("playlist", lambda d: demo_catalog.demoize_playlist(d, playlist_id))
    if path.startswith("/comments/"):
        return 200, demo_catalog.demo_comments() if fixtures.demo else doc("comments")
    if path.startswith("/streams/"):
        video_id = unquote(path[len("/streams/"):])
        if not video_id:
            return 404, {"error": "NotFound", "message": "missing video id"}
        return 200, streams_for(fixtures, video_id, base)
    return None


class Handler(BaseHTTPRequestHandler):
    fixtures: Fixtures = None  # set by serve()
    media: Path = None
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # one line per request, to stdout
        sys.stdout.write("%s %s\n" % (self.address_string(), fmt % args))
        sys.stdout.flush()

    def base(self) -> str:
        host = self.headers.get("Host") or f"{self.server.server_address[0]}:{self.server.server_address[1]}"
        return f"http://{host}"

    def do_HEAD(self):
        self.do_GET(head_only=True)

    def do_GET(self, head_only=False):
        parsed = urlparse(self.path)
        if parsed.path.startswith("/media/"):
            return self.serve_media(parsed.path[len("/media/"):], head_only)
        routed = route(self.fixtures, parsed.path, parsed.query, self.base())
        if routed is None:
            return self.send_json(404, {"error": "NotFound", "message": parsed.path}, head_only)
        status, body = routed
        self.send_json(status, body, head_only)

    def send_json(self, status: int, body, head_only=False):
        data = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        if not head_only:
            self.wfile.write(data)

    def serve_media(self, rel: str, head_only=False):
        target = (self.media / unquote(rel)).resolve()
        if not str(target).startswith(str(self.media.resolve())) or not target.is_file():
            return self.send_json(404, {"error": "NotFound", "message": rel}, head_only)
        size = target.stat().st_size
        ctype = CONTENT_TYPES.get(target.suffix) or mimetypes.guess_type(str(target))[0] or "application/octet-stream"
        start, end = 0, size - 1
        status = 200
        rng = self.headers.get("Range")
        if rng and rng.startswith("bytes="):
            lo, _, hi = rng[len("bytes="):].partition("-")
            start = int(lo) if lo else max(0, size - int(hi))
            end = int(hi) if (hi and lo) else size - 1
            end = min(end, size - 1)
            if start > end or start >= size:
                self.send_response(416)
                self.send_header("Content-Range", f"bytes */{size}")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            status = 206
        length = end - start + 1
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(length))
        self.send_header("Access-Control-Allow-Origin", "*")
        if status == 206:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.end_headers()
        if head_only:
            return
        with target.open("rb") as f:
            f.seek(start)
            remaining = length
            while remaining > 0:
                chunk = f.read(min(65536, remaining))
                if not chunk:
                    break
                self.wfile.write(chunk)
                remaining -= len(chunk)


def export_static(fixtures: Fixtures, media: Path, out: Path, base: str):
    """Write the API as files for static hosting (S3 + CloudFront). Query strings
    are ignored by static hosts, so `/search?q=x` is served by the `search` object;
    upload with the right Content-Type (application/json for extensionless keys)."""
    base = base.rstrip("/")
    out.mkdir(parents=True, exist_ok=True)

    def write(rel: str, body):
        path = out / rel.lstrip("/")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(body), encoding="utf-8")

    for rel in ["/search", "/trending", "/channels/tabs", "/healthz"]:
        write(rel, route(fixtures, rel, "", base)[1])
    channel = fixtures.load("channel") or {}
    for cid in {row.get("url", "").split("/channel/")[-1] for row in (fixtures.load("search") or {}).get("items", [])
                if "/channel/" in (row.get("url") or "")} | {channel.get("id", "")}:
        if cid:
            write(f"/channel/{cid}", route(fixtures, f"/channel/{cid}", "", base)[1])
            write(f"/nextpage/channel/{cid}", {"content": [], "nextpage": None})
    for vid in fixtures.all_video_ids():
        write(f"/streams/{vid}", streams_for(fixtures, vid, base))
        write(f"/comments/{vid}", route(fixtures, f"/comments/{vid}", "", base)[1])
    playlist = fixtures.load("playlist")
    if playlist is not None:
        for row in (fixtures.load("channelPlaylistTab") or {}).get("content", []):
            pid = (row.get("url") or "").split("list=")[-1]
            if pid:
                write(f"/playlists/{pid}", route(fixtures, f"/playlists/{pid}", "", base)[1])
    if (out / "media").exists():
        shutil.rmtree(out / "media")
    shutil.copytree(media, out / "media")
    print(f"✓ exported static API + media to {out} (base {base})")


def serve(host: str, port: int, fixtures: Fixtures, media: Path):
    Handler.fixtures = fixtures
    Handler.media = media
    server = ThreadingHTTPServer((host, port), Handler)
    server.daemon_threads = True
    print(f"fake Piped backend listening on http://{host}:{server.server_address[1]}  "
          f"(fixtures {fixtures.dir}, media {media})", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


def daemonize(log: Path, pidfile: Path):
    """Detach so the caller's shell (a CI step, an SSH session) can exit while
    the server keeps running. Done in-process rather than with `nohup`, which
    fails under a LaunchDaemon-hosted CI runner ("can't detach from console")
    and leaves the step hanging on the inherited stdio. Double-fork, new
    session, stdio onto the log file, pid written for the matching stop step."""
    if os.fork() > 0:
        return False  # parent: let main() exit
    os.setsid()
    if os.fork() > 0:
        os._exit(0)
    sys.stdout.flush(); sys.stderr.flush()
    fd = os.open(str(log), os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
    null = os.open(os.devnull, os.O_RDONLY)
    os.dup2(null, 0); os.dup2(fd, 1); os.dup2(fd, 2)
    pidfile.write_text(str(os.getpid()))
    return True


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", default="127.0.0.1", help="bind address (default loopback; use an SSH tunnel for devices)")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--fixtures", type=Path, default=DEFAULT_FIXTURES)
    ap.add_argument("--media", type=Path, default=DEFAULT_MEDIA)
    ap.add_argument("--catalog", choices=["fixtures", "demo"], default=None,
                    help="fixtures: real captured titles (UI tests; the default when serving). "
                         "demo: labelled placeholders (the default for --export-static)")
    ap.add_argument("--export-static", type=Path, metavar="DIR", help="write the API as static files and exit")
    ap.add_argument("--base-url", default="", help="public base URL baked into exported stream/media links")
    ap.add_argument("--daemon", action="store_true", help="detach and keep serving after this shell exits")
    ap.add_argument("--log", type=Path, default=Path("/tmp/pipe-fake.log"), help="request log when daemonized")
    ap.add_argument("--pidfile", type=Path, default=Path("/tmp/pipe-fake.pid"), help="pid file when daemonized")
    args = ap.parse_args(argv)
    fixtures = Fixtures(args.fixtures, catalog=args.catalog or ("demo" if args.export_static else "fixtures"))
    if args.export_static:
        if not args.base_url:
            ap.error("--export-static needs --base-url (the URL the files will be served from)")
        export_static(fixtures, args.media, args.export_static, args.base_url)
        return 0
    if args.daemon and not daemonize(args.log, args.pidfile):
        print(f"fake Piped backend starting in the background on http://{args.host}:{args.port} (log {args.log}, pid file {args.pidfile})")
        return 0
    serve(args.host, args.port, fixtures, args.media)
    return 0


if __name__ == "__main__":
    sys.exit(main())
