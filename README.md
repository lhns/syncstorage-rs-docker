# syncstorage-rs-docker

A simple Docker container and Docker Compose configuration to get started with [mozilla-services/syncstorage-rs](https://github.com/mozilla-services/syncstorage-rs) to self-host a Firefox sync server.

I didn't have much luck with the existing documentation and wrote this for my own infrastructure. There's no guarantee it will work for you.

## Database backends

syncstorage-rs picks its database backend at **compile time**, so each image ships a single backend. This repo supports two:

- **PostgreSQL** (default) — a single shared database for syncstorage and tokenserver.
- **MySQL / MariaDB** — two separate databases.

SQLite is **not** supported by syncstorage-rs upstream ([issue #498](https://github.com/mozilla-services/syncstorage-rs/issues/498)), and Spanner (which needs Google Cloud) is out of scope here.

CI publishes one image per backend, suffixed accordingly (e.g. `...-postgres` and `...-mysql`). When building locally with Compose, the backend is selected by the `SYNC_BACKEND` variable in your `.env`.

### Databases & configuration

syncstorage-rs runs two services — **syncstorage** (your sync data) and **tokenserver** (user routing) — and each needs a database URL. Both are required:

- `SYNC_SYNCSTORAGE__DATABASE_URL`
- `SYNC_TOKENSERVER__DATABASE_URL`

MySQL and PostgreSQL work the same way: point each URL at a database, and the server creates every table itself (migrations run automatically at startup). You just need the **empty** database(s) to exist first. You can point both URLs at the **same** database or at **two separate** ones — your choice.

The example config is ready to run as-is:

- **PostgreSQL** — both URLs point at one shared `syncserver` database, created by `POSTGRES_DB` in `docker-compose.yaml`.
- **MySQL** — the URLs point at two databases, `syncstorage_rs` and `tokenserver_rs`, created by `data/initdb.d/init.sql`.

To use a different layout, edit the URLs and make sure each database you point at exists.

Both schema migration sets are applied **automatically at server startup** (syncstorage's schema, plus tokenserver's via `SYNC_TOKENSERVER__RUN_MIGRATIONS=true`), and the `sync-1.5` node is bootstrapped from `SYNC_URL` (`SYNC_TOKENSERVER__INIT_NODE_URL`). There is no manual migration or seeding step. All of these values are set in `.env` / `docker-compose.yaml` — see the comments in `example.env` for the full list.

## Getting started

So far these steps have been shown to work on Debian based distros including Raspbian and Debian Bullseye.

To get started clone this repository. You will need to have [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/) installed.

### Environment Variables

The Docker Compose file makes use of environment variables. To configure them, make a copy of example.env

```bash
cp example.env .env
```

Now edit the new `.env` file to add configuration and secrets. Keep in mind the `SYNC_MASTER_SECRET` and `METRICS_HASH_SECRET` require 64 characters.

### Choosing a backend

`.env` defaults to PostgreSQL. To use it, just set a `POSTGRES_PASSWORD` (and the other secrets) and leave `SYNC_BACKEND=postgres` / `COMPOSE_PROFILES=postgres`.

To use MySQL instead:

1. Set `SYNC_BACKEND=mysql` and `COMPOSE_PROFILES=mysql`.
2. Fill in `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD`.
3. Switch the two `SYNC_*__DATABASE_URL` values to the commented `mysql://` versions.

### Initial Run

```bash
docker compose up -d --build && docker compose logs -f
```

The first time you run the application, it will do a few things:

1. The database container (PostgreSQL or MariaDB, depending on `COMPOSE_PROFILES`) is pulled and initialised. For MySQL, `./data/initdb.d/init.sql` creates the required databases and permissions on first run.

2. The Dockerfile builds the syncserver app. This is a Rust app, so all of the required dependencies are compiled and the Mozilla syncstorage-rs repo is cloned at a pinned revision. This will take several minutes.

3. On startup the server **applies its own schema migrations** and **bootstraps the `sync-1.5` node** from `SYNC_URL` — there is no manual migration or seeding step. Once everything is up you should see startup logs. Subsequent runs of `docker compose up -d` are much faster because the build artifacts are cached. Database data is persisted in `./data` between restarts.

You can confirm the server is healthy with:

```bash
curl -f http://localhost:8000/__heartbeat__
```

### Rebuilding Everything

In the course of setting this up, you may need to tear down and rebuild your instance. To remove persisted data and artifacts, run the following.

```bash
docker compose down
docker image rm app-syncserver
docker builder prune -af
rm -rf ./data/config ./data/postgres
```

This will delete the compiled Rust app and any cached layers, and also delete the database data.

### Firefox Setup

Once your app is running, you can configure Firefox by updating the `about:config` settings.

`identity.sync.tokenserver.uri` needs to be set to the `SYNC_URL` configured in your `.env` file followed by `/1.0/sync/1.5`. 

>Example: http://sync.example.com:8000/1.0/sync/1.5

To confirm the sync is working you can enable success logs in `about:config` also. Set `services.sync.log.appender.file.logOnSuccess` to true. Now you should see sync logs in `about:sync-log`

Syncing is usually very quick, and when a sync occurs you can see logs in `docker compose logs -f` also.
