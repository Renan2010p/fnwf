#!/usr/bin/env python3
"""Create a proper PS2 bootable ISO with CORRECT sector layout."""

import struct
import os

def create_ps2_iso(src_dir, output_path):
    SECTOR = 2048
    
    # Collect all files
    files = []
    for root, dirs, fnames in os.walk(src_dir):
        for f in sorted(fnames):
            path = os.path.join(root, f)
            rel = os.path.relpath(path, src_dir).upper()
            with open(path, 'rb') as fp:
                data = fp.read()
            files.append((rel, data))
    
    print(f"Found {len(files)} files")
    
    # === CALCULATE LAYOUT ===
    # Sectors 0-15: System area (zeros)
    # Sector 16: PVD
    # Sector 17: Root directory (. and ..)
    # Sector 18+: File directory entries (34 bytes each)
    # After entries: File data
    
    num_files = len(files)
    num_entries = num_files + 2  # . + ..
    dir_entries_size = num_entries * 34
    
    # Where file data starts (after all directory entries)
    # Entry sector = 18
    # Entry offset within sector = 0
    # Total entry space = num_entries * 34
    data_start_offset = 18 * SECTOR + dir_entries_size
    # Round up to sector boundary
    data_start_offset = ((data_start_offset + SECTOR - 1) // SECTOR) * SECTOR
    data_start_sector = data_start_offset // SECTOR
    
    total_data = sum(len(d) for _, d in files)
    total_size = data_start_offset + total_data
    total_size = ((total_size + SECTOR - 1) // SECTOR) * SECTOR
    total_sectors = total_size // SECTOR
    
    print(f"Directory entries: {dir_entries_size} bytes (sectors 17-{17 + dir_entries_size//SECTOR})")
    print(f"File data starts: sector {data_start_sector} (offset {data_start_offset})")
    print(f"Total: {total_sectors} sectors ({total_size/1024/1024:.2f} MB)")
    
    # === CREATE ISO ===
    iso = bytearray(total_size)
    
    # --- PVD (sector 16) ---
    pvd = bytearray(SECTOR)
    pvd[0] = 2  # Type
    pvd[1:6] = b'CD001'
    pvd[6] = 1
    pvd[41:73] = b'PLAYSTATION 2'
    pvd[73:105] = b'SLUS-20001'
    struct.pack_into('<Q', pvd, 129, total_sectors)
    struct.pack_into('<Q', pvd, 155, total_sectors)
    struct.pack_into('<H', pvd, 163, SECTOR)
    iso[16*SECTOR:17*SECTOR] = pvd
    
    # --- Root Directory (sector 17) ---
    root_off = 17 * SECTOR
    
    # Entry for .
    iso[root_off] = 34
    struct.pack_into('<I', iso, root_off+1, 17)  # extent
    struct.pack_into('<I', iso, root_off+5, dir_entries_size)  # size
    iso[root_off+9] = 90
    iso[root_off+16] = 0x03  # flags: directory
    iso[root_off+21] = 1
    iso[root_off+22] = ord('.')
    
    # Entry for ..
    iso[root_off+34] = 34
    struct.pack_into('<I', iso, root_off+35, 16)  # extent = PVD sector
    struct.pack_into('<I', iso, root_off+39, SECTOR)
    iso[root_off+43] = 90
    iso[root_off+50] = 0x02
    iso[root_off+55] = 2
    iso[root_off+56] = ord('.')
    iso[root_off+57] = ord('.')
    
    # --- File Entries (sector 18+) ---
    entry_off = 18 * SECTOR
    file_data_off = data_start_offset
    
    for i, (rel, data) in enumerate(files):
        name = os.path.basename(rel).split(';')[0][:31]
        name_len = len(name)
        
        # Directory entry
        iso[entry_off] = 34
        struct.pack_into('<I', iso, entry_off+1, file_data_off // SECTOR)
        struct.pack_into('<I', iso, entry_off+5, len(data))
        iso[entry_off+9] = 90
        iso[entry_off+16] = 0x00  # flags: file
        iso[entry_off+21] = name_len
        for j, c in enumerate(name):
            iso[entry_off+22+j] = ord(c)
        entry_off += 34
        
        # File data
        iso[file_data_off:file_data_off+len(data)] = data
        # Align to next sector boundary
        file_data_off += len(data)
        file_data_off = ((file_data_off + SECTOR - 1) // SECTOR) * SECTOR
    
    print(f"\nFile data layout:")
    print(f"  FNWF.ELF: sector 19, size 15848780 bytes")
    print(f"  Next file should be at sector {(19*SECTOR + 15848780 + SECTOR-1)//SECTOR}")
    
    # Write
    with open(output_path, 'wb') as f:
        f.write(iso)
    
    print(f"\n✅ ISO: {output_path}")
    
    # === VERIFY ===
    print("\n=== Verification ===")
    with open(output_path, 'rb') as f:
        # Check PVD
        f.seek(16*SECTOR)
        pvd = f.read(256)
        print(f"PVD Type: {pvd[0]} (expected 2)")
        print(f"PVD Sig: {pvd[1:6]}")
        print(f"Volume: {pvd[73:105].decode().strip()}")
        
        # Check root dir
        f.seek(17*SECTOR)
        root = f.read(68)
        print(f"\nRoot dir: entry1 len={root[0]}, entry2 len={root[34]}")
        
        # Check file entries
        f.seek(18*SECTOR)
        entries = []
        for i in range(30):
            entry = f.read(34)
            if entry[0] != 34 or entry[21] == 0:
                break
            name = entry[22:22+entry[21]].decode('ascii', errors='ignore')
            sector = struct.unpack('<I', entry[1:5])[0]
            size = struct.unpack('<I', entry[5:9])[0]
            entries.append((name, sector, size))
        
        print(f"\nFiles: {len(entries)}")
        for name, sector, size in entries:
            print(f"  {name:30s} sector={sector:5d} ({size/1024:.1f} KB)")
        
        # Verify SYSTEM.CNF content
        for name, sector, size in entries:
            if 'SYSTEM' in name:
                f.seek(sector*SECTOR)
                data = f.read(size)
                text = data.decode('ascii', errors='ignore')
                print(f"\n=== SYSTEM.CNF (sector {sector}) ===")
                for line in text.split('\n'):
                    if '=' in line or line.strip():
                        print(f"  {line.strip()}")
                break
        
        # Verify FNWF.ELF is valid
        for name, sector, size in entries:
            if 'FNWF' in name:
                f.seek(sector*SECTOR)
                header = f.read(4)
                print(f"\n=== FNWF.ELF (sector {sector}) ===")
                print(f"  ELF magic: {header.hex()} (expected: 7f454c46)")
                break


if __name__ == "__main__":
    create_ps2_iso("/tmp/fnwf-iso", "/home/renan/Projects/cpp/fnwf/fnwf-ps2.iso")
