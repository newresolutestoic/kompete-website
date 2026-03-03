# Kompete.ai Website

Marketing website for [Kompete.ai](https://kompete.ai) — domain hosted on GoDaddy.

## Structure

```
site/                # Live website source
  index.html
  css/
  js/
  assets/

snapshots/           # Dated website backups
  2026-03-03/        # Each folder = full copy of site/ at that date
  ...

scripts/
  snapshot.sh        # Creates a dated snapshot of the current site

research/            # Git submodule → kompete-research repo
  interviews/
  synthesis/
```

## Workflow

### Publishing a new version
1. Make changes in `site/`
2. Run `./scripts/snapshot.sh` to create a dated backup before deploying
3. Deploy `site/` to GoDaddy
4. Commit and push

### Creating a snapshot
```bash
./scripts/snapshot.sh
# Creates snapshots/YYYY-MM-DD/ with a copy of site/
# If same-day snapshot exists, appends a version number
```

### Accessing research
Research (customer interviews, pain points) lives in the `research/` submodule.
```bash
git submodule update --init --recursive   # First time
git submodule update --remote research    # Pull latest
```

## Deployment
Domain: kompete.ai (GoDaddy)
Deploy method: [TBD — manual upload, GitHub Pages, or CI/CD]
