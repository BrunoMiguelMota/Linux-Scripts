# WarpNETDNS Build and Release System

This repository contains scripts and workflows to build and release WarpNETDNS, a rebranded version of AdGuard Home customized for Warp NET services.

## Overview

WarpNETDNS is automatically built from AdGuard Home source code with custom branding, themes, and configuration. The build process is automated via GitHub Actions.

## Build System

### Components

1. **install_warpnetdns.sh** - Main build script that:
   - Clones AdGuard Home source
   - Applies Warp NET branding
   - Builds binaries for target platforms
   - Creates distribution packages

2. **GitHub Actions Workflow** - Automated CI/CD that:
   - Builds binaries for multiple architectures (amd64, arm64, arm, armv7)
   - Creates releases on the BrunoMiguelMota/warpnetdns repository
   - Makes binaries available at `https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/`

### Setup Instructions

#### Prerequisites

To use the automated release system, you need to:

1. Create a separate repository for releases: `https://github.com/BrunoMiguelMota/warpnetdns`

2. Create a Personal Access Token (PAT) with the following permissions:
   - `repo` (Full control of private repositories)
   - `write:packages` (if publishing packages)

3. Add the PAT as a repository secret:
   - Go to this repository's Settings → Secrets and variables → Actions
   - Create a new secret named `WARPNETDNS_RELEASE_TOKEN`
   - Paste your PAT as the value

#### Building Locally

To build WarpNETDNS locally:

```bash
# Clone this repository
git clone https://github.com/BrunoMiguelMota/Linux-Scripts.git
cd Linux-Scripts

# Run the build script
chmod +x install_warpnetdns.sh
./install_warpnetdns.sh

# The package will be created in warpnetdns-build/
```

You can customize the build with environment variables:

```bash
# Build for different architecture
GOOS=linux GOARCH=arm64 ./install_warpnetdns.sh

# Use a different AdGuard Home version
ADGUARD_VERSION=v0.107.52 ./install_warpnetdns.sh
```

#### Automated Releases

The GitHub Actions workflow automatically:

1. Triggers on push to main branch when `install_warpnetdns.sh` or the workflow file changes
2. Can also be manually triggered via workflow_dispatch
3. Builds for multiple architectures in parallel
4. Creates a new release with all binaries
5. Updates the "latest" tag for easy access

### Installation on Target Systems

Users can install WarpNETDNS using the installer script:

```bash
# Using the installation script (recommended)
curl -fsSL https://raw.githubusercontent.com/BrunoMiguelMota/Linux-Scripts/main/install_adguardhome_warpnet.sh | sudo bash

# Or manually:
wget https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_amd64.tar.gz
tar xzf warpnetdns_linux_amd64.tar.gz
sudo ./WarpNETDNS
```

### Available Packages

- `warpnetdns_linux_amd64.tar.gz` - Linux x86_64 (most common)
- `warpnetdns_linux_arm64.tar.gz` - Linux ARM64 (Raspberry Pi 4, etc.)
- `warpnetdns_linux_arm.tar.gz` - Linux ARM
- `warpnetdns_linux_armv7.tar.gz` - Linux ARMv7

## Customization

The build script automatically applies the following customizations:

- **Branding**: All "AdGuard Home" references are replaced with "Warp NET DNS"
- **Logo**: Custom Warp NET logo in blue theme
- **Theme**: Custom CSS with Warp NET color scheme (#4183c4 primary)
- **Binary name**: Renamed to `WarpNETDNS`

## Troubleshooting

### Build Failures

If the build fails, check:

1. Go version compatibility (requires Go 1.22+)
2. AdGuard Home version availability
3. Internet connectivity for cloning source

### Release Failures

If releases fail to publish:

1. Verify `WARPNETDNS_RELEASE_TOKEN` secret is set correctly
2. Check that the token has appropriate permissions
3. Ensure the warpnetdns repository exists and is accessible

## Contributing

To modify the build process:

1. Edit `install_warpnetdns.sh` for build logic changes
2. Edit `.github/workflows/build-warpnetdns.yml` for CI/CD changes
3. Test locally before committing
4. Push to main branch to trigger automated build

## License

WarpNETDNS is based on AdGuard Home, which is licensed under GPL-3.0. This customized version maintains the same license.
