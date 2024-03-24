#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "usage:"
  echo "  $0 ownerEmail albumUuid"
  echo ""
  echo "albumUuid can be seen in URL"
  exit 1
fi

OWNER_EMAIL=$1
ALBUM_UUID=$2
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# SELECT "id", "albumName", "ownerId" FROM albums WHERE "id" = '$ALBUM_UUID' AND "ownerId" = (SELECT "id" FROM users WHERE "email" = '$OWNER_EMAIL');

read -r -d '' PSQL_SCRIPT <<-PSQL_SCRIPT
  UPDATE assets SET "ownerId" = (SELECT "id" FROM users WHERE "email" = '$OWNER_EMAIL') WHERE
    "id" IN (SELECT "assetsId" FROM albums_assets_assets WHERE "albumsId" = '$ALBUM_UUID')
    AND CHECKSUM NOT IN (SELECT CHECKSUM FROM assets WHERE "ownerId" = (SELECT "id" FROM users WHERE "email" = '$OWNER_EMAIL'));
PSQL_SCRIPT
echo "> $PSQL_SCRIPT"

set -e
cd "$SCRIPT_DIR/.."
docker-compose exec -e PSQL_SCRIPT="$PSQL_SCRIPT" database bash -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "$PSQL_SCRIPT"'

echo "database updated, sleep 10s..."
sleep 10

echo "starting storageTemplateMigration..."
"$SCRIPT_DIR/immich-client/curl.sh" /api/jobs/storageTemplateMigration -X PUT --data-raw '{"command":"start","force":false}'
