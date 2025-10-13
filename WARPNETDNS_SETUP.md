# WarpNETDNS Quick Setup Guide

This guide will help you set up the automated build and release system for WarpNETDNS.

## Step 1: Create the WarpNETDNS Repository

1. Go to GitHub and create a new repository:
   - Repository name: `warpnetdns`
   - Owner: `BrunoMiguelMota`
   - Description: "Warp NET DNS - Custom branded AdGuard Home"
   - Visibility: Public
   - Initialize with: README (optional)

   URL: https://github.com/new

2. Alternatively, use the setup script:
   ```bash
   ./setup_warpnetdns_repo.sh
   ```

## Step 2: Create GitHub Personal Access Token

1. Go to: https://github.com/settings/tokens/new

2. Configure the token:
   - Note: `WarpNETDNS Release Token`
   - Expiration: No expiration (or set as needed)
   - Select scopes:
     - ✓ `repo` (Full control of private repositories)
     - ✓ `write:packages` (Upload packages to GitHub Package Registry)

3. Click "Generate token"

4. **IMPORTANT**: Copy the token immediately (you won't see it again!)

## Step 3: Add Token to Linux-Scripts Repository

1. Go to the Linux-Scripts repository settings:
   https://github.com/BrunoMiguelMota/Linux-Scripts/settings/secrets/actions

2. Click "New repository secret"

3. Add the secret:
   - Name: `WARPNETDNS_RELEASE_TOKEN`
   - Secret: [Paste your token here]

4. Click "Add secret"

## Step 4: Trigger the First Build

### Option A: Automatic (on push)

Simply merge this PR to the main branch, and the workflow will automatically run.

### Option B: Manual Trigger

1. Go to Actions tab:
   https://github.com/BrunoMiguelMota/Linux-Scripts/actions

2. Select "Build and Release WarpNETDNS" workflow

3. Click "Run workflow"

4. Optional: Change the AdGuard Home version if needed

5. Click "Run workflow" button

## Step 5: Wait for Build to Complete

The build process will:
1. Build binaries for 4 architectures (takes ~15-20 minutes)
2. Create artifacts for each platform
3. Create a new release in the warpnetdns repository
4. Upload all binaries to the release

You can monitor progress in the Actions tab.

## Step 6: Verify the Release

Once complete, verify the release is available:

1. Check releases: https://github.com/BrunoMiguelMota/warpnetdns/releases

2. Verify download URLs work:
   ```bash
   # Test download
   curl -I https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_amd64.tar.gz
   
   # Should return: HTTP/2 302 (redirect) followed by 200
   ```

## Step 7: Test Installation

Test the installation on a clean system:

```bash
# Using the installer script
curl -fsSL https://raw.githubusercontent.com/BrunoMiguelMota/Linux-Scripts/main/install_adguardhome_warpnet.sh | sudo bash

# Or manually
wget https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_amd64.tar.gz
tar xzf warpnetdns_linux_amd64.tar.gz
sudo ./WarpNETDNS
```

## Troubleshooting

### Build fails with "Permission denied"

**Problem**: WARPNETDNS_RELEASE_TOKEN doesn't have the right permissions.

**Solution**: 
1. Verify the token has `repo` scope
2. Regenerate the token if needed
3. Update the secret in repository settings

### Releases not appearing in warpnetdns repository

**Problem**: The workflow can't access the warpnetdns repository.

**Solution**:
1. Ensure the warpnetdns repository exists
2. Verify the token has access to the repository
3. Check workflow logs for specific errors

### Build takes too long or times out

**Problem**: Building from source can be resource-intensive.

**Solution**:
- This is normal; builds take 15-20 minutes
- GitHub Actions has a 6-hour timeout, so this should not be an issue
- Consider using a specific AdGuard Home version instead of latest

## Updating AdGuard Home Version

To build from a different AdGuard Home version:

1. Manual trigger:
   - Go to Actions → Build and Release WarpNETDNS → Run workflow
   - Enter the version (e.g., `v0.107.52`)

2. Edit the workflow file:
   - Change `default: 'v0.107.52'` to your desired version
   - Commit and push

## Maintenance

### Regular Updates

1. Check for new AdGuard Home releases: https://github.com/AdguardTeam/AdGuardHome/releases

2. Trigger a new build with the latest version

3. Test the new build before announcing

### Token Rotation

If you need to rotate the token:

1. Create a new token with the same permissions
2. Update `WARPNETDNS_RELEASE_TOKEN` secret
3. Delete the old token from GitHub

## Support

For issues or questions:
- Open an issue: https://github.com/BrunoMiguelMota/Linux-Scripts/issues
- Check build logs in Actions tab
- Review documentation: [WARPNETDNS_BUILD.md](WARPNETDNS_BUILD.md)

---

**Next Steps**: Once setup is complete, the system will automatically build and release WarpNETDNS whenever you update the build script!
