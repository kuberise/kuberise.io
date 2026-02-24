---
name: check-upgrades
description: Check for newer versions of external Helm charts referenced in the platform
---

# Check Helm Chart Upgrades

Run the upgrade check script and summarize results.

## Steps

1. Run the upgrade check script:
   ```bash
   ./scripts/upgrade.sh
   ```

2. Parse the output and present a summary table showing:
   - Component name
   - Current version (from `app-of-apps/values-base.yaml`)
   - Latest available version
   - Whether it's a major, minor, or patch update

3. For any components with available upgrades, note:
   - Major version bumps may have breaking changes - flag these prominently
   - Link to the chart's changelog if available (usually in the chart's GitHub repo)

4. If the user wants to upgrade specific components, update the `targetRevision` field in `app-of-apps/values-base.yaml`.

## Important

- Do NOT automatically upgrade anything without user confirmation
- Major version bumps should be investigated for breaking changes before upgrading
- After upgrading, remind the user to test on a dev cluster before committing
