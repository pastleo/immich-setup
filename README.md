Immich setup
===

## Ops

TODO: add doc

## Setup

https://immich.app/docs/install/docker-compose/

```bash
git clone https://github.com/pastleo/immich-setup immich-app
cd immich-app

wget https://github.com/immich-app/immich/releases/latest/download/example.env
mv example.env .env

vi .env
# UPLOAD_LOCATION=./upload
# EXTERNAL_PATH=/path/to/memories
# IMMICH_VERSION=vx.xx.x from https://github.com/immich-app/immich/releases
# DB_PASSWORD=xxxxxxxxxx from openssl rand -hex xx

docker compose up -d
docker-compose logs --tail=300 -f
```

### Setup `ops/.env`

```bash
cd ops/
cp example.env .env
vi .env # get IMMICH_KEY from immich web interface under "Account Settings"
```

### Setup `ops/immich-client/immich-go` for `ops/immich-client/go-cli.sh`

https://github.com/simulot/immich-go

download and extract `ops/immich-client/immich-go/immich-go` from https://github.com/simulot/immich-go/releases

for example:

```bash
mkdir ops/immich-client/immich-go
cd ops/immich-client/immich-go
wget https://github.com/simulot/immich-go/releases/download/0.12.0/immich-go_Linux_x86_64.tar.gz
tar xzvf immich-go_Linux_x86_64.tar.gz

# test
./immich-go --help
```
