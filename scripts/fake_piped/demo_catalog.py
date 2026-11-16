"""Plainly-labelled demo catalogue for the fake Piped backend.

The UI-test fixtures are real captures (real titles, real channel names), which
is what the acceptance suite asserts on. Anything a reviewer or demo user sees
must not reference a streaming service, so this rewrites a fixture document
into labelled placeholders: videos become "Demo Clip N", channels "Demo
Channel X", descriptions say what the clip is, and comments are disabled.
Deterministic per id, so every endpoint agrees on a video's name.
"""
import hashlib
import re

WATCH_RE = re.compile(r"/watch\?v=([^&]+)")
CHANNEL_RE = re.compile(r"/channel/([^/?]+)")
PLAYLIST_RE = re.compile(r"list=([^&]+)")
CLIP_SECONDS = 30

DESCRIPTION = ("Demo content. This is a %d-second synthetic clip from pipe's built-in demo "
               "library: a generated test pattern with a two-tone audio track. Nothing here "
               "comes from a streaming service. Enter your own Piped instance under "
               "Settings to browse real content." % CLIP_SECONDS)


def _index(key: str, modulo: int) -> int:
    return int(hashlib.sha1(key.encode("utf-8")).hexdigest()[:8], 16) % modulo


def clip_title(video_id: str) -> str:
    return "Demo Clip %d" % (_index(video_id, 97) + 1)


def channel_name(key: str) -> str:
    return "Demo Channel %s" % "ABCDEFGHJKLMNPQRSTUVWXYZ"[_index(key, 24)]


def playlist_name(key: str) -> str:
    return "Demo Playlist %d" % (_index(key, 9) + 1)


def _channel_key(node: dict) -> str:
    for field in ("uploaderUrl", "url"):
        m = CHANNEL_RE.search(node.get(field) or "")
        if m:
            return m.group(1)
    return node.get("uploaderName") or node.get("uploader") or node.get("name") or "demo"


def demoize(node):
    """Rewrite every human-readable field in a fixture document."""
    if isinstance(node, list):
        return [demoize(v) for v in node]
    if not isinstance(node, dict):
        return node
    out = {k: demoize(v) for k, v in node.items()}
    # Opaque pagination/tab tokens embed upstream URLs and names; replace them
    # with inert tokens (the router only looks for the word "playlist").
    if "nextpage" in out:
        out["nextpage"] = None
    if "data" in out and "name" in out:
        out["data"] = "demo-tab:%s" % out["name"]
    url = out.get("url") or ""
    watch = WATCH_RE.search(url)
    if watch:  # a video row (search, trending, related, channel tab)
        out["title"] = clip_title(watch.group(1))
        if "uploaderName" in out:
            out["uploaderName"] = channel_name(_channel_key(out))
        if "duration" in out:
            out["duration"] = CLIP_SECONDS
    elif out.get("type") == "channel" or CHANNEL_RE.search(url):
        out["name"] = channel_name(_channel_key(out))
        if "description" in out:
            out["description"] = DESCRIPTION
    elif PLAYLIST_RE.search(url):  # a playlist row
        out["name"] = playlist_name(PLAYLIST_RE.search(url).group(1))
        if "uploaderName" in out:
            out["uploaderName"] = channel_name(_channel_key(out))
    if "commentText" in out:  # a comment: never shown in demo mode
        out["commentText"] = ""
        out["author"] = "demo"
    return out


def demoize_streams(doc: dict, video_id: str) -> dict:
    out = demoize(doc)
    out["title"] = clip_title(video_id)
    out["uploader"] = channel_name(_channel_key(doc))
    out["description"] = DESCRIPTION
    return out


def demoize_channel(doc: dict) -> dict:
    out = demoize(doc)
    out["name"] = channel_name(doc.get("id") or "demo")
    out["description"] = DESCRIPTION
    return out


def demoize_playlist(doc: dict, playlist_id: str) -> dict:
    out = demoize(doc)
    out["name"] = playlist_name(playlist_id)
    out["uploader"] = channel_name(doc.get("uploaderUrl") or doc.get("uploader") or "demo")
    return out


def demo_comments() -> dict:
    return {"comments": [], "disabled": True}
