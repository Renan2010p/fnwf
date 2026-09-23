#!/usr/bin/env python3
"""
Create a proper PS2 bootable ISO using manual ISO9660 construction.
PS2 expects specific sector layout and SYSTEM.CNF format.
"""

import struct
import os
import sys

def create_ps2_iso(src_dir, output_path):
    """Create a PS2-compatible ISO9660 disc image."""
    
    # Collect all files
    files = []
    for root, dirs, filenames in os.walk(src_dir):
        for f in sorted(filenames):
            path = os.path.join(root, f)
            rel = os.path.relpath(path, src_dir)
            # Convert to uppercase for ISO9660
            rel_upper = rel.upper()
            with open(path, 'rb') as fp:
                data = fp.read()
            files.append((rel_upper, data))
            size_kb = len(data) / 1024
            print(f"  {rel_upper} ({size_kb:.1f} KB)")
    
    # Sort files for consistent ordering
    files.sort(key=lambda x: x[0])
    
    SECTOR = 2048
    
    # Calculate sizes
    total_data = sum(len(f[1]) for f in files)
    num_dirs = len(files) + 2  # . and ..
    dir_data_size = num_dirs * 34
    
    # System area: 16 sectors (0-15)
    # Primary Volume Descriptor: sector 16
    # Directory records: sector 17+
    # File data: after directories
    
    # Calculate where file data starts
    dir_start_sector = 17
    dir_start_offset = dir_start_sector * SECTOR
    dir_end_offset = dir_start_offset + dir_data_size
    # Round up to sector boundary
    data_start_offset = (dir_end_offset + SECTOR - 1) // SECTOR * SECTOR
    data_start_sector = data_start_offset // SECTOR
    
    total_size = data_start_offset + total_data
    total_size = (total_size + SECTOR - 1) // SECTOR * SECTOR
    
    print(f"\nISO layout:")
    print(f"  System area: sectors 0-15")
    print(f"  PVD: sector 16")
    print(f"  Directories: sector {dir_start_sector}")
    print(f"  Data: sector {data_start_sector}")
    print(f"  Total: {total_size // SECTOR} sectors ({total_size/1024/1024:.2f} MB)")
    
    # Create ISO data
    iso = bytearray(total_size)
    
    # === PRIMARY VOLUME DESCRIPTOR (sector 16) ===
    pvd = bytearray(SECTOR)
    pvd[0] = 2  # Type: Primary Volume Descriptor
    pvd[1:6] = b'CD001'  # Standard identifier
    pvd[6] = 1  # Version
    # System identifier (bytes 41-72)
    pvd[41:73] = b'PLAYSTATION 2'
    # Volume identifier (bytes 73-104)
    pvd[73:105] = b'FNWF PS2'
    # Volume size (bytes 129-136, little-endian u64)
    struct.pack_into('<Q', pvd, 129, total_size // SECTOR)
    # Volume space size (bytes 155-162)
    struct.pack_into('<Q', pvd, 155, total_size // SECTOR)
    # Sector size (bytes 163-164)
    struct.pack_into('<H', pvd, 163, SECTOR)
    # Path table location (bytes 169-176)
    pt_location = data_start_sector + len(files) + 2
    struct.pack_into('<Q', pvd, 169, pt_location)
    # Optional path table location (bytes 177-184)
    struct.pack_into('<Q', pvd, 177, pt_location)
    # Length of path table (byte 185)
    pvd[185] = 4
    # Path table location (bytes 187-188)
    struct.pack_into('<H', pvd, 187, pt_location)
    
    # Root directory record at offset 328
    root_offset = 328
    pvd[root_offset] = 34  # Length
    struct.pack_into('<I', pvd, root_offset + 1, dir_start_sector)  # Extent
    struct.pack_into('<I', pvd, root_offset + 5, dir_data_size)  # Size
    pvd[root_offset + 9] = 90  # Date year 1900
    pvd[root_offset + 16] = 0x03  # Flags: directory with children
    pvd[root_offset + 21] = 1  # Filename length
    pvd[root_offset + 22] = ord('.')  # Filename: "."
    
    iso[16 * SECTOR : 17 * SECTOR] = pvd
    
    # === DIRECTORY RECORDS (sector 17+) ===
    entry_offset = dir_start_offset
    
    # Root entry (.)
    iso[entry_offset] = 34
    struct.pack_into('<I', iso, entry_offset + 1, dir_start_sector)
    struct.pack_into('<I', iso, entry_offset + 5, dir_data_size)
    iso[entry_offset + 9] = 90
    iso[entry_offset + 16] = 0x03
    iso[entry_offset + 21] = 1
    iso[entry_offset + 22] = ord('.')
    entry_offset += 34
    
    # Parent entry (..)
    iso[entry_offset] = 34
    struct.pack_into('<I', iso, entry_offset + 1, 16)  # Points to PVD sector
    struct.pack_into('<I', iso, entry_offset + 5, SECTOR)
    iso[entry_offset + 9] = 90
    iso[entry_offset + 16] = 0x02
    iso[entry_offset + 21] = 2
    iso[entry_offset + 22] = ord('.')
    iso[entry_offset + 23] = ord('.')
    entry_offset += 34
    
    # File entries
    file_data_offset = entry_offset + len(files) * 34
    
    for rel_path, data in files:
        name = os.path.basename(rel_path).split(';')[0][:31]
        name_len = len(name)
        
        # Directory entry
        iso[entry_offset] = 34
        struct.pack_into('<I', iso, entry_offset + 1, file_data_offset // SECTOR)
        struct.pack_into('<I', iso, entry_offset + 5, len(data))
        iso[entry_offset + 9] = 90
        iso[entry_offset + 16] = 0x00  # Flags: file
        iso[entry_offset + 21] = name_len
        for i, c in enumerate(name):
            iso[entry_offset + 22 + i] = ord(c)
        entry_offset += 34
        
        # File data
        iso[file_data_offset:file_data_offset + len(data)] = data
        file_data_offset += len(data)
    
    # === PATH TABLE (after file data) ===
    pt_offset = file_data_offset
    # Directory entry for root (4 bytes: depth=0, extent=17, parent=0)
    struct.pack_into('<I', iso, pt_offset, (17 << 8) | 0)  # Actually: extent<<8 | depth
    # But PS2 might not need this for basic boot
    
    # Write ISO
    with open(output_path, 'wb') as f:
        f.write(iso)
    
    print(f"\n✅ ISO created: {output_path}")
    print(f"📊 Size: {len(iso) / 1024 / 1024:.2f} MB")
    return output_path


def main():
    src_dir = "/tmp/fnwf-iso"
    output = "/home/renan/Projects/cpp/fnwf/fnwf-ps2.iso"
    
    print("=== Creating PS2 ISO ===")
    print(f"Source: {src_dir}")
    print()
    
    create_ps2_iso(src_dir, output)


if __name__ == "__main__":
    main()
