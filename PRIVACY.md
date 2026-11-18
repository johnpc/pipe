# pipe privacy policy

_Last updated: 2026-11-17_

pipe is an audio and video player for Piped instances. It has no accounts and
no sign-in, and the developer runs no service that your listening passes through.

## What leaves your device

**Requests to the Piped instance you choose.** pipe ships with no server. When you
enter an instance URL (or pick the demo library), the app sends your searches,
the channels you open, and the videos you play to that instance so it can answer
them. That instance's operator can see those requests; pipe adds no identifiers
to them. The demo library is a set of static files hosted by the developer and
contains only synthetic sample clips; it logs nothing about you.

**SponsorBlock lookups (on by default, can be turned off).** To skip sponsor
segments, pipe asks the public SponsorBlock API (sponsor.ajay.app) for the
segments of the video you're playing. Only the video id is sent.

**Diagnostics upload (off by default, opt in).** If you turn on Settings →
Diagnostics → Upload Diagnostics, playback events (item started, buffering,
errors, and similar) are uploaded to the developer's collector together with a
random device identifier generated on first launch, the app version, and the
iOS version and device model. These logs contain the video ids you played and
the instance URL you configured, and are used only to diagnose playback
problems. They are kept for 90 days. Nothing is uploaded while the toggle is off;
the same log is always available on-device under Settings → Diagnostics.

## What stays on your device

Your queue, watch history and resume positions, followed channels, saved items,
downloads, playback speed, audio-language and casting preferences, and the
instance URL are stored only on the device (and in its iCloud/iTunes backups).
Clear them from the app's own screens or by deleting the app.

## Casting

When you cast to a TV, the Google Cast SDK on your device talks to the receiver
on your local network and to Google's Cast services as described in Google's
privacy policy. pipe sends the receiver the media URL and title to play.

## Children

pipe is not directed at children under 13 and collects no personal information.

## Contact

Questions: open an issue at https://github.com/johnpc/pipe/issues.
