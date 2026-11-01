# Deploying to the Raspberry Pi

Every push to `main` builds a multi-arch image on GitHub-hosted runners, tags it `latest` and `sha-<commit>`,
and pushes it to Docker Hub. A self-hosted runner on the Pi then runs [deploy.sh](deploy.sh), which:

1. records the image tag that is currently running,
2. pulls and starts the new tag with [docker-compose.yml](docker-compose.yml),
3. polls `http://127.0.0.1:9123/healthz` for up to 30 seconds,
4. rolls back to the previous tag if the new one never becomes healthy.

Cloudflare Tunnel runs as the `cloudflare-tunnel` container and reaches the site at `http://portfolio-web:9123`
over a shared Docker network named `tunnel`. The site's host port is bound to `127.0.0.1` only, for the health
check, so it isn't reachable from the rest of the home network.

## One-time setup on the Pi

### 1. Create a dedicated runner user

```bash
sudo useradd -m -s /bin/bash gh-runner
sudo usermod -aG docker gh-runner
```

Being in the `docker` group is effectively root on the Pi. That's why the protections in step 4 matter.

### 2. Install and register the runner

The Pi needs the **ARM64** runner build. The GitHub page defaults to x64, which fails with
`Exec format error`. First, check that the OS is 64-bit:

```bash
dpkg --print-architecture   # must print arm64 (armhf means 32-bit Raspberry Pi OS)
```

Download the latest ARM64 runner as `gh-runner`:

```bash
sudo -iu gh-runner
mkdir actions-runner && cd actions-runner
VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep -oP '"tag_name": "v\K[^"]+')
curl -L -o runner.tar.gz \
   "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-arm64-${VERSION}.tar.gz"
tar xzf runner.tar.gz
file bin/Runner.Listener    # should say ARM aarch64
```

Then get a registration token from **Settings → Actions → Runners → New self-hosted runner** (tokens expire after
an hour) and register the runner with the `pi` label:

```bash
./config.sh --url https://github.com/shabbirnayeem/aws-resume --token <TOKEN> \
   --name pi5 --labels pi --unattended
exit
```

### 3. Run it as a service

Run this from your normal sudo-capable user, not `gh-runner`. Ubuntu locks home folders against other users,
so the whole command runs under `sudo` instead of using `cd` first:

```bash
sudo bash -c 'cd /home/gh-runner/actions-runner && ./svc.sh install gh-runner && ./svc.sh start && ./svc.sh status'
```

Look for `active (running)`. Runner logs: `journalctl -u 'actions.runner.*' -f`.

The runner should now show as **Idle** under Settings → Actions → Runners.

### 4. Lock it down (this repo is public)

A public repo with a self-hosted runner lets anyone who opens a pull request try to run code on the Pi.
To prevent that:

- **Settings → Actions → General → Fork pull request workflows from outside collaborators:** choose
  **Require approval for all external contributors**.
- Only `deploy` targets the runner (`runs-on: [self-hosted, pi]`), and the workflow only triggers on pushes
  to `main` and manual runs. Keep any `pull_request` workflows on GitHub-hosted runners.
- Optionally, add a required reviewer under **Settings → Environments → production**, so every deploy waits
  for your approval.

### 5. Hand over from the manual setup

Stop the container you started by hand, so that the compose project in this repo owns port 9123:

```bash
cd <your old compose directory> && docker compose down
```

Then trigger the workflow from the **Actions** tab (**Run workflow**) or push to `main`.

### 6. Point the tunnel at the new container

Put the cloudflared container on the shared network (`deploy.sh` creates the network if it doesn't exist):

```bash
docker network inspect tunnel >/dev/null 2>&1 || docker network create tunnel
docker network connect tunnel cloudflare-tunnel
```

Then, in the Cloudflare dashboard (**Zero Trust → Networks → Tunnels → your tunnel → Public Hostname**), change
the hostname's **Service** to `http://portfolio-web:9123`.

The network connection survives restarts of the cloudflared container, but not re-creating it. If you ever
re-create it, add `--network tunnel` to its `docker run` command (or `networks: [tunnel]` in its compose file).

## Manual deploy or rollback

You can run the same script by hand on the Pi:

```bash
IMAGE=<dockerhub-user>/portfolio-app IMAGE_TAG=sha-abc1234 ./deploy/deploy.sh
```
