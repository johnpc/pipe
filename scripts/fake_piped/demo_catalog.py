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

# The catalogue reads like a real audio-first library — podcasts, talks, long
# mixes — rather than "Demo Clip 72". Every name is invented; none references a
# streaming service, a real show, or a real person. Deterministic per id, so
# every endpoint agrees on a video's name (and its art, see `assign_art`).
TITLES = [
    "The Long Walk Home — Episode 12: Night Shift",
    "Deep Focus: Rain on a Tin Roof (2 hours)",
    "Morning Run Mix, Vol. 3",
    "How Lighthouses Were Built (and Why They Still Matter)",
    "Field Notes #41: The Marsh at Dawn",
    "Slow Coffee: A Conversation About Doing Less",
    "Office Hours — Building a Tiny Business, Week 9",
    "Late Night Jazz for Reading",
    "The Cartographer's Table: Maps That Lied",
    "Quiet Hours: Piano Sketches, No Talking",
    "Trail Report — Spring Thaw on the North Ridge",
    "What a Watchmaker Hears",
    "Study Beats, Side B",
    "The Reading Room: Three Short Stories",
    "Backyard Astronomy: Finding Saturn by Hand",
    "Kitchen Table Economics, Part 2",
    "Ambient Tape Loops for Falling Asleep",
    "Tuesday Standup: What Shipped, What Broke",
    "Harbor Sounds at Low Tide",
    "A Brief History of the Pencil",
    "Night Drive — 90 Minutes of Synth",
    "The Repair Shop Diaries: A 1964 Radio",
    "Hill Country Weather, Explained",
    "Weekend Long Read: The Lost Orchard",
    "Warm-Up Set: Easy Tempo, Easy Mood",
    "Letters From the Lighthouse Keeper",
    "Learning Dutch on the Bus, Lesson 7",
    "Rooftop Session — Live From the Roof",
    "The Slow Garden: Soil, Patience, Tomatoes",
    "Chess for the Commute: Openings",
    "Rainforest Canopy — Dawn Chorus Recording",
    "Grandma's Kitchen, Episode 3: Bread",
    "How Elevators Decide Where to Go",
    "Brass Band Rehearsal, Open Doors",
    "Minimal Techno for Spreadsheets",
    "The Apprentice Carpenter, Week One",
    "Wind Across the Dunes (Binaural)",
    "City Council Recap in Plain Words",
    "Lullabies From Four Countries",
    "The Bakery at 4 A.M.",
    "Folk Session at the Corner Pub",
    "Rivers I Have Paddled, Chapter 5",
    "Vinyl Hour: Side One",
    "Why Bridges Hum",
    "Campfire Stories, Unedited",
    "Monday Reset: Stretch and Breathe",
    "Deep Sea Soundscape, Pressure Hull",
    "The Night Train to Nowhere in Particular",
]
CHANNELS = [
    "Northwind Audio", "Quiet Hours", "Field Notes", "The Reading Room", "Harbor Light Radio",
    "Slow Coffee", "Trailhead Talks", "Workshop Sounds", "Night Drive FM", "Kitchen Table",
    "Rooftop Sessions", "Open Doors Collective",
]
PLAYLISTS = [
    "Commute Companions", "Sleep & Focus", "Long Reads, Read Aloud", "Weekend Workshop",
    "Live Recordings", "Morning Starters",
]
# Realistic run times (seconds) a listener expects: 8-minute shorts to 2-hour mixes.
DURATIONS = [512, 1848, 2731, 3605, 7215, 1264, 2937, 4420, 905, 2210, 6480, 1537]
N_THUMBS = 12
N_AVATARS = 8


def _index(key: str, modulo: int) -> int:
    return int(hashlib.sha1(key.encode("utf-8")).hexdigest()[:8], 16) % modulo


# Set by `use_catalog` when the whole catalogue is known: ids ranked so each
# gets a distinct title (hashing alone collides on a 48-title list).
_TITLE_RANK = {}
RELATIVE_DATES = ["2 days ago", "5 days ago", "1 week ago", "2 weeks ago", "3 weeks ago", "1 month ago", "2 months ago", "4 months ago"]


def use_catalog(video_ids):
    """Rank every id in the catalogue so titles are unique (up to the list size)."""
    _TITLE_RANK.clear()
    for rank, vid in enumerate(sorted(set(video_ids))):
        _TITLE_RANK[vid] = rank


def clip_title(video_id: str) -> str:
    if video_id in _TITLE_RANK:
        return TITLES[_TITLE_RANK[video_id] % len(TITLES)]
    return TITLES[_index(video_id, len(TITLES))]


def relative_date(video_id: str) -> str:
    return RELATIVE_DATES[_index("date:" + video_id, len(RELATIVE_DATES))]


def channel_name(key: str) -> str:
    return CHANNELS[_index(key, len(CHANNELS))]


def playlist_name(key: str) -> str:
    return PLAYLISTS[_index(key, len(PLAYLISTS))]


def clip_duration(video_id: str) -> int:
    return DURATIONS[_index(video_id, len(DURATIONS))]


# Which ids are "on air" / "still to come": decided by position in a channel's
# video list (see `demoize_channel`), so a followed channel's feed always shows
# the Live now and Upcoming sections. Everything else is an upload.
_STATUS = {}


def listing_status(video_id: str) -> str:
    return _STATUS.get(video_id, "video")


def _mark_statuses(rows):
    """Second row live, third row an upcoming premiere, in a channel's list."""
    ids = [WATCH_RE.search(r.get("url") or "") for r in rows if isinstance(r, dict)]
    ids = [m.group(1) for m in ids if m]
    if len(ids) > 1:
        _STATUS[ids[1]] = "live"
    if len(ids) > 2:
        _STATUS[ids[2]] = "upcoming"


def upcoming_start(now=None) -> str:
    """Piped's premiere shape: a UTC wall clock, ~6 weeks out at 20:00 so a
    static export stays "upcoming" for a while before it reads as started."""
    import datetime as _dt
    base = (now or _dt.datetime.now(_dt.timezone.utc)) + _dt.timedelta(days=41)
    return base.strftime("%Y-%m-%d") + " 20:00"


def thumb_path(key: str) -> str:
    return "/media/art/thumb-%02d.jpg" % _index("thumb:" + key, N_THUMBS)


def avatar_path(key: str) -> str:
    return "/media/art/avatar-%02d.jpg" % _index("avatar:" + key, N_AVATARS)


def assign_art(node, base: str):
    """Give every row its own artwork (thumbnails by video/playlist id, avatars
    by channel) instead of one shared placeholder, so screens look like a
    library. Runs after `rewrite_images`, which already made every image URL
    local; this only re-points the ones it recognises."""
    if isinstance(node, list):
        return [assign_art(v, base) for v in node]
    if not isinstance(node, dict):
        return node
    out = {k: assign_art(v, base) for k, v in node.items()}
    url = out.get("url") or ""
    watch = WATCH_RE.search(url)
    if watch and "thumbnail" in out:
        out["thumbnail"] = base + thumb_path(watch.group(1))
    elif (out.get("type") == "channel" or CHANNEL_RE.search(url)) and "thumbnail" in out:
        out["thumbnail"] = base + avatar_path(_channel_key(out))
    elif PLAYLIST_RE.search(url) and "thumbnail" in out:
        out["thumbnail"] = base + thumb_path(PLAYLIST_RE.search(url).group(1))
    if "uploaderAvatar" in out:
        out["uploaderAvatar"] = base + avatar_path(_channel_key(out))
    if "avatarUrl" in out:  # a channel document
        out["avatarUrl"] = base + avatar_path(out.get("id") or "demo")
    if "bannerUrl" in out:
        out["bannerUrl"] = base + "/media/art/banner.jpg"
    return out


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
        video_id = watch.group(1)
        out["title"] = clip_title(video_id)
        if "uploaderName" in out:
            out["uploaderName"] = channel_name(_channel_key(out))
        status = listing_status(video_id)
        if "duration" in out:
            out["duration"] = -1 if status != "video" else clip_duration(video_id)
        if status == "live":
            out["uploadedDate"] = None
            out["uploaded"] = -1
        elif status == "upcoming":
            out["uploadedDate"] = upcoming_start()
        elif "uploadedDate" in out and "ago" not in str(out.get("uploadedDate") or ""):
            out["uploadedDate"] = relative_date(video_id)  # a fixture premiere/live row becomes an upload
        if "isShort" in out:
            out["isShort"] = False
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
    out["livestream"] = listing_status(video_id) == "live"
    return out


def demoize_channel(doc: dict) -> dict:
    _mark_statuses(doc.get("relatedStreams") or [])
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
