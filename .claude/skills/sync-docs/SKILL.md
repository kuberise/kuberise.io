---
name: sync-docs
description: Check consistency between public docs in the platform repo and the website repo
---

# Sync Docs Check

Check that public docs in `docs/public/` are consistent with their copies in the website repo. Public docs should only be edited in the platform repo - the website fetches them at build time.

## Steps

### 1. List docs in both locations

Source of truth:
```
docs/public/
```

Website copy (populated at build time, should NOT be manually edited):
```
../https.kuberise.io/content/1.docs/
```

### 2. Compare files

For each file in `docs/public/`:
- Check if a corresponding file exists in the website content directory
- Compare content to detect manual edits in the website repo that should have been made in the platform repo

### 3. Check for orphaned files

Look for files in `../https.kuberise.io/content/1.docs/` that don't have a corresponding source in `docs/public/`. These may be:
- Manually added docs that should be moved to the platform repo
- Leftover files from renamed/deleted docs

### 4. Report findings

Present a summary:
- Files in sync (no action needed)
- Files with differences (show the diff, recommend which version to keep)
- Orphaned files in either location
- Reminder: always edit public docs in `docs/public/`, never directly in the website repo

## Important

- The website's `scripts/build.sh` fetches docs from the platform repo at build time
- The `.github/workflows/trigger-website.yml` triggers a Cloudflare Pages rebuild when `docs/public/**` changes on main
- Files in `../https.kuberise.io/docs/` (root level) are internal developer docs for website contributors - ignore these
