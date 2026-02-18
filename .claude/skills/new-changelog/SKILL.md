---
name: new-changelog
description: Create a changelog entry for the kuberise.io website from RELEASE_NOTES.md
---

# New Changelog Entry

Create a new changelog entry in the website repo based on the release notes.

## 1. Read the latest release from RELEASE_NOTES.md

Read `RELEASE_NOTES.md` and identify the version to create a changelog for. If the user doesn't specify, use the latest non-DRAFT version. If a DRAFT version exists, ask if they want to use it.

## 2. Determine file number

Check existing changelog entries in `../https.kuberise.io/content/4.changelog/` to find the next sequential number. Current pattern: `{N}.{major}-{minor}-{patch}.md`.

## 3. Create the changelog file

Create `../https.kuberise.io/content/4.changelog/{N}.{major}-{minor}-{patch}.md`.

Frontmatter format (all fields required by the `versions` collection schema):
```yaml
---
title: "{X.Y.Z} - {Short Title from RELEASE_NOTES}"
description: "{One-sentence summary from the release notes}"
date: "{YYYY-MM-DD}"
image: {unsplash image URL}
---
```

For the image, use a relevant Unsplash URL with `auto=format&fit=crop&w=800&q=80` parameters. Choose images related to the release theme (e.g., CLI tools, deployment, configuration).

## 4. Write the body

Convert the `RELEASE_NOTES.md` content to website-friendly Markdown:
- Start with a summary paragraph
- Use `**Added:**`, `**Changed:**`, `**Removed:**` etc. as bold text (not heading level)
- Keep the same content but format it for web readability
- Use backticks for code references

## 5. Update version badge

Also update the `version` field in `../https.kuberise.io/app/app.config.ts` to the new version number.

## 6. Verify

- Confirm the changelog file number is sequential
- Confirm the frontmatter matches the schema (title, description, date, image - all required)
- Confirm `app.config.ts` version is updated
