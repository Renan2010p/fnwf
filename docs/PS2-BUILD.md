# PS2 Build Guide

## Build PS2 ISO

### Local Build

```bash
# 1. Build ELF
./build-ps2.sh

# 2. Build ISO
./build-ps2-iso.sh
```

### GitHub Actions

The workflow automatically builds when you push to `main` or run manually:

```bash
# Trigger manual build
gh workflow run build-ps2.yml
```

Or go to Actions tab → "Build PS2 ISO" → "Run workflow"

## ISO Structure

```
fnwf-ps2.iso
├── SYSTEM.CNF          # Boot config (BOOT2 = cdrom0:\SLUS_200.01;1)
├── SLUS_200.01         # ELF executable
├── VIDEO_TS/           # DVD structure (required for BIOS)
│   ├── VIDEO_TS.IFO
│   └── VIDEO_TS.VOB
├── AUDIO_TS/           # Empty folder (required)
└── ASSETS/             # Game assets
    ├── *.PNG
    ├── AUDIO/*.OGG
    └── FONT/*.TTF
```

## Disc ID

- **SLUS-99001** - Unique ID for this homebrew
- Avoids collision with Tekken Tag Tournament (SLUS-20001)

## Testing

### PCSX2

1. Open PCSX2
2. File > Run CDVD
3. Select `fnwf-ps2.iso`

### Real PS2

1. Burn ISO to DVD-R at 1x-4x speed
2. Insert into PS2
3. Game boots automatically after BIOS intro

## Troubleshooting

### "Please insert PlayStation 2 format disc"

- Use DVD-R instead of CD-R
- Burn at lower speed (1x-4x)
- Ensure VIDEO_TS/AUDIO_TS structure exists

### Wrong game title in PCSX2

The PCSX2 game database (`GameIndex.yaml`) is updated automatically with our Disc ID.

If the name is wrong:
1. Check `~/.config/PCSX2/resources/GameIndex.yaml`
2. Find `SLUS-99001` entry
3. Update the `name` field

### Game crashes on boot

- Verify all assets are in UPPERCASE (ISO9660 requirement)
- Check that VIDEO_TS structure exists
- Try rebuilding with `./build-ps2-iso.sh`

## Files

| File | Description |
|------|-------------|
| `build-ps2.sh` | Build ELF for PS2 |
| `build-ps2-iso.sh` | Build bootable ISO |
| `.github/workflows/build-ps2.yml` | GitHub Actions workflow |
| `.github/workflows/ci.yml` | Main CI (includes PS2) |

## Requirements

- `ps2dev` toolchain (`/usr/local/ps2dev`)
- `gsKit` (`/usr/local/ps2dev/gsKit`)
- `mkps2iso` v1.1.1+ (auto-downloaded if missing)
