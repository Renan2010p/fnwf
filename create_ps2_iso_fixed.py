#!/usr/bin/env python3
"""Create a proper PS2 bootable ISO with correct sector layout."""

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
    for rel, data in files:
        print(f"  {rel} ({len(data)/1024:.1f} KB)")
    
    # Calculate layout
    total_data = sum(len(d) for _, d in files)
    num_files = len(files)
    
    # Directory entries: . + .. + files
    num_dir_entries = 2 + num_files
    dir_entries_size = num_dir_entries * 34
    
    # Sector layout:
    # Sectors 0-15: System area (zeros)
    # Sector 16: Primary Volume Descriptor (PVD)
    # Sector 17: Root directory entries (. + ..)
    # Sector 18+: File directory entries
    # After entries: File data
    
    pvd_sector = 16
    root_dir_sector = 17
    file_entries_sector = 18
    
    # Root directory entry size (2 entries: . and ..)
    root_dir_size = 2 * 34
    
    # File entries start at sector 18
    file_entries_start = file_entries_sector * SECTOR
    
    # File data starts after root dir + file entries
    file_data_start = file_entries_start + num_dir_entries * 34
    file_data_start = ((file_data_start + SECTOR - 1) // SECTOR) * SECTOR
    file_data_sector = file_data_start // SECTOR
    
    total_size = file_data_start + total_data
    total_size = ((total_size + SECTOR - 1) // SECTOR) * SECTOR
    
    print(f"\nLayout:")
    print(f"  PVD: sector {pvd_sector}")
    print(f"  Root dir: sector {root_dir_sector} ({root_dir_size} bytes)")
    print(f"  File entries: sector {file_entries_sector}")
    print(f"  File data: sector {file_data_sector}")
    print(f"  Total: {total_size // SECTOR} sectors ({total_size/1024/1024:.2f} MB)")
    
    # Create ISO
    iso = bytearray(total_size)
    
    # === PVD (sector 16) ===
    pvd = bytearray(SECTOR)
    pvd[0] = 2  # Type: Primary Volume Descriptor
    pvd[1:6] = b'CD001'
    pvd[6] = 1
    pvd[41:73] = b'PLAYSTATION 2'
    pvd[73:105] = b'SLUS-20001'
    struct.pack_into('<Q', pvd, 129, total_size // SECTOR)
    struct.pack_into('<Q', pvd, 155, total_size // SECTOR)
    struct.pack_into('<H', pvd, 163, SECTOR)
    iso[16*SECTOR:17*SECTOR] = pvd
    
    # === Root Directory (sector 17) ===
    root_off = root_dir_sector * SECTOR
    
    # Entry for .
    iso[root_off] = 34
    struct.pack_into('<I', iso, root_off+1, root_dir_sector)
    struct.pack_into('<I', iso, root_off+5, root_dir_size + num_files * 34)
    iso[root_off+9] = 90
    iso[root_off+16] = 0x03
    iso[root_off+21] = 1
    iso[root_off+22] = ord('.')
    
    # Entry for ..
    iso[root_off+34] = 34
    struct.pack_into('<I', iso, root_off+35, pvd_sector)
    struct.pack_into('<I', iso, root_off+39, SECTOR)
    iso[root_off+43] = 90
    iso[root_off+50] = 0x02
    iso[root_off+55] = 2
    iso[root_off+56] = ord('.')
    iso[root_off+57] = ord('.')
    
    # === File Directory Entries (sector 18+) ===
    entry_off = file_entries_sector * SECTOR
    file_data_off = file_data_start
    
    for i, (rel, data) in enumerate(files):
        name = os.path.basename(rel).split(';')[0][:31]
        name_len = len(name)
        
        # Directory entry
        iso[entry_off] = 34
        struct.pack_into('<I', iso, entry_off+1, file_data_off // SECTOR)
        struct.pack_into('<I', iso, entry_off+5, len(data))
        iso[entry_off+9] = 90
        iso[entry_off+16] = 0x00
        iso[entry_off+21] = name_len
        for j, c in enumerate(name):
            iso[entry_off+22+j] = ord(c)
        entry_off += 34
        
        # File data
        iso[file_data_off:file_data_off+len(data)] = data
        file_data_off += len(data)
    
    # Write ISO
    with open(output_path, 'wb') as f:
        f.write(iso)
    
    print(f"\n✅ ISO created: {output_path}")
    print(f"📊 Size: {len(iso)/1024/1024:.2f} MB")
    
    # Verify
    print("\n=== Verification ===")
    with open(output_path, 'rb') as f:
        # Check PVD
        f.seek(16*SECTOR)
        pvd = f.read(256)
        print(f"PVD Type: {pvd[0]} (expected 2)")
        print(f"PVD Sig: {pvd[1:6]}")
        print(f"Volume: {pvd[73:105].decode().strip()}")
        
        # Check directory entries
        f.seek(17*SECTOR)
        entries = []
        for i in range(30):
            entry = f.read(34)
            if entry[0] != 34 or entry[21] == 0:
                break
            name = entry[22:22+entry[21]].decode('ascii', errors='ignore')
            sector = struct.unpack('<I', entry[1:5])[0]
            size = struct.unpack('<I', entry[5:9])[0]
            entries.append((name, sector, size))
        
        print(f"\nEntries: {len(entries)}")
        for name, sector, size in entries:
            print(f"  {name:30s} sector={sector:5d} size={size:8d}")
        
        # Read SYSTEM.CNF
        for name, sector, size in entries:
            if 'SYSTEM' in name:
                f.seek(sector*SECTOR)
                data = f.read(size)
                print(f"\nSYSTEM.CNF content:")
                text = data.decode('ascii', errors='ignore')
                for line in text.split('\n'):
                    if '=' in line:
                        print(f"  {line.strip()}")
                break


if __name__ == "__main__":
    create_ps2_iso("/tmp/fnwf-iso", "/home/renan/Projects/cpp/fnwf/fnwf-ps2.iso")
