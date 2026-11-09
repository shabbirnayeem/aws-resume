# Portfolio site

[![Test, Build and Deploy](https://github.com/shabbirnayeem/aws-resume/actions/workflows/docker-image-ci.yml/badge.svg)](https://github.com/shabbirnayeem/aws-resume/actions/workflows/docker-image-ci.yml)

My DevOps / platform engineering portfolio. The site itself is a small hybrid-infrastructure project: a Flask
container self-hosted on a Raspberry Pi behind a Cloudflare Tunnel, plus a serverless visitor counter on AWS.

## Architecture

```
Browser ──► Cloudflare (DNS + TLS + Tunnel) ──► cloudflared ──► portfolio-web Service ──► Flask + gunicorn pod
                                                                   (k3s on a Raspberry Pi 5, Flux-managed)
Browser ──► API Gateway ──► Lambda (Python) ──► DynamoDB          (visitor counter, Terraform-managed)

git push ──► GitHub Actions (ubuntu-latest): tests ──► multi-arch image (amd64/arm64), tagged sha-<hash>-<run>
                                                              │
                                                              ▼
                                                         Docker Hub
                                                              │
                                                              ▼
                                      Flux image automation (in the homelab repo) notices the new tag,
                                      commits it to Git, and the cluster reconciles — no kubectl, no
                                      cluster credentials in CI.
```

- **No open ports at home.** The Pi only makes outbound connections to Cloudflare; nothing is exposed to the
  home network or the internet.
- **GitOps deploys, no manual `kubectl`.** A push that changes app code is tested, built, and pushed to Docker
  Hub with a sortable tag. [Flux](https://fluxcd.io), running from the separate
  [`homelab`](https://github.com/shabbirnayeem/homelab) repo, picks up the new tag and commits it to Git;
  Kubernetes's own rolling update and readiness probes keep the old pod serving traffic until the new one is
  healthy. The CI job that builds and pushes the image holds no Kubernetes credentials at all.
- **Self-hosted CI runner on the same cluster.** [Actions Runner Controller](https://github.com/actions/actions-runner-controller)
  runs ephemeral GitHub Actions runners on the same k3s cluster (also Flux-managed), as a learning mirror of a
  similar setup at work. Today only [arc-test.yml](.github/workflows/arc-test.yml) uses it as a smoke test —
  `test`/`build-and-push` still run on GitHub-hosted runners.
- **Cost.** The site started on ECS Fargate behind an ALB (about $50 a month). Moving it to a Pi brought hosting to
  near zero. The original Fargate Terraform is still in [terraform/](terraform/) for reference.

Cluster-side config (the Deployment, the Cloudflare Tunnel connector, ARC, and image automation) lives entirely
in the separate [`homelab`](https://github.com/shabbirnayeem/homelab) repo, not here — see its README for the
full architecture and diagrams.

## Repository layout

| Path | What it is |
|---|---|
| [app/](app/) | Flask app: `app.py`, the page template, and static CSS/JS/images |
| [Dockerfile](Dockerfile) | Python 3.12 image running gunicorn as a non-root user, with a health check |
| [deploy/](deploy/) | **Not used.** Old systemd-runner + docker-compose deploy flow, superseded by Flux GitOps in `homelab`; kept for reference |
| [terraform/](terraform/) | Visitor counter (API Gateway, Lambda, DynamoDB, IAM) and the legacy ECS/ALB setup |
| [tests/](tests/) | pytest tests for the Flask app and the Lambda |
| [.github/workflows/](.github/workflows/) | CI/CD: test on every push and PR; build and deploy from `main` |

## Run it locally

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

# Dev server with auto-reload on http://localhost:9123
cd app && FLASK_DEBUG=1 python app.py

# Tests (from the repo root)
pytest
```

Or run the production container:

```bash
docker build -t portfolio-app .
docker run --rm -p 9123:9123 portfolio-app
```

The visitor counter shows "n/a" locally, because the API only allows browser requests from the live domain.

## Visitor counter

The Lambda increments the count with DynamoDB's atomic `ADD`, so concurrent visits are never lost, and returns
`{"count": N}`. Changes deploy with `terraform apply` in [terraform/](terraform/), which repackages the function
automatically.

## Credits

The design and code have been built out independently over time, starting from the
[CeeVee template by StyleShout](https://styleshout.com/free-templates/ceevee/) as an early reference point.
