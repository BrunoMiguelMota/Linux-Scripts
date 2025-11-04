# WarpNETDNS Architecture Overview

## System Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    WARPNETDNS BUILD & RELEASE SYSTEM                    │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────┐
│  Developer/Maintainer   │
│  (You)                  │
└───────────┬─────────────┘
            │
            │ 1. Push to main or
            │    Manual trigger
            ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                      GitHub Actions Workflow                            │
│                   (Linux-Scripts Repository)                            │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │  Step 1: Clone AdGuard Home Source                                │ │
│  │  ├─ git clone github.com/AdguardTeam/AdGuardHome                  │ │
│  │  └─ Version: v0.107.52 (or specified)                             │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│              │                                                           │
│              ↓                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │  Step 2: Apply Warp NET Branding                                  │ │
│  │  ├─ Replace "AdGuard Home" → "Warp NET DNS"                       │ │
│  │  ├─ Inject custom logo (SVG)                                      │ │
│  │  ├─ Apply custom theme (CSS)                                      │ │
│  │  └─ Update version strings                                        │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│              │                                                           │
│              ↓                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │  Step 3: Build Matrix (Parallel)                                  │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌──────────┐│ │
│  │  │ linux/amd64 │  │ linux/arm64 │  │  linux/arm  │  │linux/armv7││ │
│  │  │   Build     │  │   Build     │  │   Build     │  │  Build   ││ │
│  │  │  ~5 mins    │  │  ~5 mins    │  │  ~5 mins    │  │ ~5 mins  ││ │
│  │  └─────┬───────┘  └─────┬───────┘  └─────┬───────┘  └────┬─────┘│ │
│  │        │                 │                 │               │      │ │
│  │        └─────────────────┴─────────────────┴───────────────┘      │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│              │                                                           │
│              ↓                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │  Step 4: Package & Upload Artifacts                               │ │
│  │  ├─ warpnetdns_linux_amd64.tar.gz   (~30 MB)                      │ │
│  │  ├─ warpnetdns_linux_arm64.tar.gz   (~28 MB)                      │ │
│  │  ├─ warpnetdns_linux_arm.tar.gz     (~26 MB)                      │ │
│  │  └─ warpnetdns_linux_armv7.tar.gz   (~26 MB)                      │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│              │                                                           │
│              ↓                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │  Step 5: Create Release                                            │ │
│  │  ├─ Target: BrunoMiguelMota/warpnetdns                            │ │
│  │  ├─ Tag: v1.0.{run_number}                                        │ │
│  │  ├─ Attach all 4 binaries                                         │ │
│  │  └─ Update "latest" tag                                           │ │
│  └───────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
            │
            ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                    warpnetdns Repository                                │
│                    (Release Destination)                                │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │  /releases/latest/download/                                        │ │
│  │  ├─ warpnetdns_linux_amd64.tar.gz                                 │ │
│  │  ├─ warpnetdns_linux_arm64.tar.gz                                 │ │
│  │  ├─ warpnetdns_linux_arm.tar.gz                                   │ │
│  │  └─ warpnetdns_linux_armv7.tar.gz                                 │ │
│  └───────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
            │
            │ wget/curl
            ↓
┌─────────────────────────┐
│  End Users              │
│  ├─ install script      │
│  ├─ manual download     │
│  └─ automated deploy    │
└─────────────────────────┘
```

## Component Details

### 1. Source Repository (Linux-Scripts)
**Location**: `BrunoMiguelMota/Linux-Scripts`
**Purpose**: Contains build scripts and CI/CD automation
**Key Files**:
- `install_warpnetdns.sh` - Build script
- `.github/workflows/build-warpnetdns.yml` - CI/CD pipeline
- `install_adguardhome_warpnet.sh` - User installation script

### 2. Build Process
**Engine**: GitHub Actions
**Duration**: 15-20 minutes
**Triggers**:
- Push to main (affecting build files)
- Manual workflow dispatch

**Steps**:
1. Clone AdGuard Home source
2. Apply branding transformations
3. Compile for each architecture (parallel)
4. Package as compressed archives
5. Create GitHub release
6. Update latest tag

### 3. Release Repository (warpnetdns)
**Location**: `BrunoMiguelMota/warpnetdns`
**Purpose**: Hosts compiled binaries for distribution
**Structure**:
```
warpnetdns/
├── README.md
├── LICENSE
└── releases/
    ├── v1.0.1/
    │   ├── warpnetdns_linux_amd64.tar.gz
    │   ├── warpnetdns_linux_arm64.tar.gz
    │   ├── warpnetdns_linux_arm.tar.gz
    │   └── warpnetdns_linux_armv7.tar.gz
    ├── v1.0.2/
    └── latest/  ← Symlink to most recent
```

### 4. Distribution URLs
**Pattern**: `https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/{filename}`

**Available Downloads**:
- AMD64: `warpnetdns_linux_amd64.tar.gz`
- ARM64: `warpnetdns_linux_arm64.tar.gz`
- ARM: `warpnetdns_linux_arm.tar.gz`
- ARMv7: `warpnetdns_linux_armv7.tar.gz`

### 5. Installation Methods

#### Method A: Automated Installer
```bash
curl -fsSL https://raw.githubusercontent.com/BrunoMiguelMota/Linux-Scripts/main/install_adguardhome_warpnet.sh | sudo bash
```
**Process**:
1. Detects CPU architecture
2. Downloads appropriate binary
3. Extracts to /opt/WarpNETDNS
4. Installs systemd service
5. Starts WarpNETDNS

#### Method B: Manual Installation
```bash
wget https://github.com/BrunoMiguelMota/warpnetdns/releases/latest/download/warpnetdns_linux_amd64.tar.gz
tar xzf warpnetdns_linux_amd64.tar.gz
sudo ./WarpNETDNS
```

## Security Architecture

### Authentication Flow
```
Developer → GitHub Token → GitHub Actions → Release Repository
   │                                           │
   └─ WARPNETDNS_RELEASE_TOKEN ───────────────┘
      (repo scope, encrypted secret)
```

### Access Control
- **Build Triggers**: Only maintainers with write access
- **Release Creation**: Automated via GitHub Actions
- **Token Storage**: Encrypted GitHub secrets
- **Binary Downloads**: Public (no authentication)

## Data Flow

### Build Time
```
AdGuard Home    Linux-Scripts     GitHub         warpnetdns
   Source    →   Build Script  →  Actions   →    Releases
(upstream)     (transformation)  (compile)     (distribution)
```

### Installation Time
```
User Script → Download Binary → Extract → Configure → Run
```

## Scalability

### Build Capacity
- **Parallel builds**: 4 simultaneous (architecture matrix)
- **Build queue**: GitHub Actions queue
- **Rate limits**: GitHub API limits apply
- **Storage**: GitHub release storage (unlimited for public repos)

### Distribution
- **CDN**: GitHub's global CDN
- **Bandwidth**: Unlimited for public repos
- **Concurrent downloads**: No limit
- **Availability**: 99.9%+ (GitHub SLA)

## Maintenance Triggers

### Automatic Rebuilds
- Push to `install_warpnetdns.sh`
- Push to workflow file
- Scheduled (optional - can be added)

### Manual Rebuilds
- Workflow dispatch in Actions tab
- Change AdGuard Home version
- Update branding assets

## Version Management

### Tagging Strategy
```
v1.0.{github.run_number}
│ │  │
│ │  └─ Incremental build number
│ └──── Minor version (stable)
└───── Major version (breaking changes)
```

### Latest Tag
- Points to most recent release
- Updated automatically after each build
- Used by installation scripts for automatic updates

## Monitoring & Logs

### Build Monitoring
- **Location**: GitHub Actions tab
- **Logs**: Full build output available
- **Notifications**: GitHub notifications on failure
- **Status**: Badge can be added to README

### Release Monitoring
- **Location**: Releases page
- **Metrics**: Download counts per asset
- **History**: All previous releases retained

## Disaster Recovery

### Backup Strategy
- **Source code**: Git history in Linux-Scripts
- **Binaries**: All releases retained in warpnetdns
- **Configuration**: Workflow files in source control

### Recovery Procedures
1. **Lost token**: Generate new, update secret
2. **Failed build**: Check logs, re-run workflow
3. **Corrupted release**: Delete and rebuild
4. **Repository issue**: Fork and update references

## Performance Metrics

### Build Performance
- **Clone time**: ~30 seconds
- **Branding time**: ~1 minute
- **Compile time**: ~4-5 minutes per architecture
- **Package time**: ~30 seconds
- **Upload time**: ~1-2 minutes
- **Total**: ~15-20 minutes

### Network Performance
- **Download speed**: Limited by user bandwidth
- **CDN latency**: <100ms globally
- **Mirror availability**: GitHub's CDN redundancy

## Future Enhancements

### Potential Additions
- [ ] Automated testing of binaries
- [ ] Checksum verification
- [ ] GPG signature signing
- [ ] Windows/macOS builds
- [ ] Docker image builds
- [ ] Scheduled security updates
- [ ] Automated changelog generation
- [ ] Build status badges

---

**Last Updated**: 2025-10-13
**Architecture Version**: 1.0
**Status**: Production Ready
