# Deploying the Krishi Roadmap site properly

Notes for the Google Cloud VM (`upload@ukra-server`), written after the review
questions: *"Is the IP static? I hope you have not deployed the code manually.
How did we deploy? Docker? — deploy it as a docker image, else the environment
will get contaminated."*

---

## 1. What was actually being asked

Two separate questions were asked, and they are worth separating:

**"Is the IP static?"** — Does the server keep the same address forever, or can
it change? On Google Cloud, a VM gets an **ephemeral** external IP by default.
Stop and start the VM and *the IP changes*. Anything pointing at the old address
— a DNS record, a bookmark, a link in a circular — silently breaks. "Accessed
via SSH" does not answer this question; SSH is *how you log in*, not *whether
the address is permanent*. See section 3 to check and fix it.

**"I hope you have not deployed the code manually."** — This is not about your
HTML. It is about the server. See section 2.

---

## 2. Why Docker, when the site is one HTML file

For a single HTML file on your own laptop, Docker genuinely is overkill. That is
not what the concern is about. The concern is the **shared server**.

Deploying manually means someone SSH'd into `ukra-server` and, by hand:
installed a web server, edited config files somewhere under `/etc`, and copied
files into some directory. That works — the site comes up. The problems appear
later:

- **Nobody knows what is on the box.** Which web server, which version, which
  config file was edited, which packages were pulled in as dependencies. It
  lives in one person's memory and nowhere else.
- **It cannot be reproduced.** If the VM dies, or a second server is needed, or
  someone must rebuild it in a year — there is no recipe. Only guesswork.
- **The next project collides with this one.** Someone deploys a second site to
  the same VM, installs a conflicting package or grabs port 80, and now two
  unrelated things break each other. This is the "contamination".
- **There is no undo.** A bad manual change has no clean rollback. With images,
  you re-run the previous tag.
- **No record of what changed, or when, or by whom.** Files copied over SSH
  leave no trail.

Docker fixes all five by making the deployment **a file in the repository**
instead of a sequence of remembered commands. `Dockerfile` and `nginx.conf` are
now the complete, readable, version-controlled answer to "how is this served?"
Anyone can read them. Anyone can reproduce the exact same server.

The server itself then only ever needs one thing installed: Docker. Nothing
accumulates on it. Every project brings its own sealed environment.

> The honest summary: the container is not protecting the HTML file. It is
> protecting the VM, and protecting the next person who has to touch this.

---

## 3. Make the IP static

Check what you have now:

```bash
gcloud compute instances describe ukra-server \
  --zone=<YOUR_ZONE> \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)"

gcloud compute addresses list      # reserved (static) addresses only
```

If the VM's IP does **not** appear in `addresses list`, it is ephemeral and will
change. Promote the address you already have — this keeps the same number, so
nothing breaks:

```bash
gcloud compute addresses create ukra-server-ip \
  --addresses=<THE_IP_FROM_ABOVE> \
  --region=<YOUR_REGION>
```

In the Console instead: **VPC network → IP addresses**, find the row, change
Type from *Ephemeral* to *Static*.

Note that a reserved IP is billed while it is **not** attached to a running VM,
so release it if the server is ever retired.

---

## 4. Install Docker on the VM

SSH in, then:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
```

Log out and back in (the group change needs a fresh session), then verify:

```bash
docker version     # a Server section must appear
```

---

## 5. Get the image onto the server

Three ways. Pick one — A to start, B once this is a real deployment.

### Option A — build on the server (simplest)

```bash
git clone <your-repo-url> krishi-roadmap
cd krishi-roadmap
docker build -t krishi-roadmap:v1 .
docker run -d --name krishi -p 80:8080 --restart unless-stopped krishi-roadmap:v1
```

Fine for one small server. The downside: the server needs the source code and a
build toolchain, and "what is running" depends on which commit was checked out.

### Option B — push to Artifact Registry, pull on the server (proper)

This is what a reviewer means by "deploy it as a docker image": the artifact is
built **once**, stored, versioned, and the server only *pulls* it. The server
never sees source code.

> Use **Artifact Registry**, not Container Registry — `gcr.io` was shut down in
> March 2025.

One-time setup, from your laptop:

```bash
gcloud artifacts repositories create ukra \
  --repository-format=docker \
  --location=asia-south1          # pick the region nearest the VM

gcloud auth configure-docker asia-south1-docker.pkg.dev
```

Each release:

```bash
docker build -t krishi-roadmap:v1 .
docker tag krishi-roadmap:v1 \
  asia-south1-docker.pkg.dev/<PROJECT_ID>/ukra/krishi-roadmap:v1
docker push asia-south1-docker.pkg.dev/<PROJECT_ID>/ukra/krishi-roadmap:v1
```

On the VM:

```bash
gcloud auth configure-docker asia-south1-docker.pkg.dev
docker pull asia-south1-docker.pkg.dev/<PROJECT_ID>/ukra/krishi-roadmap:v1
docker run -d --name krishi -p 80:8080 --restart unless-stopped \
  asia-south1-docker.pkg.dev/<PROJECT_ID>/ukra/krishi-roadmap:v1
```

The VM's service account needs the **Artifact Registry Reader** role, or the
pull will fail with a permissions error.

**Tag real versions — `v1`, `v2` — not just `latest`.** `latest` means nobody
can tell what is actually running, and rollback becomes guesswork. With real
tags, rolling back is: stop the container, run the previous tag.

### Option C — no registry (offline handoff)

```bash
# laptop
docker save krishi-roadmap:v1 | gzip > krishi.tar.gz
scp krishi.tar.gz upload@<SERVER_IP>:~

# server
docker load < krishi.tar.gz
docker run -d --name krishi -p 80:8080 --restart unless-stopped krishi-roadmap:v1
```

---

## 6. Ports and firewall

`-p 80:8080` means: the world connects to port **80** on the VM, Docker forwards
to port **8080** inside the container (where nginx listens as a non-root user).

Google Cloud blocks port 80 unless you allow it. Easiest is the Console:
**VM instances → edit `ukra-server` → tick "Allow HTTP traffic"**. Or:

```bash
gcloud compute firewall-rules create allow-http \
  --allow=tcp:80 --target-tags=http-server
gcloud compute instances add-tags ukra-server \
  --tags=http-server --zone=<YOUR_ZONE>
```

**If `docker run` fails with "port is already allocated"**, a web server
installed by hand is already holding port 80 — see section 7.

`--restart unless-stopped` matters: without it, the site does not come back
after a VM reboot.

---

## 7. Clean up the manual deployment

If a web server was installed on the VM directly, remove it — otherwise it
fights the container for port 80 and the contamination stays. Check first:

```bash
systemctl status nginx        # or apache2
```

If it is running:

```bash
sudo systemctl stop nginx
sudo systemctl disable nginx
sudo apt-get purge -y nginx nginx-common
sudo apt-get autoremove -y
```

Also delete whatever files were copied by hand, typically under
`/var/www/html`. From here on, the container is the only thing serving the site,
and the VM stays clean.

---

## 8. Updating the site later

The container is a snapshot. Editing files on the server does nothing — that is
the point. To publish a change:

```bash
# build and push v2 from your laptop, then on the server:
docker pull <image>:v2
docker stop krishi && docker rm krishi
docker run -d --name krishi -p 80:8080 --restart unless-stopped <image>:v2
```

Downtime is about a second. To roll back, run the same commands with `:v1`.

---

## 9. Worth doing next

- **HTTPS.** A government-facing page should not be plain HTTP. The least
  painful route is putting [Caddy](https://caddyserver.com) in front — it
  obtains and renews Let's Encrypt certificates automatically. Needs a domain
  name pointed at the static IP.
- **A domain name** instead of a bare IP.
- **Automated deploys** — a GitHub Action that builds, pushes, and restarts on
  every commit to `main`, so deployment stops being a manual SSH session
  entirely.

---

## 10. Short answer for the review

> The site now ships as a Docker image — `Dockerfile` and `nginx.conf` are in
> the repo, so the server build is reproducible and nothing is installed on the
> VM except Docker itself. Images are tagged by version in Artifact Registry and
> pulled on the server, so rollback is one command. The manual copy under
> `/var/www` and the hand-installed nginx have been removed. The external IP is
> now reserved as static. Still open: HTTPS and a domain name.

Do not send that until each line is actually true — sections 3, 5, and 7 are the
ones to complete first.
