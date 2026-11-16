#!/usr/bin/env bash
# Regenerate the fake backend's media: a 30-second synthetic clip (test pattern
# + a two-tone melody) as HLS (fMP4, separate audio rendition — the shape of
# YouTube's masters the app plays first), a muxed MP4, a video-only MP4, and an
# audio-only M4A for the direct-URL fallback. Nothing here is YouTube content,
# so it is safe for CI and for an App Store review build.
# Requires ffmpeg. Output is committed; rerun only when changing the clip.
set -euo pipefail
cd "$(dirname "$0")/media"
DUR=30
rm -rf hls && mkdir hls

# Audio: a soft alternating two-note tone so "is sound coming out" is obvious.
ffmpeg -y -loglevel error -f lavfi -i "sine=frequency=440:duration=$DUR" \
  -f lavfi -i "sine=frequency=554:duration=$DUR" \
  -filter_complex "[0:a][1:a]amix=inputs=2,volume=0.3,tremolo=f=0.5:d=0.9[a]" -map "[a]" \
  -c:a aac -b:a 32k -ac 1 -movflags +faststart audio.m4a

# Video: moving test pattern (testsrc2 carries its own running counter).
ffmpeg -y -loglevel error -f lavfi -i "testsrc2=size=256x144:rate=10:duration=$DUR" \
  -c:v libx264 -preset veryslow -crf 36 -pix_fmt yuv420p -g 30 -an -movflags +faststart video_only.mp4

ffmpeg -y -loglevel error -i video_only.mp4 -i audio.m4a -c copy -movflags +faststart video.mp4

# HLS: one video variant + one English audio rendition group, fMP4 segments.
ffmpeg -y -loglevel error -i video_only.mp4 -i audio.m4a \
  -map 0:v -map 1:a -c copy \
  -f hls -hls_time 6 -hls_playlist_type vod -hls_segment_type fmp4 \
  -hls_flags independent_segments -hls_segment_filename "hls/seg_%v_%03d.m4s" \
  -hls_fmp4_init_filename "init_%v.mp4" \
  -var_stream_map "a:0,agroup:aud,language:en,name:English v:0,agroup:aud" \
  -master_pl_name master.m3u8 "hls/stream_%v.m3u8"
du -sh .

# Thumbnail/avatar placeholder (one frame of the pattern) so no request from a
# demo build reaches YouTube's image CDN either.
ffmpeg -y -loglevel error -f lavfi -i "testsrc2=size=320x180:rate=1:duration=1" -frames:v 1 -q:v 6 thumb.jpg
