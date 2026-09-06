#!/usr/bin/env bash
# ── FNWF Free Sound Generator ──
# Generates placeholder sound effects using ffmpeg synthesis.
# All sounds are 100% original (no copyrighted material).
# Replace with better sounds later if desired.
set -euo pipefail

AUDIO_DIR="$(cd "$(dirname "$0")" && pwd)/assets/audio"
mkdir -p "$AUDIO_DIR"

log() { echo -e "\033[1;32m→ $1\033[0m"; }

# Helper: generate OGG from ffmpeg filter
gen() {
  local out="$1" desc="$2" filters="$3" dur="${4:-1}"
  log "  $desc → $out"
  ffmpeg -y -loglevel error -f lavfi -i "anoisesrc=d=$dur:c=pink:r=44100:a=0.02,$filters" \
    -c:a libvorbis -q:a 5 "$AUDIO_DIR/$out" 2>/dev/null || \
  ffmpeg -y -loglevel error -f lavfi -i "sine=frequency=440:duration=$dur:sample_rate=44100,$filters" \
    -c:a libvorbis -q:a 5 "$AUDIO_DIR/$out" 2>/dev/null
}

echo "╔══════════════════════════════════════════╗"
echo "║  FNWF Free Sound Generator (CC0/Original)║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── 1. Door open/close ──
log "Door sound"
ffmpeg -y -loglevel error -f lavfi \
  -i "anoisesrc=d=0.4:c=white:r=44100:a=0.15,highpass=f=200,lowpass=f=2000,afade=t=in:d=0.05,afade=t=out:st=0.25:d=0.15" \
  -c:a libvorbis -q:a 5 "$AUDIO_DIR/portas.ogg"
log "  ✓ portas.ogg"

# ── 2. Camera/UI blip ──
log "Camera blip"
ffmpeg -y -loglevel error -f lavfi \
  -i "sine=frequency=1200:duration=0.08:sample_rate=44100,afade=t=in:d=0.01,afade=t=out:st=0.04:d=0.04,volume=0.3" \
  -c:a libvorbis -q:a 5 "$AUDIO_DIR/trocar_camera.ogg"
log "  ✓ trocar_camera.ogg"

# ── 3. Mask equip (fabric rustle) ──
log "Mask equip"
ffmpeg -y -loglevel error -f lavfi \
  -i "anoisesrc=d=0.3:c=pink:r=44100:a=0.08,bandpass=f=800:w=400,afade=t=in:d=0.05,afade=t=out:st=0.15:d=0.15" \
  -c:a libvorbis -q:a 5 "$AUDIO_DIR/colocar_mascara.ogg"
log "  ✓ colocar_mascara.ogg"

# ── 4. Mask remove ──
log "Mask remove"
ffmpeg -y -loglevel error -f lavfi \
  -i "anoisesrc=d=0.35:c=pink:r=44100:a=0.06,bandpass=f=1000:w=500,afade=t=in:d=0.08,afade=t=out:st=0.15:d=0.2" \
  -c:a libvorbis -q:a 5 "$AUDIO_DIR/retirar_mascara.ogg"
log "  ✓ retirar_mascara.ogg"

# ── 5. Mask breathing (loop) ──
log "Mask breathing"
ffmpeg -y -loglevel error -f lavfi \
  -i "anoisesrc=d=2.0:c=pink:r=44100:a=0.03,lowpass=f=600,afade=t=in:d=0.3,afade=t=out:st=1.5:d=0.5,volume=0.5" \
  -c:a libvorbis -q:a 5 "$AUDIO_DIR/usando_a_mascara.ogg"
log "  ✓ usando_a_mascara.ogg"

# ── 6. Jumpscare scream ──
log "Jumpscare"
ffmpeg -y -loglevel error -f lavfi \
  -i "anoisesrc=d=0.8:c=white:r=44100:a=0.3,highpass=f=300,lowpass=f=4000,afade=t=in:d=0.02,afade=t=out:st=0.5:d=0.3,acompressor=threshold=-20dB:ratio=4:attack=5:release=50" \
  -c:a libvorbis -q:a 5 "$AUDIO_DIR/animatronic_na_porta.ogg"
log "  ✓ animatronic_na_porta.ogg"

# ── 7. Night complete / 6AM chime ──
log "6AM chime"
ffmpeg -y -loglevel error -f lavfi \
  -i "sine=frequency=880:duration=0.6:sample_rate=44100,volume=0.4,afade=t=in:d=0.01,afade=t=out:st=0.35:d=0.25" \
  -c:a libvorbis -q:a 5 "$AUDIO_DIR/noite_concluida.ogg"
log "  ✓ noite_concluida.ogg"

# ── 8. Footsteps ──
log "Footsteps"
ffmpeg -y -loglevel error -f lavfi \
  -i "anoisesrc=d=0.15:c=brown:r=44100:a=0.2,lowpass=f=500,afade=t=in:d=0.01,afade=t=out:st=0.05:d=0.1" \
  -c:a libvorbis -q:a 5 "$AUDIO_DIR/passos.ogg"
log "  ✓ passos.ogg"

# ── 9. Ventilation ──
log "Ventilation"
ffmpeg -y -loglevel error -f lavfi \
  -i "anoisesrc=d=1.0:c=pink:r=44100:a=0.04,bandpass=f=300:w=200,afade=t=in:d=0.2,afade=t=out:st=0.7:d=0.3" \
  -c:a libvorbis -q:a 5 "$AUDIO_DIR/ventilacao.ogg"
log "  ✓ ventilacao.ogg"

# ── 10. Menu ambient ──
log "Menu ambient"
ffmpeg -y -loglevel error -f lavfi \
  -i "anoisesrc=d=8.0:c=pink:r=44100:a=0.015,lowpass=f=200,afade=t=in:d=1.0,afade=t=out:st=7.0:d=1.0" \
  -c:a libvorbis -q:a 5 "$AUDIO_DIR/menu_ambient.ogg"
log "  ✓ menu_ambient.ogg"

# ── 11. Gameplay ambient ──
log "Gameplay ambient"
ffmpeg -y -loglevel error -f lavfi \
  -i "anoisesrc=d=10.0:c=pink:r=44100:a=0.01,lowpass=f=150,afade=t=in:d=2.0,afade=t=out:st=8.0:d=2.0" \
  -c:a libvorbis -q:a 5 "$AUDIO_DIR/ambient.ogg"
log "  ✓ ambient.ogg"

# ── 12. Sonk charge (running) ──
log "Sonk charge"
ffmpeg -y -loglevel error -f lavfi \
  -i "anoisesrc=d=0.6:c=brown:r=44100:a=0.2,highpass=f=100,lowpass=f=800,afade=t=in:d=0.1,afade=t=out:st=0.3:d=0.3" \
  -c:a libvorbis -q:a 5 "$AUDIO_DIR/sonk_indo_pra_porta.ogg"
log "  ✓ sonk_indo_pra_porta.ogg"

echo ""
log "All sounds generated in $AUDIO_DIR/"
log "These are placeholder sounds - replace with better ones if desired."
echo ""
echo "To find free high-quality alternatives:"
echo "  https://pixabay.com/sound-effects/search/horror/"
echo "  https://freesound.org/search/?f=license:%22Creative+Commons+0%22"
echo "  https://opengameart.org/art-search-advanced?field_art_type_tid%5B%5D=12"
echo ""
