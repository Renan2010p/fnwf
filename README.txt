=== Five Nights With Friends - PS2 Build ===

Para usar no PS2 real:

1. Formate o Memory Stick em FAT32
2. Crie a pasta: /fnwf/
3. Extraia os arquivos dentro dela:
   - fnwf.elf
   - assets/ (pasta com todos os assets)

Estrutura final no Memory Stick:
  /fnwf/
  ├── fnwf.elf
  └── assets/
      ├── font/
      │   └── font.ttf
      ├── images/
      │   ├── office.png
      │   ├── cam1.png
      │   └── ...
      └── audio/
          ├── music.ogg
          └── ...

Rodar pelo homebrew loader (MagicGate, USB Loader, etc.)

=== PS2 Build ===

Resolução: 640×448 (NTSC padrão)
Device: mass: (Memory Stick)
FPS alvo: 60 FPS (GPU via gsKit)
