#!/usr/bin/env python3
"""
Create a PS2-compatible ISO9660 image manually.
This creates a minimal ISO9660 filesystem that the PS2 can read.
"""

import struct
import os
import sys
from pathlib import Path

class ISO9660Creator:
    def __init__(self):
        self.files = []
        self.directories = [("/", [])]
        
    def add_file(self, path, data):
        """Add a file to the ISO"""
        self.files.append((path, data))
        
    def add_directory(self, path):
        """Add a directory to the ISO"""
        # Check if directory already exists
        for i, (p, _) in enumerate(self.directories):
            if p == path:
                return i
        self.directories.append((path, []))
        return len(self.directories) - 1
    
    def generate_system_area(self):
        """Generate the system area (first 16 sectors)"""
        # Primary Volume Descriptor
        pvd = bytearray()
        pvd += struct.pack('B', 1)  # Type: Primary Volume Descriptor
        pvd += b'CD001'  # Standard Identifier
        pvd += struct.pack('B', 1)  # Version
        pvd += bytes([0] * 40)  # Unused
        pvd += b'FNWF PS2'  # System Identifier (32 bytes)
        pvd += b'FIVE NIGHTS WITH FRIENDS'  # Volume Identifier (32 bytes)
        pvd += bytes([0] * 8)  # Unused
        pvd += struct.pack('<Q', 0)  # Volume Size (sectors)
        pvd += bytes([0] * 32768)  # Pad to sector size
        
        return bytes(pvd[:2048])
    
    def generate_boot_catalog(self):
        """Generate boot catalog for El Torito"""
        catalog = bytearray()
        catalog += bytes([0x01])  # Boot indicator
        catalog += bytes([0x00])  # Boot media type
        catalog += struct.pack('<H', 0x0000)  # Load segment
        catalog += struct.pack('<H', 0x0000)  # System type
        # ... rest of boot catalog
        catalog += bytes([0] * (2048 - len(catalog)))
        return bytes(catalog[:2048])
    
    def generate_pvd(self, volume_size):
        """Generate Primary Volume Descriptor"""
        pvd = bytearray()
        pvd += struct.pack('B', 2)  # Type: Primary Volume Descriptor
        pvd += b'CD001'  # Standard Identifier
        pvd += struct.pack('B', 1)  # Version
        pvd += bytes([0] * 40)  # Unused
        pvd += b'FNWFPS2'  # System Identifier (32 bytes)
        pvd += b'FIVE NIGHTS'  # Volume Identifier (32 bytes)
        pvd += bytes([0] * 8)  # Unused
        pvd += struct.pack('<Q', volume_size)  # Volume Size (sectors)
        pvd += struct.pack('<Q', 16)  # Volume Space Size (sectors)
        pvd += struct.pack('<H', 512)  # Sector Size
        pvd += struct.pack('<Q', 16)  # Path Table Location
        pvd += struct.pack('<Q', 17)  # Optional Path Table Location
        pvd += struct.pack('<H', 1)  # LAD size
        pvd += struct.pack('<H', 2)  # Root directory entry
        pvd += bytes([0] * (2048 - len(pvd)))
        return bytes(pvd[:2048])
    
    def generate_root_dir_entry(self):
        """Generate root directory entry"""
        entry = bytearray()
        entry += struct.pack('B', 1)  # Length of extent
        entry += struct.pack('<H', 1)  # Extent start
        entry += struct.pack('<Q', 2048)  # Extent size
        entry += struct.pack('<Q', 0)  # Modification time
        entry += struct.pack('B', 0x1F)  # Flags
        entry += struct.pack('B', 0)  # File unit size
        entry += struct.pack('B', 0)  # Interleave gap size
        entry += struct.pack('<H', 0)  # Volume sequence number
        entry += struct.pack('B', 1)  # Length of filename
        entry += struct.pack('B', 0)  # Name length (reserved)
        entry += b'.'  # Filename
        entry += bytes([0] * (34 - len(entry)))
        return bytes(entry[:34])
    
    def create_iso(self, output_path):
        """Create the ISO file"""
        # Calculate sizes
        header_size = 32 * 2048  # System area + PVD + boot catalog
        file_entries_size = len(self.files) * 34  # Directory entries
        data_start = header_size + file_entries_size
        
        # Create ISO data
        iso_data = bytearray()
        
        # Add system area
        iso_data += self.generate_system_area()
        iso_data += self.generate_boot_catalog()
        
        # Add Primary Volume Descriptor
        iso_data += self.generate_pvd(len(self.files))
        
        # Add padding to data start
        while len(iso_data) < data_start:
            iso_data += b'\x00'
        
        # Add files
        for path, data in self.files:
            iso_data += data
            # Pad to 2048 byte boundary
            while len(iso_data) % 2048 != 0:
                iso_data += b'\x00'
        
        # Write to file
        with open(output_path, 'wb') as f:
            f.write(iso_data)
        
        return len(iso_data)


def main():
    src_dir = "/tmp/fnwf-iso"
    output_path = "/home/renan/Projects/cpp/fnwf/fnwf-ps2.iso"
    
    creator = ISO9660Creator()
    
    # Add files
    for root, dirs, files in os.walk(src_dir):
        for f in files:
            file_path = os.path.join(root, f)
            iso_path = "/" + file_path.replace(src_dir, "").lstrip("/")
            print(f"Adding: {iso_path}")
            
            with open(file_path, 'rb') as fp:
                data = fp.read()
            creator.add_file(iso_path, data)
    
    # Create ISO
    size = creator.create_iso(output_path)
    print(f"\n✅ ISO created: {output_path}")
    print(f"📊 Size: {size / (1024*1024):.2f} MB")


if __name__ == "__main__":
    main()
