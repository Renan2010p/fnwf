#!/usr/bin/env python3
import os, sys, struct

def asset_key(rel):
    return rel.replace("\\", "/").replace(".", "_").replace("/", "_")

def main():
    assets_dir = sys.argv[1]
    out_hpp = sys.argv[2]
    out_cpp = sys.argv[3]

    files = []
    for root, dirs, fnames in os.walk(assets_dir):
        for fn in fnames:
            full = os.path.join(root, fn)
            rel = os.path.relpath(full, assets_dir).replace("\\", "/")
            files.append((rel, full))

    files.sort()

    with open(out_hpp, "w") as h:
        h.write("#pragma once\n#include <string>\n#include <cstdint>\n\n")
        h.write("namespace embedded {\n")
        h.write("struct Asset { const std::uint8_t* data; std::uint32_t size; };\n")
        h.write("Asset get_asset(const std::string& name);\n")
        h.write("}\n")

    with open(out_cpp, "w") as c:
        c.write('#include "generated/embedded_assets.hpp"\n')
        c.write('#include <string>\n#include <cstdint>\n#include <unordered_map>\n\n')
        c.write("namespace {\n")

        keys = []
        for rel, full in files:
            key = asset_key(rel)
            with open(full, "rb") as f:
                data = f.read()
            c.write(f"static constexpr std::uint8_t {key}[] = {{\n")
            for i in range(0, len(data), 16):
                chunk = data[i:i+16]
                c.write("  " + ", ".join(f"0x{b:02x}" for b in chunk) + ",\n")
            c.write("};\n\n")
            keys.append((key, rel.lower(), len(data)))

        c.write("struct Entry { const char* name; const std::uint8_t* data; std::uint32_t size; };\n")
        c.write("static constexpr Entry entries[] = {\n")
        for key, rel, size in keys:
            c.write(f'  {{"{rel}", {key}, {size}}},\n')
        c.write("};\n")
        c.write("static constexpr int num_entries = sizeof(entries) / sizeof(entries[0]);\n")
        c.write("}  // namespace\n\n")

        c.write("namespace embedded {\n")
        c.write("Asset get_asset(const std::string& name) {\n")
        c.write("  for (int i = 0; i < num_entries; ++i) {\n")
        c.write("    if (name == entries[i].name) return {entries[i].data, entries[i].size};\n")
        c.write("  }\n")
        c.write("  return {nullptr, 0};\n")
        c.write("}\n")
        c.write("}\n")

if __name__ == "__main__":
    main()
