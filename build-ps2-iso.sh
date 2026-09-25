#!/bin/bash
# ── Build PS2 ISO for FNWF ──
# Usage: ./build-ps2-iso.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ── Paths ──
PS2DEV="${PS2DEV:-/usr/local/ps2dev}"
PS2SDK="${PS2SDK:-$PS2DEV/ps2sdk}"
GSKIT="${GSKIT:-$PS2DEV/gsKit}"
MKPS2ISO="/tmp/mkps2iso-bin/mkps2iso-1.1.1-Linux/bin/mkps2iso"
ISO_OUTPUT="./fnwf-ps2.iso"
ELF="builddir-ps2/fnwf.elf"

# ── Version ──
VERSION=$(grep "^version" meson.build | head -1 | sed "s/.*'\(.*\)'.*/\1/")
DISC_ID="SLUS-99001"  # Unique ID to avoid collision with Tekken Tag Tournament

echo "=== Building PS2 ISO v${VERSION} ==="

# ── Check ELF exists ──
if [ ! -f "$ELF" ]; then
    echo "ERROR: ELF not found. Run ./build-ps2.sh first"
    exit 1
fi

# ── Check mkps2iso ──
if [ ! -f "$MKPS2ISO" ]; then
    echo "Downloading mkps2iso..."
    mkdir -p /tmp/mkps2iso-bin
    curl -sL "https://github.com/N4gtan/mkps2iso/releases/download/v1.1.1/mkps2iso-1.1.1-Linux.zip" \
        -o /tmp/mkps2iso.zip
    unzip -o /tmp/mkps2iso.zip -d /tmp/mkps2iso-bin
    chmod +x "$MKPS2ISO"
fi

# ── Clean and create ISO structure ──
SRC_DIR="/tmp/fnwf-ps2-iso"
rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR/VIDEO_TS"
mkdir -p "$SRC_DIR/AUDIO_TS"
mkdir -p "$SRC_DIR/ASSETS/AUDIO"
mkdir -p "$SRC_DIR/ASSETS/FONT"

# ── Copy ELF ──
echo "Copying ELF..."
cp "$ELF" "$SRC_DIR/SLUS_200.01"

# ── Copy assets with uppercase names ──
echo "Copying assets..."
for f in assets/*.png; do
    [ -f "$f" ] && cp "$f" "$SRC_DIR/ASSETS/$(basename "$f" | tr '[:lower:]' '[:upper:]')"
done
for f in assets/audio/*.ogg; do
    [ -f "$f" ] && cp "$f" "$SRC_DIR/ASSETS/AUDIO/$(basename "$f" | tr '[:lower:]' '[:upper:]')"
done
for f in assets/font/*.ttf; do
    [ -f "$f" ] && cp "$f" "$SRC_DIR/ASSETS/FONT/$(basename "$f" | tr '[:lower:]' '[:upper:]')"
done

# ── Create DVD structure files ──
echo "Creating DVD structure..."
dd if=/dev/zero of="$SRC_DIR/VIDEO_TS/VIDEO_TS.IFO" bs=2048 count=1 2>/dev/null
dd if=/dev/zero of="$SRC_DIR/VIDEO_TS/VIDEO_TS.VOB" bs=2048 count=1 2>/dev/null

# ── Create SYSTEM.CNF ──
cat > "$SRC_DIR/SYSTEM.CNF" << EOF
BOOT2 = cdrom0:\\SLUS_200.01;1
VER = 1.00
VMODE = NTSC
disc_id = ${DISC_ID}
brand = Sony Computer Entertainment
product_name = FIVE NIGHTS WITH FRIENDS
brand_code = SL
product_code = ${DISC_ID}
region = USA
EOF

# ── List structure ──
echo ""
echo "=== ISO Structure ==="
find "$SRC_DIR" -type f | sort
echo ""
echo "Total files: $(find "$SRC_DIR" -type f | wc -l)"

# ── Create XML for mkps2iso ──
cat > "/tmp/fnwf-ps2-project.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<iso_project image_name="fnwf-ps2" serial="${DISC_ID}" region="america">
    <identifiers
        system="PLAYSTATION 2"
        application="FIVE NIGHTS WITH FRIENDS"
        volume="${DISC_ID}"
        producer="RENAN2010P"
        publisher="INDIE"
    />
    <layer>
        <directory_tree source="${SRC_DIR}">
            <file name="SYSTEM.CNF"/>
            <file name="SLUS_200.01"/>
            <dir name="VIDEO_TS">
                <file name="VIDEO_TS.IFO"/>
                <file name="VIDEO_TS.VOB"/>
            </dir>
            <dir name="AUDIO_TS"/>
            <dir name="ASSETS">
                <file name="ALICE.PNG"/>
                <file name="CEDRO.PNG"/>
                <file name="ESER.PNG"/>
                <file name="MAFIA.PNG"/>
                <file name="RENAN.PNG"/>
                <file name="SONK.PNG"/>
                <dir name="AUDIO">
                    <file name="AMBIENT.OGG"/>
                    <file name="ANIMATRONIC_NA_PORTA.OGG"/>
                    <file name="COLOCAR_MASCARA.OGG"/>
                    <file name="MENU_AMBIENT.OGG"/>
                    <file name="NOITE_CONCLUIDA.OGG"/>
                    <file name="PASSOS.OGG"/>
                    <file name="PORTAS.OGG"/>
                    <file name="RETIRAR_MASCARA.OGG"/>
                    <file name="SONK_INDO_PRA_PORTA.OGG"/>
                    <file name="TROCAR_CAMERA.OGG"/>
                    <file name="USANDO_A_MASCARA.OGG"/>
                    <file name="VENTILACAO.OGG"/>
                </dir>
                <dir name="FONT">
                    <file name="FONT.TTF"/>
                </dir>
            </dir>
        </directory_tree>
    </layer>
</iso_project>
EOF

# ── Build ISO ──
echo ""
echo "Building ISO..."
"$MKPS2ISO" -y -o "$ISO_OUTPUT" "/tmp/fnwf-ps2-project.xml"

# ── Verify ──
echo ""
echo "=== Build Complete ==="
ls -lh "$ISO_OUTPUT"
echo ""
echo "📋 ISO Info:"
iso-info -i "$ISO_OUTPUT" 2>/dev/null | grep -E "Application|Volume|System" || true
echo ""
echo "✅ ISO created: ${ISO_OUTPUT}"
echo "📀 Disc ID: ${DISC_ID}"
echo "🎮 To test on PCSX2: File > Run CDVD -> ${ISO_OUTPUT}"
echo ""
echo "📦 To burn to disc:"
echo "   cdrecord -v -dao dev=/dev/cdrom ${ISO_OUTPUT}"
