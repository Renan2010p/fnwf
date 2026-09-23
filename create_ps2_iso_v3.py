#!/usr/bin/env python3
"""
Create a proper PS2-compatible ISO9660 image.
"""

import struct
import os
import sys

class PS2ISOCreator:
    def __init__(self):
        self.sector_size = 2048
        self.files = []
        self.root_extent = 16  # After system area (16 sectors)
        
    def add_file(self, path, data):
        self.files.append((path, data))
        
    def create_pvd(self, volume_size):
        """Create Primary Volume Descriptor at sector 16"""
        pvd = bytearray(self.sector_size)
        
        # Byte 0: Descriptor type (2 = Primary Volume Descriptor)
        pvd[0] = 2
        
        # Bytes 1-5: Standard identifier "CD001"
        pvd[1:6] = b'CD001'
        
        # Byte 6: Version (1)
        pvd[6] = 1
        
        # Bytes 41-72: System identifier (32 bytes)
        pvd[41:73] = b'PLAYSTATION 2'
        
        # Bytes 73-104: Volume identifier (32 bytes)
        pvd[73:105] = b'FNWF PS2'
        
        # Bytes 129-136: Volume size (8 bytes, little-endian)
        struct.pack_into('<Q', pvd, 129, volume_size)
        
        # Bytes 155-162: Volume space size
        struct.pack_into('<Q', pvd, 155, volume_size)
        
        # Bytes 163-166: Sector size
        struct.pack_into('<H', pvd, 163, self.sector_size)
        
        # Bytes 169-176: Path table location
        pt_location = 17 + (len(self.files) + 2)  # After PVD + dir entries
        struct.pack_into('<Q', pvd, 169, pt_location)
        
        # Bytes 177-184: Optional path table location
        struct.pack_into('<Q', pvd, 177, pt_location)
        
        # Bytes 185-186: Length of path table (1 byte)
        pvd[185] = 4
        
        # Bytes 187-188: Path table location (2 bytes)
        struct.pack_into('<H', pvd, 187, pt_location)
        
        # Root directory record at offset 328
        self._write_root_dir_record(pvd, 328, pt_location)
        
        return bytes(pvd)
    
    def _write_root_dir_record(self, data, offset, dir_extent):
        """Write root directory record"""
        # Length of extent descriptor (1 byte)
        data[offset] = 34
        
        # Extent location (4 bytes, little-endian)
        struct.pack_into('<I', data, offset + 1, self.root_extent)
        
        # Extent size (4 bytes) - calculate based on number of files
        dir_size = (len(self.files) + 2) * 34
        struct.pack_into('<I', data, offset + 5, dir_size)
        
        # Date (7 bytes) - 1900-01-01 00:00:00
        for i in range(7):
            data[offset + 9 + i] = 0
        data[offset + 9] = 90  # Year 1900
        
        # Flags (1 byte) - 0x03 = directory with children
        data[offset + 16] = 0x03
        
        # File unit size (1 byte)
        data[offset + 17] = 0
        
        # Interleave gap size (1 byte)
        data[offset + 18] = 0
        
        # Volume sequence number (2 bytes)
        struct.pack_into('<H', data, offset + 19, 1)
        
        # Length of filename (1 byte)
        data[offset + 21] = 1
        
        # Filename (1 byte)
        data[offset + 22] = ord('.')
        
        # Pad remaining bytes to 34
        for i in range(23, 34):
            data[offset + i] = 0
    
    def create_dir_entry(self, name, extent, size, flags=0x02):
        """Create a directory entry (34 bytes)"""
        entry = bytearray(34)
        
        # Length of extent descriptor (1 byte)
        entry[0] = 34
        
        # Extent location (4 bytes, little-endian)
        struct.pack_into('<I', entry, 1, extent)
        
        # Extent size (4 bytes)
        struct.pack_into('<I', entry, 5, size)
        
        # Date (7 bytes) - 1900-01-01 00:00:00
        entry[9] = 90  # Year 1900
        
        # Flags (1 byte)
        entry[16] = flags
        
        # File unit size (1 byte)
        entry[17] = 0
        
        # Interleave gap size (1 byte)
        entry[18] = 0
        
        # Volume sequence number (2 bytes)
        struct.pack_into('<H', entry, 19, 1)
        
        # Length of filename (1 byte)
        name_len = min(len(name), 31)
        entry[21] = name_len
        
        # Filename (max 31 bytes at offset 22-52)
        for i, c in enumerate(name[:31]):
            if 22 + i < 34:
                entry[22 + i] = ord(c)
        
        return bytes(entry)
    
    def create_iso(self, output_path):
        """Create the ISO file"""
        # Calculate total size
        total_data_size = sum(len(f[1]) for f in self.files)
        dir_entries_count = len(self.files) + 2  # +2 for . and ..
        dir_entries_size = dir_entries_count * 34
        
        # Data starts after system area (16 sectors) + PVD (1 sector)
        data_start_sector = 17
        data_start_offset = data_start_sector * self.sector_size
        
        # Directory entries right after PVD
        dir_offset = data_start_offset + self.sector_size
        
        total_size = dir_offset + dir_entries_size + total_data_size
        # Round up to sector boundary
        total_size = ((total_size + self.sector_size - 1) // self.sector_size) * self.sector_size
        
        print(f"Total ISO size: {total_size / (1024*1024):.2f} MB")
        print(f"Data starts at sector {data_start_sector}")
        print(f"Directory entries: {dir_entries_count} x 34 = {dir_entries_size} bytes")
        
        # Create ISO data
        iso_data = bytearray(total_size)
        
        # Primary Volume Descriptor at sector 16
        pvd = self.create_pvd(total_size // self.sector_size)
        iso_data[16 * self.sector_size : 17 * self.sector_size] = pvd
        
        # Directory entries after PVD
        current_offset = 17 * self.sector_size
        
        # Root directory entry (.)
        root_entry = self.create_dir_entry('.', dir_offset // self.sector_size, dir_entries_size, 0x03)
        iso_data[current_offset : current_offset + 34] = root_entry
        current_offset += 34
        
        # Parent directory entry (..) - points to system area
        parent_entry = self.create_dir_entry('..', 0, 16 * self.sector_size, 0x02)
        iso_data[current_offset : current_offset + 34] = parent_entry
        current_offset += 34
        
        # File entries
        file_data_offset = current_offset + dir_entries_size
        for path, data in self.files:
            name = os.path.basename(path)
            size = len(data)
            
            # Directory entry
            entry = self.create_dir_entry(name, file_data_offset // self.sector_size, size, 0x00)
            iso_data[current_offset : current_offset + 34] = entry
            current_offset += 34
            
            # File data
            iso_data[file_data_offset : file_data_offset + size] = data
            file_data_offset += size
        
        # Pad to sector boundary
        while len(iso_data) < total_size:
            iso_data.append(0)
        
        # Write to file
        with open(output_path, 'wb') as f:
            f.write(iso_data)
        
        print(f"\n✅ ISO created: {output_path}")
        print(f"📊 Size: {len(iso_data) / (1024*1024):.2f} MB")


def main():
    src_dir = "/tmp/fnwf-iso"
    output_path = "/home/renan/Projects/cpp/fnwf/fnwf-ps2.iso"
    
    creator = PS2ISOCreator()
    
    # Add files
    for root, dirs, files in os.walk(src_dir):
        for f in sorted(files):
            file_path = os.path.join(root, f)
            rel_path = os.path.relpath(file_path, src_dir)
            print(f"Adding: {rel_path}")
            
            with open(file_path, 'rb') as fp:
                data = fp.read()
            creator.add_file(rel_path, data)
    
    # Create ISO
    creator.create_iso(output_path)


if __name__ == "__main__":
    main()
