#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export $(cat "$SCRIPT_DIR/../.env" | xargs)

if [ "$#" -lt 1 ]; then
  echo "usage:"
  echo "  $0 /api/some/endpoint [curl args]"
  echo ""
  echo "example:"
  echo "  $0 /api/album"
  echo "  $0 /api/jobs/storageTemplateMigration -X PUT --data-raw '{\"command\":\"start\",\"force\":false}'"
  echo ""
  echo "API doc: https://immich.app/docs/api"
  exit 1
fi
path=$1
shift

exec curl -L "$IMMICH_SERVER$path" -H 'Content-Type: application/json' -H 'Accept: application/json' -H "x-api-key: $IMMICH_KEY" "$@"
