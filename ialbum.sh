#!/bin/bash
function curl_post_json {
	curl -sH "Content-Type: application/json" -X POST -d "@-" "$@"
}

BASE_API_URL="https://p23-sharedstreams.icloud.com/$(echo $1 | cut -d# -f2)/sharedstreams"

pushd $2 > /dev/null
STREAM=$(echo '{"streamCtag":null}' | curl_post_json "$BASE_API_URL/webstream")
HOST=$(echo $STREAM | jq '.["X-Apple-MMe-Host"]' | cut -c 2- | rev | cut -c 2- | rev)

if [ "$HOST" ]; then
    BASE_API_URL="https://$(echo $HOST)/$(echo $1 | cut -d# -f2)/sharedstreams"
    STREAM=$(echo '{"streamCtag":null}' | curl_post_json "$BASE_API_URL/webstream")
fi

CHECKSUMS=$(echo $STREAM | jq -r '.photos[] | [(.derivatives[] | {size: .fileSize | tonumber, value: .checksum})] | max_by(.size | tonumber).value')

echo $STREAM \
| jq -c "{photoGuids: [.photos[].photoGuid]}" \
| curl_post_json "$BASE_API_URL/webasseturls" \
| jq -r '.items | to_entries[] | "https://" + .value.url_location + .value.url_path + "&" + .key' \
| while read URL; do
	for CHECKSUM in $CHECKSUMS; do
		if echo $URL | grep $CHECKSUM > /dev/null; then
			curl -sOJ $URL &
			break
		fi
	done
done

popd > /dev/null
wait