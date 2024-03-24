#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export $(cat "$SCRIPT_DIR/../.env" | xargs)

exec "$SCRIPT_DIR/immich-go/immich-go" -server "$IMMICH_SERVER" -key "$IMMICH_KEY" "$@"
