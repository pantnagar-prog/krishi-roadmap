# Running the Krishi Roadmap site in Docker

The site is static HTML, so the container is just **nginx + two files**. Nothing
is installed on your machine except Docker itself.

## Why Docker at all?

The site needs *something* to serve it over HTTP. Without a container you would
install a web server (or Python, or Node) directly on the machine, and every
demo machine ends up with a slightly different pile of leftovers — different
nginx versions, stray config in `/etc`, a Python you no longer remember
installing. That drift is what "contaminating the environment" means: the thing
works on the laptop it was set up on and nowhere else.

A container puts the server, its config, and the site in one sealed image:

- **Nothing lands on the host.** Delete the image and the machine is exactly as
  it was. No packages, no config files, no ports left listening.
- **Same bytes everywhere.** The image that runs on your laptop is the image
  that runs on the department's server. No "works on my machine".
- **Pinned versions.** nginx is fixed at 1.27-alpine, so a host upgrade six
  months from now cannot change how the site behaves.
- **One command to hand over.** Anyone with Docker runs the site without being
  told how to install or configure a web server.

For a site this small it is mostly about the first and last points — clean
machines, and a demo anyone can start in one command.

## Requirements

Docker Desktop (Windows/macOS) or Docker Engine (Linux). Nothing else.

## Build and run

```bash
docker build -t krishi-roadmap:latest .
docker run --rm -p 8080:8080 --name krishi krishi-roadmap:latest
```

Then open <http://localhost:8080>.

`--rm` deletes the container when you stop it (Ctrl+C), leaving nothing behind.

### Or with Compose

```bash
docker compose up --build -d     # start in the background
docker compose logs -f           # watch the logs
docker compose down              # stop and remove
```

### Port already in use?

Map a different host port — the left-hand number is the one you visit:

```bash
docker run --rm -p 9000:8080 krishi-roadmap:latest    # http://localhost:9000
```

## Editing the site

The image is a snapshot: editing `index.html` on disk does **not** change a
running container. Either rebuild (`docker compose up --build`), or uncomment
the `volumes:` block at the bottom of `docker-compose.yml` to mount your working
copy live — then a save plus a browser refresh is enough.

## Shipping it

```bash
# Tag against a registry (GitHub Container Registry shown here)
docker tag krishi-roadmap:latest ghcr.io/<your-org>/krishi-roadmap:v1
docker push ghcr.io/<your-org>/krishi-roadmap:v1
```

On the target server: `docker run -d -p 80:8080 --restart unless-stopped ghcr.io/<your-org>/krishi-roadmap:v1`

To hand the image over without a registry (useful for an offline demo):

```bash
docker save krishi-roadmap:latest | gzip > krishi-roadmap.tar.gz
# on the other machine:
docker load < krishi-roadmap.tar.gz
```

## What's in the image

| File | Purpose |
|---|---|
| `Dockerfile` | Copies the site into `nginx:1.27-alpine`, runs as the non-root `nginx` user |
| `nginx.conf` | Server block: port 8080, gzip, cache headers, security headers, `/healthz` |
| `.dockerignore` | Keeps `.git` and editor noise out of the build context |
| `docker-compose.yml` | One-command start/stop, optional live-edit mounts |

Two details worth knowing:

- **Port 8080, not 80.** The container runs as a non-root user, and non-root
  processes cannot bind ports below 1024. Map it to 80 on the host if you want
  (`-p 80:8080`) — that is the host's port, which Docker binds as root.
- **`/healthz`** returns `ok`. Docker's `HEALTHCHECK` polls it, and any
  orchestrator (Compose, Kubernetes, a load balancer) can use the same URL.

## Housekeeping

```bash
docker ps                            # what's running
docker stop krishi                   # stop it
docker image rm krishi-roadmap:latest  # remove the image
docker system prune                  # reclaim space from stopped containers/layers
```
