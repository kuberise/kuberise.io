---
name: release
description: Guide through creating a new kuberise.io release with release notes, changelog, version badge, GitHub release, and LinkedIn post
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

## 5. Update `KR_VERSION` in the kr script

Update the `KR_VERSION` variable at the top of `../kuberise.io/scripts/kr`:
```bash
KR_VERSION="{X.Y.Z}"
```

This version is displayed by `kr version` and must match the release.

## 6. Create git tag and GitHub release

Remind the user to create a git tag (no 'v' prefix) and a GitHub release:
```bash
git tag {X.Y.Z}
git push origin {X.Y.Z}
```

Then create a GitHub release from the tag. This is required for the `kr` installer (`install-kr.sh`) to download the correct version. The release should attach the `scripts/kr` script as a release asset:
```bash
gh release create {X.Y.Z} --title "{X.Y.Z}" --notes "See RELEASE_NOTES.md for details" scripts/kr
```

## 7. Draft a LinkedIn post

Draft a LinkedIn post for the kuberise company page announcing the new release. The post should:
- Start with a hook line about the key feature
- Summarize the 2-3 most impactful changes in plain language (not too technical)
- Include relevant hashtags (#kubernetes #devops #platform #opensource #gitops)
- Keep it concise (under 200 words)
- End with a call to action (link to changelog or GitHub)

Present the draft to the user for review before posting. Do not post it automatically.

## 8. Summary checklist

Present a checklist of everything that was done:
- [ ] `RELEASE_NOTES.md` updated with new version
- [ ] Changelog entry created in website repo
- [ ] Version badge updated in `app.config.ts`
- [ ] `KR_VERSION` updated in `scripts/kr`
- [ ] Git tag created and pushed
- [ ] GitHub release created with `kr` script attached
- [ ] LinkedIn post drafted
