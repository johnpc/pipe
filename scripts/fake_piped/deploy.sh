#!/usr/bin/env bash
# Deploy the demo backend: create/update the CloudFront + S3 stack, export the
# fake Piped API as static files against the distribution's URL, upload with
# the right content types, and invalidate. Idempotent; safe to rerun.
#
#   scripts/fake_piped/deploy.sh            # profile "personal", us-west-2
#   AWS_PROFILE=other AWS_REGION=us-east-1 scripts/fake_piped/deploy.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
export AWS_PROFILE="${AWS_PROFILE:-personal}" AWS_REGION="${AWS_REGION:-us-west-2}" AWS_PAGER=""
STACK="${PIPE_DEMO_STACK:-pipe-demo-backend}"
OUT="$(mktemp -d)/export"

echo "▶ stack $STACK ($AWS_PROFILE/$AWS_REGION)"
aws cloudformation deploy --stack-name "$STACK" --template-file scripts/fake_piped/demo-backend.yaml --no-fail-on-empty-changeset
BUCKET=$(aws cloudformation describe-stacks --stack-name "$STACK" --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" --output text)
BASE=$(aws cloudformation describe-stacks --stack-name "$STACK" --query "Stacks[0].Outputs[?OutputKey=='BaseURL'].OutputValue" --output text)
DIST=$(aws cloudfront list-distributions --query "DistributionList.Items[?DomainName=='${BASE#https://}'].Id" --output text)
echo "  bucket $BUCKET, base $BASE, distribution $DIST"

echo "▶ export (demo catalogue)"
python3 -I scripts/fake_piped/server.py --export-static "$OUT" --base-url "$BASE" --catalog demo

echo "▶ upload"
# API objects are extensionless JSON; media by extension. --delete keeps the
# bucket an exact mirror of the export.
aws s3 sync "$OUT" "s3://$BUCKET" --delete --exclude "media/*" --content-type application/json --cache-control "public, max-age=300" --only-show-errors
sync_media() { aws s3 sync "$OUT/media" "s3://$BUCKET/media" --exclude "*" --include "$1" --content-type "$2" --cache-control "public, max-age=86400" --only-show-errors; }
sync_media "*.m3u8" application/vnd.apple.mpegurl
sync_media "*.m4s"  video/iso.segment
sync_media "*.mp4"  video/mp4
sync_media "*.m4a"  audio/mp4
sync_media "*.jpg"  image/jpeg

echo "▶ invalidate"
aws cloudfront create-invalidation --distribution-id "$DIST" --paths "/*" --query "Invalidation.Id" --output text

echo "▶ verify (anonymous, as the app would)"
curl -fsS "$BASE/healthz"; echo
curl -fsS "$BASE/streams/gar4U3n-ILY" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(" ", d["title"], "|", d["uploader"], "|", d["hls"])'
curl -fsS -o /dev/null -w "  master %{http_code} %{content_type}\n" "$BASE/media/hls/master.m3u8"
curl -fsS -o /dev/null -w "  range  %{http_code} %{size_download} bytes\n" -H "Range: bytes=0-99" "$BASE/media/audio.m4a"
curl -s -o /dev/null -w "  missing %{http_code}\n" "$BASE/streams/does-not-exist"
echo "✅ demo backend: $BASE"
