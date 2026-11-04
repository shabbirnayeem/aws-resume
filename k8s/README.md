# Kubernetes on the Raspberry Pi

The site runs on a single-node [k3s](https://k3s.io) cluster on a Raspberry Pi 5. Deploys run on ephemeral
GitHub Actions runners inside the same cluster, managed by
[Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller).

```
                    ┌──────────────────────── k3s on Raspberry Pi ─────────────────────────┐
                    │                                                                       │
Browser ─► Cloudflare ◄── outbound tunnel ── cloudflared ──► Service ──► portfolio-web pod  │
                    │                        (portfolio)    portfolio-web  (Flask, gunicorn) │
                    │                                                          ▲            │
GitHub Actions ◄─── listener ── controller ──creates──► runner pod ── kubectl ─┘            │
 (job queued)       │ (arc-systems)                     (arc-runners, one per job)          │
                    └───────────────────────────────────────────────────────────────────────┘
```

## Layout

| Path | What it is |
|---|---|
| [portfolio/deployment.yaml](portfolio/deployment.yaml) | The site's Deployment (with readiness and liveness probes on `/healthz`) and its ClusterIP Service |
| [portfolio/cloudflared.yaml](portfolio/cloudflared.yaml) | The Cloudflare Tunnel connector, running as a pod |
| [arc/rbac.yaml](arc/rbac.yaml) | The runner's ServiceAccount, and the Role that limits what it can do |
| [arc/values.yaml](arc/values.yaml) | Helm values for the runner scale set `pi-k3s` |

## Namespaces

| Namespace | Runs | Trust |
|---|---|---|
| `portfolio` | The site and cloudflared | Production workload |
| `arc-systems` | The ARC controller and the listener | High: installed software that can create pods |
| `arc-runners` | Runner pods, one per job | Low: runs whatever code a workflow contains |

The controller and the runners are in separate namespaces because they have very different levels of trust.
RBAC, Pod Security and resource quotas can then be applied to the runners without affecting the controller.

## How a deploy works

The `deploy` job in [docker-image-ci.yml](../.github/workflows/docker-image-ci.yml) runs after the
multi-arch image has been built and pushed to Docker Hub:

1. The job waits for manual approval (the `production` environment).
2. The ARC listener sees the queued job, and the controller creates a runner pod in `arc-runners`. The scale
   set has `minRunners: 0`, so no runner exists until a job needs one.
3. The runner sets the new image tag on the Deployment with `kubectl set image`.
4. The Deployment does a rolling update. The new pod gets traffic only after its readiness probe passes, so the
   old pod keeps serving the site until then.
5. `kubectl rollout status` waits up to two minutes. If the rollout doesn't finish, the job runs
   `kubectl rollout undo` and fails.
6. The runner pod is deleted when the job ends.

`kubectl` inside the runner pod has no kubeconfig. It authenticates with the pod's ServiceAccount token
(`portfolio-deployer`).

## Security model

- **Ephemeral runners:** every job gets a fresh pod that is deleted afterwards. A compromised job can't leave
  anything behind for the next one. The pods aren't privileged and don't mount host paths.
- **Least privilege:** `portfolio-deployer` can only read and update Deployments in `portfolio`, and read their
  ReplicaSets and Pods. It can't delete anything, read Secrets, or touch any other namespace. To check this:

  ```bash
  SA=system:serviceaccount:arc-runners:portfolio-deployer
  kubectl auth can-i patch deployments  -n portfolio   --as=$SA   # yes
  kubectl auth can-i get secrets        -n portfolio   --as=$SA   # no
  kubectl auth can-i delete deployments -n portfolio   --as=$SA   # no
  kubectl auth can-i patch deployments  -n kube-system --as=$SA   # no
  ```

- **GitHub App, not a personal token:** ARC signs requests with the App's private key and gets installation
  tokens that expire after an hour. The App is installed on this repo only, with Administration (read and
  write) permission so that it can register runners.
- **Public repo:** pull requests never reach the cluster. The deploy job is skipped for `pull_request` events,
  and fork pull requests need approval before their workflows run.
- **No inbound ports:** cloudflared only makes outbound connections, so nothing on the Pi is exposed to the home
  network or the internet.

## One-time setup

These are the steps used to build the cluster, run on the Pi.

### 1. Install k3s and Helm

```bash
# Kubernetes needs the memory cgroup, and pod networking needs vxlan
grep -w memory /sys/fs/cgroup/cgroup.controllers
sudo modprobe vxlan

# Traefik and servicelb are disabled: Cloudflare Tunnel handles ingress, and nothing is exposed on the LAN
curl -sfL https://get.k3s.io | sh -s - --disable traefik --disable servicelb

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER": ~/.kube/config && chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 2. Deploy the site and the tunnel

```bash
kubectl create namespace portfolio

# The Docker Hub repo is private. Use a read-only access token.
kubectl -n portfolio create secret docker-registry dockerhub \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<dockerhub-user> --docker-password=<read-only-token>

# The tunnel token is under Zero Trust → Networks → Tunnels → Configure.
# read -s keeps it off the screen and out of shell history.
read -rsp 'Tunnel token: ' TOKEN; echo
kubectl -n portfolio create secret generic cloudflared-token --from-literal=token="$TOKEN"
unset TOKEN

kubectl apply -f k8s/portfolio/
```

In the Cloudflare dashboard, the public hostname's Service is `http://portfolio-web:9123`. cloudflared runs in
the same namespace, so it resolves the Service by name.

### 3. Create the GitHub App

1. **GitHub → Settings → Developer settings → GitHub Apps → New GitHub App.** Turn off the webhook, and give it
   **Repository → Administration: Read and write**.
2. Note the numeric **App ID** from the General page. (ARC 0.15.1 needs the App ID, not the Client ID.)
3. Under **Credentials → Key pairs**, create a key. A `.pem` file downloads.
4. Under **Install App**, install it on this repository only. The number at the end of the resulting URL
   (`/settings/installations/<number>`) is the **installation ID**.

```bash
kubectl create namespace arc-runners
kubectl -n arc-runners create secret generic github-app \
  --from-literal=github_app_id=<APP_ID> \
  --from-literal=github_app_installation_id=<INSTALLATION_ID> \
  --from-file=github_app_private_key=$HOME/<key>.pem
shred -u ~/<key>.pem
```

### 4. Install ARC

The controller and the scale set charts must use the same version.

```bash
ARC_VERSION=0.15.1

helm install arc --namespace arc-systems --create-namespace --version $ARC_VERSION \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

kubectl apply -f k8s/arc/rbac.yaml

# The release name becomes the runs-on label
helm install pi-k3s --namespace arc-runners --version $ARC_VERSION -f k8s/arc/values.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

A `pi-k3s-…-listener` pod appears in `arc-systems`, and `pi-k3s` shows up under
**Settings → Actions → Runners**. [arc-test.yml](../.github/workflows/arc-test.yml) runs `hostname` on a
runner. The output is the runner pod's name.

## Day-to-day commands

```bash
kubectl -n portfolio get pods                                   # is the site up?
kubectl -n portfolio logs -f deploy/portfolio-web               # requests as they arrive
kubectl -n portfolio get deploy portfolio-web \
  -o jsonpath='{.spec.template.spec.containers[0].image}'; echo # which tag is live
kubectl -n portfolio rollout history deploy/portfolio-web       # past revisions
kubectl -n portfolio rollout undo deploy/portfolio-web          # manual rollback
kubectl -n arc-runners get pods -w                              # watch runners come and go
kubectl -n arc-systems logs deploy/arc-gha-rs-controller        # if runners don't start
```

## Trade-offs and known limitations

- **The image tag in Git drifts from the cluster.** CI updates the live Deployment with `kubectl set image` but
  doesn't commit the new tag, so `deployment.yaml` still names an older image. **Running
  `kubectl apply -f k8s/portfolio/` rolls the site back to that tag.** Check the live tag first, and update the
  file if needed. The usual fix is GitOps: CI commits the tag, and Argo CD or Flux syncs it, so the runner
  needs no cluster access at all.
- **`kubectl apply` doesn't delete.** Removing or renaming a resource in a file leaves the old one running in the
  cluster until it's deleted by hand. A GitOps tool with pruning would handle this.
- **One node, one replica.** A Pi reboot takes the site down. Rolling updates have no downtime, but there's no
  redundancy against hardware failure.
- **Secrets are created by hand** and stored as Kubernetes Secrets, which are base64-encoded, not encrypted.
  On a shared or production cluster they'd come from a vault, through something like External Secrets Operator.
- **The runner image uses `:latest`** on purpose. GitHub stops accepting runners that are too far out of date.
  Elsewhere, pinning the version and letting Renovate or Dependabot bump it would be better.

## Problems hit while building this

| Symptom | Cause |
|---|---|
| cloudflared: `Provided Tunnel token is not valid` | The Secret held more than the token (the token alone starts with `eyJ`). Decode it with `kubectl get secret … -o jsonpath='{.data.token}' \| base64 -d` |
| Site returned 502 Bad Gateway after cutover | The Service had been renamed in the file but not re-applied, so `portfolio-web` didn't exist in the cluster |
| No listener pod; controller log shows `strconv.ParseInt` | The GitHub App's Client ID was used as the installation ID. Both the App ID and the installation ID must be numbers |

## Scaling this to an organization

The same setup works at organization level, with these changes:

- Set `githubConfigUrl` to `https://github.com/<org>`.
- Give the GitHub App **Organization → Self-hosted runners: Read and write**. Enterprise-level scale sets need a
  classic personal access token instead.
- Use **runner groups** to limit which repos can send jobs to each scale set.
- For more than one target namespace, write the rules once as a ClusterRole and bind it with a **RoleBinding in
  each namespace**. A ClusterRoleBinding would grant the same rights in every namespace, including `kube-system`.
