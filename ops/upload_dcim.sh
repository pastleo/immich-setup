#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

set -e

"$SCRIPT_DIR/immich-client/go-cli.sh" upload --album DCIM "$SCRIPT_DIR/../DCIM/"

echo "DCIM uploaded, sleep 10s..."
sleep 10

echo "starting storageTemplateMigration..."
"$SCRIPT_DIR/immich-client/curl.sh" /api/jobs/storageTemplateMigration -X PUT --data-raw '{"command":"start","force":false}'
