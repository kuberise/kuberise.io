---
name: release
description: Guide through creating a new kuberise.io release with release notes, changelog, and version badge
---

# Create a New Release

Guide the user through the full release process for kuberise.io. This touches both the platform repo and the website repo.

## 1. Determine version

Ask the user for the new version number. Follow the format `X.Y.Z` (no 'v' prefix). Check the current version in `RELEASE_NOTES.md` to suggest the next logical version.

## 2. Update RELEASE_NOTES.md

In `RELEASE_NOTES.md`:
- If there's a DRAFT section, update it with the version number and today's date
- If no DRAFT, create a new section at the top
- Follow the existing format: title with version and date, summary paragraph, then Added/Changed/Removed/Fixed sections as needed
- Never use em dash - use hyphen or rephrase

## 3. Create website changelog entry

Create a new file in the website repo at:
`../https.kuberise.io/content/4.changelog/{N}.{major}-{minor}-{patch}.md`

Where `{N}` is the next sequential number after existing entries. Check existing files to determine the next number.

Frontmatter format:
```yaml
---
title: "{X.Y.Z} - {Short Title}"
description: "{One-sentence summary}"
date: "{YYYY-MM-DD}"
image: {unsplash URL or local image path}
---
```

Body content should be adapted from `RELEASE_NOTES.md` - convert the changelog format to prose-friendly Markdown suitable for the website. Use **bold** for section headers like `**Added:**`, `**Changed:**`, etc.

## 4. Update version badge

Update the `version` field in `../https.kuberise.io/app/app.config.ts`:
```typescript
export default defineAppConfig({
  version: '{X.Y.Z}',
  ...
})
```

## 5. Create git tag

Remind the user to create a git tag (no 'v' prefix):
```bash
git tag {X.Y.Z}
```

## 6. Summary checklist

Present a checklist of everything that was done:
- [ ] `RELEASE_NOTES.md` updated with new version
- [ ] Changelog entry created in website repo
- [ ] Version badge updated in `app.config.ts`
- [ ] Git tag created
