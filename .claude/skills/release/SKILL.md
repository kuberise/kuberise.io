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

## 6. Generate release PR title and description

Generate a PR title and body for the release branch. This is the main PR that merges all release changes into `main`.

**PR title format:**
```
Release {X.Y.Z}: {Short Title from RELEASE_NOTES}
```

**PR body format:**
```markdown
## Release {X.Y.Z} - {Short Title}

{One-sentence summary from RELEASE_NOTES}

### Changes in this PR
- Updated `RELEASE_NOTES.md` with version {X.Y.Z}
- Created changelog entry `{N}.{major}-{minor}-{patch}.md`
- Updated version badge in `app.config.ts` to {X.Y.Z}
- Updated `KR_VERSION` in `scripts/kr` to {X.Y.Z}

### Release notes

{Copy the Added/Changed/Removed sections from RELEASE_NOTES.md}
```

Present the PR title and body to the user so they can use it when creating the PR.

## 7. Generate git tag message

Generate an annotated tag message for the release. The tag should be annotated (not lightweight) so it includes metadata.

**Tag command:**
```bash
git tag -a {X.Y.Z} -m "{Tag message}"
```

**Tag message format:**
```
Release {X.Y.Z}: {Short Title}

{2-3 sentence summary of the most important changes, derived from RELEASE_NOTES.md}
```

Present the full `git tag` command to the user.

## 8. Create GitHub release

Remind the user to push the tag and create a GitHub release.

**IMPORTANT: The `scripts/kr` file MUST be attached as a release asset.** Without it, the installer (`curl -sSL https://kuberise.io/install | sh`) will fail with a 404 error because it downloads `kr` from `https://github.com/kuberise/kuberise.io/releases/download/{X.Y.Z}/kr`.

```bash
git push origin {X.Y.Z}
gh release create {X.Y.Z} --title "{X.Y.Z} - {Short Title}" --notes-file <(sed -n '/## \[{X.Y.Z}\]/,/## \[/p' RELEASE_NOTES.md | head -n -1) scripts/kr
```

If the `sed` approach is too complex, generate the release notes content and present a simpler `gh release create` command with `--notes` inline.

If the release already exists but is missing the asset, use:
```bash
gh release upload {X.Y.Z} scripts/kr
```

After creating the release, verify the installer works:
```bash
curl -sSL https://kuberise.io/install | sh
```

## 9. Draft a LinkedIn post

Draft a LinkedIn post for the kuberise company page announcing the new release. The post should:
- Start with a hook line about the key feature
- Summarize the 2-3 most impactful changes in plain language (not too technical)
- Include relevant hashtags (#kubernetes #devops #platform #opensource #gitops)
- Keep it concise (under 200 words)
- End with a call to action (link to changelog or GitHub)

Present the draft to the user for review before posting. Do not post it automatically.

## 10. Summary checklist

Present a checklist of everything that was done:
- [ ] `RELEASE_NOTES.md` updated with new version
- [ ] Changelog entry created in website repo
- [ ] Version badge updated in `app.config.ts`
- [ ] `KR_VERSION` updated in `scripts/kr`
- [ ] Release PR title and description generated
- [ ] Annotated git tag message generated
- [ ] GitHub release created with `kr` script attached
- [ ] LinkedIn post drafted
