#!/usr/bin/env python3
"""
Create a proper PS2 bootable ISO with correct sector layout.
"""

import struct
import os

def create_ps2_iso(src_dir, output_path):
    """Create a PS2-compatible ISO9660 disc image."""
    
    # Collect all files
    files = []
    for root, dirs, filenames in os.walk(src_dir):
        for f in sorted(filenames):
            path = os.path.join(root, f)
            rel = os.path.relpath(path, src_dir).upper()
            with open(path, 'rb') as fp:
                data = fp.read()
            files.append((rel, data))
            print(f"  {rel} ({len(data)/1024:.1f} KB)")
    
    SECTOR = 2048
    
    # Calculate total data size
    total_data = sum(len(f[1]) for f in files)
    
    # Directory entries (34 bytes each)
    # . and .. entries
    num_dir_entries = 2
    dir_entries_size = num_dir_entries * 34
    
    # File entries
    num_file_entries = len(files)
    file_entries_size = num_file_entries * 34
    
    # Total directory area (root + file entries)
    total_dir_size = dir_entries_size + file_entries_size
    
    # Layout:
    # Sectors 0-15: System area (zeros)
    # Sector 16: Primary Volume Descriptor (PVD)
    # Sector 17: Root directory (. and .. entries)
    # Sector 18+: File directory entries
    # After entries: File data
    
    pvd_sector = 16
    root_dir_sector = 17
    file_entries_sector = 18
    
    # Calculate where file data starts
    # Root dir takes 1 sector (sector 17)
    # File entries start at sector 18
    # Each entry is 34 bytes, so we need to calculate exact offset
    file_entries_offset = file_entries_sector * SECTOR
    file_data_start_offset = file_entries_offset + file_entries_size
    
    # Round up to sector boundary
    file_data_start_offset = (file_data_start_offset + SECTOR - 1) // SECTOR * SECTOR
    file_data_start_sector = file_data_start_offset // SECTOR
    
    total_size = file_data_start_offset + total_data
    total_size = (total_size + SECTOR - 1) // SECTOR * SECTOR
    
    print(f"\nISO Layout:")
    print(f"  System area: sectors 0-{pvd_sector-1}")
    print(f"  PVD: sector {pvd_sector}")
    print(f"  Root dir: sector {root_dir_sector}")
    print(f"  File entries: sector {file_entries_sector}")
    print(f"  File data: sector {file_data_start_sector}")
    print(f"  Total: {total_size // SECTOR} sectors ({total_size/1024/1024:.2f} MB)")
    
    # Create ISO
    iso = bytearray(total_size)
    
    # === PVD (sector 16) ===
    pvd = bytearray(SECTOR)
    pvd[0] = 2  # Type: Primary Volume Descriptor
    pvd[1:6] = b'CD001'
    pvd[6] = 1
    pvd[41:73] = b'PLAYSTATION 2'
    pvd[73:105] = b'SLUS-20001 FNWF'
    struct.pack_into('<Q', pvd, 129, total_size // SECTOR)
    struct.pack_into('<Q', pvd, 155, total_size // SECTOR)
    struct.pack_into('<H', pvd, 163, SECTOR)
    iso[16*SECTOR:17*SECTOR] = pvd
    
    # === Root Directory (sector 17) ===
    root_offset = root_dir_sector * SECTOR
    
    # Entry for . (offset 0-33)
    iso[root_offset] = 34  # Length
    struct.pack_into('<I', iso, root_offset+1, root_dir_sector)  # Extent
    struct.pack_into('<I', iso, root_offset+5, total_dir_size)  # Size
    iso[root_offset+9] = 90  # Date
    iso[root_offset+16] = 0x03  # Flags: directory
    iso[root_offset+21] = 1  # Filename length
    iso[root_offset+22] = ord('.')  # Filename: "."
    
    # Entry for .. (offset 34-67)
    iso[root_offset+34] = 34
    struct.pack_into('<I', iso, root_offset+35, pvd_sector)  # Extent = PVD sector
    struct.pack_into('<I', iso, root_offset+39, SECTOR)  # Size
    iso[root_offset+43] = 90
    iso[root_offset+50] = 0x02  # Flags
    iso[root_offset+55] = 2  # Filename length
    iso[root_offset+56] = ord('.')
    iso[root_offset+57] = ord('.')
    
    # === File Entries (sector 18+) ===
    entry_offset = file_entries_sector * SECTOR
    
    # File data starts after all directory entries
    file_data_offset = entry_offset + file_entries_size
    
    for rel, data in files:
        name = os.path.basename(rel).split(';')[0][:31]
        name_len = len(name)
        
        # Directory entry
        iso[entry_offset] = 34
        struct.pack_into('<I', iso, entry_offset+1, file_data_offset // SECTOR)
        struct.pack_into('<I', iso, entry_offset+5, len(data))
        iso[entry_offset+9] = 90
        iso[entry_offset+16] = 0x00  # Flags: file
        iso[entry_offset+21] = name_len
        for i, c in enumerate(name):
            iso[entry_offset+22+i] = ord(c)
        entry_offset += 34
        
        # File data
        iso[file_data_offset:file_data_offset+len(data)] = data
        file_data_offset += len(data)
    
    # Write ISO
    with open(output_path, 'wb') as f:
        f.write(iso)
    
    print(f"\n✅ ISO created: {output_path}")
    print(f"📊 Size: {len(iso)/1024/1024:.2f} MB")


def main():
    src_dir = "/tmp/fnwf-iso"
    output = "/home/renan/Projects/cpp/fnwf/fnwf-ps2.iso"
    
    print("=== Creating PS2 ISO ===")
    print(f"Source: {src_dir}")
    print()
    
    create_ps2_iso(src_dir, output)
    
    # Verify
    print("\n=== Verification ===")
    with open(output, 'rb') as f:
        f.seek(16 * 2048)
        pvd = f.read(256)
        print(f"PVD Type: {pvd[0]} (expected 2)")
        print(f"PVD Sig: {pvd[1:6]}")
        print(f"Volume ID: {pvd[73:105].decode().strip()}")
        
        # Read root dir
        f.seek(17 * 2048)
        root = f.read(68)
        print(f"\nRoot entry (.): len={root[0]}, flags=0x{root[16]:02X}")
        print(f"Root entry (..): len={root[34]}, flags=0x{root[34+16]:02X}")
        
        # Read file entries
        f.seek(18 * 2048)
        print(f"\n=== Files in ISO ===")
        for i in range(25):
            entry = f.read(34)
            if entry[0] != 34 or entry[21] == 0:
                break
            name = entry[22:22+entry[21]].decode('ascii', errors='ignore')
            sector = struct.unpack('<I', entry[1:5])[0]
            size = struct.unpack('<I', entry[5:9])[0]
            print(f"  {name:35s} sector={sector:5d} size={size:8d}")
            
            # Read SYSTEM.CNF content
            if 'SYSTEM' in name:
                f.seek(sector * 2048)
                data = f.read(size)
                print(f"\n  SYSTEM.CNF content:")
                for line in data.decode('ascii', errors='ignore').split('\n'):
                    if line.strip():
                        print(f"    {line}")


if __name__ == "__main__":
    main()
