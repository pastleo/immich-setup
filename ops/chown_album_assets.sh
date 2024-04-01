#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENV_FILE="$SCRIPT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "no $ENV_FILE"
  exit 1
fi
export $(cat "$ENV_FILE" | xargs)

if [ "$#" -ne 1 ]; then
  echo "usage:"
  echo "  $0 albumUuid"
  echo ""
  echo "albumUuid can be seen in URL"
  exit 1
fi

ALBUM_UUID=$1

# SELECT "id", "albumName", "ownerId" FROM albums WHERE "id" = '$ALBUM_UUID' AND "ownerId" = (SELECT "id" FROM users WHERE "email" = '$IMMICH_EMAIL');

read -r -d '' PSQL_SCRIPT <<-PSQL_SCRIPT
  UPDATE assets SET "ownerId" = (SELECT "id" FROM users WHERE "email" = '$IMMICH_EMAIL') WHERE
    "id" IN (SELECT "assetsId" FROM albums_assets_assets WHERE "albumsId" = '$ALBUM_UUID')
    AND "ownerId" != (SELECT "id" FROM users WHERE "email" = '$IMMICH_EMAIL');
PSQL_SCRIPT
echo "> $PSQL_SCRIPT"

set -e
cd "$SCRIPT_DIR/.."
docker-compose exec -e PSQL_SCRIPT="$PSQL_SCRIPT" database bash -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "$PSQL_SCRIPT"'

echo "database updated, sleep 2s..."
sleep 2

echo "starting storageTemplateMigration..."
"$SCRIPT_DIR/immich-client/curl.sh" /api/jobs/storageTemplateMigration -X PUT --data-raw '{"command":"start","force":false}'
