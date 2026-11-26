"""A followed channel as big as a real feed, for the background-CPU gate.

The fixture channel has 5 videos; the owner's real feed has hundreds. Work the
app repeats per row on every playback tick only hurts at that scale (the
2026-11-26 cpu_resource_fatal kills: the feed re-parsed every row's date ~6x a
second, in the background). `pad(doc, n)` grows a channel's `relatedStreams`
to `n` rows, cycling the date shapes Piped really sends: relative text, ISO
8601, and a channel list's day-first UTC wall clock for premieres.
"""
import copy
from datetime import datetime, timedelta, timezone

RELATIVE = ["1 hour ago", "3 days ago", "2 weeks ago", "1 month ago", "11 months ago"]


def date_shapes(i: int, now: datetime) -> tuple:
    """(uploadedDate, duration-or-None) for row i: a rotating mix of shapes."""
    past = now - timedelta(hours=6 * (i + 1))
    kind = i % 4
    if kind == 0:
        return past.strftime("%Y-%m-%dT%H:%M:%S.000Z"), None
    if kind == 1:
        return past.strftime("%d/%m/%Y, %H:%M"), None  # a premiere that already aired
    if kind == 2 and i % 200 == 2:
        return (now + timedelta(days=1 + i % 5)).strftime("%d/%m/%Y, %H:%M"), -1  # upcoming
    return RELATIVE[i % len(RELATIVE)], None


def pad(doc: dict, n: int, now: datetime = None) -> dict:
    """`doc` with `relatedStreams` grown to `n` rows (unchanged if already that big)."""
    rows = (doc or {}).get("relatedStreams") or []
    if n <= len(rows) or not rows:
        return doc
    now = now or datetime.now(timezone.utc)
    out = copy.deepcopy(doc)
    grown = list(out["relatedStreams"])
    for i in range(len(rows), n):
        row = copy.deepcopy(rows[i % len(rows)])
        row["url"] = f"/watch?v=perf{i:07d}"  # 11 chars, like a real video id
        row["title"] = f"{row.get('title', 'Video')} #{i}"
        uploaded_date, duration = date_shapes(i, now)
        row["uploadedDate"] = uploaded_date
        if duration is not None:
            row["duration"] = duration
        row["uploaded"] = int((now - timedelta(hours=6 * (i + 1))).timestamp() * 1000)
        grown.append(row)
    out["relatedStreams"] = grown
    return out
