"""Read `ps -o time=` ([[dd-]hh:]mm:ss.ss) on stdin, print CPU seconds."""
import sys

raw = sys.stdin.read().strip()
days, _, clock = raw.rpartition("-")
seconds = 0.0
for part in clock.split(":"):
    seconds = seconds * 60 + float(part)
print(seconds + (int(days) * 86400 if days else 0))
