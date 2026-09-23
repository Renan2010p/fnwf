#!/bin/bash
set -e

echo "=== Building PS2 ISO ==="

# Paths
SRC_DIR="/tmp/fnwf-iso"
OUTPUT="./fnwf-ps2.iso"
ELF="builddir-ps2/fnwf.elf"

# Check ELF exists
if [ ! -f "$ELF" ]; then
    echo "ERROR: ELF not found. Run ./build-ps2.sh first"
    exit 1
fi

# Clean and create ISO structure
rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR/ASSETS/FONT"
mkdir -p "$SRC_DIR/ASSETS/IMAGES"
mkdir -p "$SRC_DIR/ASSETS/AUDIO"

# Copy ELF
echo "Copying ELF..."
cp "$ELF" "$SRC_DIR/FNWF.ELF"

# Copy assets with uppercase names
echo "Copying assets..."
for f in assets/font/*; do
    [ -f "$f" ] && cp "$f" "$SRC_DIR/ASSETS/FONT/$(basename "$f" | tr '[:lower:]' '[:upper:]')"
done
for f in assets/images/*; do
    [ -f "$f" ] && cp "$f" "$SRC_DIR/ASSETS/IMAGES/$(basename "$f" | tr '[:lower:]' '[:upper:]')"
done
for f in assets/audio/*; do
    [ -f "$f" ] && cp "$f" "$SRC_DIR/ASSETS/AUDIO/$(basename "$f" | tr '[:lower:]' '[:upper:]')"
done

# Create SYSTEM.CNF
echo "Creating SYSTEM.CNF..."
cat > "$SRC_DIR/SYSTEM.CNF" << 'EOF'
BOOT2 = cdrom0:\FNWF.ELF;1
VER = 1.00
VMODE = NTSC
EOF

# List structure
echo ""
echo "=== ISO Structure ==="
find "$SRC_DIR" -type f | sort

# Try to create ISO with available tools
echo ""
echo "Creating ISO..."
if command -v genisoimage &> /dev/null; then
    genisoimage -R -J -V "FNWF PS2" -o "$OUTPUT" "$SRC_DIR"
elif command -v mkisofs &> /dev/null; then
    mkisofs -R -J -V "FNWF PS2" -o "$OUTPUT" "$SRC_DIR"
elif command -v xorriso &> /dev/null; then
    xorriso -as mkisofs -o "$OUTPUT" "$SRC_DIR"
else
    echo "WARNING: No ISO tool found, using Python fallback"
    python3 create_ps2_iso.py
fi

echo ""
echo "=== Build Complete ==="
ls -lh "$OUTPUT"
echo ""
echo "📋 To burn the ISO:"
echo "   cdrecord -v -dao dev=/dev/cdrom fnwf-ps2.iso"
echo "   # or use brasero/k3b/bredis for GUI burning"
