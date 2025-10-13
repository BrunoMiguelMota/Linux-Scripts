# Complete Setup Instructions for WarpNETDNS Automated Release System

## Overview

This system automatically builds WarpNETDNS (a rebranded AdGuard Home) and publishes releases to:
- **https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/**

Users can then download binaries from:
- **https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_amd64.tar.gz**

## Required Actions

### 1. Create the warpnetdns Repository (One-time Setup)

#### Option A: Manual Creation
1. Go to: https://github.com/new
2. Fill in:
   - Owner: `BrunoMiguelMota`
   - Repository name: `warpnetdns`
   - Description: `Warp NET DNS - Custom branded AdGuard Home`
   - Visibility: **Public** (required for public downloads)
   - ✓ Add a README file
3. Click "Create repository"

#### Option B: Using the Helper Script
```bash
cd /home/runner/work/Linux-Scripts/Linux-Scripts
./setup_warpnetdns_repo.sh
# Follow the prompts
```

### 2. Create GitHub Personal Access Token (One-time Setup)

1. Go to: https://github.com/settings/tokens/new

2. Configure token:
   - **Note**: `WarpNETDNS Release Automation`
   - **Expiration**: 90 days (or "No expiration" if you prefer)
   - **Select scopes**:
     - ✅ `repo` (Full control of private repositories)
       - This includes: `repo:status`, `repo_deployment`, `public_repo`, `repo:invite`

3. Click "Generate token"

4. **CRITICAL**: Copy the token immediately! Format: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### 3. Add Token as Repository Secret (One-time Setup)

1. Go to: https://github.com/BrunoMiguelMota/Linux-Scripts/settings/secrets/actions

2. Click "New repository secret"

3. Configure secret:
   - **Name**: `WARPNETDNS_RELEASE_TOKEN`
   - **Secret**: Paste the token from step 2
   
4. Click "Add secret"

### 4. Merge This PR

Once you merge this PR to the `main` branch, the workflow will NOT run automatically on the first merge because the workflow file itself is being added. You need to trigger it manually.

### 5. Trigger the First Build

#### Manual Trigger (Recommended for first run)

1. After merging the PR, go to:
   https://github.com/BrunoMiguelMota/Linux-Scripts/actions

2. Click on "Build and Release WarpNETDNS" workflow

3. Click "Run workflow" button (top right)

4. Optional: Change AdGuard Home version (default is v0.107.52)

5. Click the green "Run workflow" button

6. Wait 15-20 minutes for completion

#### Automatic Trigger (Future runs)

After the first manual run, the workflow will automatically run whenever you:
- Push changes to `install_warpnetdns.sh`
- Push changes to `.github/workflows/build-warpnetdns.yml`
- On the `main` branch

### 6. Verify the Release

Once the workflow completes successfully:

1. Check the release page:
   https://github.com/BrunoMiguelMota/warpnetdns/releases

2. You should see a new release with 4 files:
   - `warpnetdns_linux_amd64.tar.gz`
   - `warpnetdns_linux_arm64.tar.gz`
   - `warpnetdns_linux_arm.tar.gz`
   - `warpnetdns_linux_armv7.tar.gz`

3. Test the download URL:
   ```bash
   wget https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_amd64.tar.gz
   ```

4. If successful, the URL from the install scripts will now work!

## Architecture

```
Linux-Scripts Repository (Build Source)
         |
         | [Push to main or manual trigger]
         v
    GitHub Actions
         |
         | [Builds for 4 architectures]
         |
         +---> Build amd64
         +---> Build arm64
         +---> Build arm
         +---> Build armv7
         |
         | [All builds complete]
         v
    Create Release Assets
         |
         v
warpnetdns Repository (Release Destination)
    /releases/latest/download/
         |
         +---> warpnetdns_linux_amd64.tar.gz
         +---> warpnetdns_linux_arm64.tar.gz
         +---> warpnetdns_linux_arm.tar.gz
         +---> warpnetdns_linux_armv7.tar.gz
```

## What Happens During Build

1. **Clone**: AdGuard Home source code is cloned
2. **Rebrand**: All references changed from "AdGuard Home" to "Warp NET DNS"
3. **Customize**: Logo and theme files are injected
4. **Build**: Go compilation for each architecture
5. **Package**: Binaries packaged into tar.gz files
6. **Upload**: Artifacts uploaded to GitHub
7. **Release**: New release created in warpnetdns repository
8. **Tag**: "latest" tag updated for easy access

## Testing the Installation

After releases are available, test the installation:

```bash
# Test the automated installer
curl -fsSL https://raw.githubusercontent.com/BrunoMiguelMota/Linux-Scripts/main/install_adguardhome_warpnet.sh | sudo bash -v

# Or test manual installation
wget https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_amd64.tar.gz
tar xzf warpnetdns_linux_amd64.tar.gz
sudo ./WarpNETDNS --version
```

## Troubleshooting

### "Resource not accessible by personal access token"
- Token doesn't have `repo` scope
- Token has expired
- Token was deleted
- Solution: Create new token with full `repo` scope

### "Release not found" or "404 Not Found"
- warpnetdns repository doesn't exist
- Repository is private (must be public)
- Workflow hasn't run yet
- Solution: Check repository exists and is public

### Workflow fails with "go: version not found"
- AdGuard Home version doesn't exist
- Version format is incorrect
- Solution: Use valid version like `v0.107.52`

### Builds succeed but release fails
- WARPNETDNS_RELEASE_TOKEN not set
- Token doesn't have access to warpnetdns repo
- Solution: Verify secret exists and token is valid

## Maintenance

### Update AdGuard Home Version

To build from a newer AdGuard Home version:

1. Go to Actions tab
2. Select "Build and Release WarpNETDNS"
3. Click "Run workflow"
4. Enter new version (e.g., `v0.107.53`)
5. Click "Run workflow"

### Rotate Token

If the token needs to be rotated:

1. Create new token with same permissions
2. Update `WARPNETDNS_RELEASE_TOKEN` secret
3. Delete old token from GitHub
4. Trigger a test build to verify

## Support

For issues:
1. Check workflow logs: https://github.com/BrunoMiguelMota/Linux-Scripts/actions
2. Review this documentation
3. Open an issue: https://github.com/BrunoMiguelMota/Linux-Scripts/issues

## Summary Checklist

- [ ] Create warpnetdns repository
- [ ] Generate GitHub Personal Access Token
- [ ] Add WARPNETDNS_RELEASE_TOKEN secret
- [ ] Merge this PR to main
- [ ] Manually trigger first workflow run
- [ ] Verify release appears in warpnetdns repository
- [ ] Test download URL works
- [ ] Test installation script works

Once all steps are complete, the automated system will handle all future builds!
