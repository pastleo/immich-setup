#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENV_FILE="$SCRIPT_DIR/../.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "no $ENV_FILE"
  exit 1
fi
export $(cat "$ENV_FILE" | xargs)

exec "$SCRIPT_DIR/immich-go/immich-go" -server "$IMMICH_SERVER" -key "$IMMICH_KEY" "$@"
