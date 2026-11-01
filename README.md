# Portfolio site

[![Test, Build and Deploy](https://github.com/shabbirnayeem/aws-resume/actions/workflows/docker-image-ci.yml/badge.svg)](https://github.com/shabbirnayeem/aws-resume/actions/workflows/docker-image-ci.yml)

My DevOps / platform engineering portfolio. The site itself is a small hybrid-infrastructure project: a Flask
container self-hosted on a Raspberry Pi behind a Cloudflare Tunnel, plus a serverless visitor counter on AWS.

## Architecture

```
Browser ──► Cloudflare (DNS + TLS) ──► Cloudflare Tunnel ──► Raspberry Pi: Flask + gunicorn container
Browser ──► API Gateway ──► Lambda (Python) ──► DynamoDB          (visitor counter, Terraform-managed)

git push ──► GitHub Actions: tests ──► multi-arch image (amd64/arm64) ──► Docker Hub
                                                      └──► self-hosted runner on the Pi: deploy + health check + rollback
```

- **No open ports at home.** The Pi connects outbound to Cloudflare, and the container listens only on `127.0.0.1`.
- **Automated deploys with rollback.** Every push to `main` is tested, built, tagged with its commit SHA and rolled
  out by [deploy/deploy.sh](deploy/deploy.sh). If `/healthz` doesn't come up, the previous image is restored.
- **Cost.** The site started on ECS Fargate behind an ALB (about $50 a month). Moving it to a Pi brought hosting to
  near zero. The original Fargate Terraform is still in [terraform/](terraform/) for reference.

## Repository layout

| Path | What it is |
|---|---|
| [app/](app/) | Flask app: `app.py`, the page template, and static CSS/JS/images |
| [Dockerfile](Dockerfile) | Python 3.12 image running gunicorn as a non-root user, with a health check |
| [deploy/](deploy/) | Compose file, deploy/rollback script, and the [runner setup guide](deploy/README.md) |
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

Page design and code are my own. The site originally used the
[CeeVee template by StyleShout](https://styleshout.com/free-templates/ceevee/).
