#!/usr/bin/env python
# mark a mach-o as built with a newer sdk than the headers it was compiled
# against. ios 7 looks at the sdk field of LC_VERSION_MIN_IPHONEOS to decide
# whether an app gets the ios 7 behaviour (full screen under the status bar,
# the ios 7 keyboard and swipe-back) or the ios 6 compatibility mode; ios 4-6
# ignore it. run before signing. works with python 2.7 (the os x 10.8 vm) and 3.
#
#   set_sdk_version.py <binary> 7.0
import struct
import sys

LC_VERSION_MIN_IPHONEOS = 0x25
MH_MAGIC, MH_MAGIC_64 = 0xfeedface, 0xfeedfacf
FAT_MAGIC = 0xcafebabe


def encode(text):
    parts = [int(p) for p in text.split('.')] + [0, 0]
    return (parts[0] << 16) | (parts[1] << 8) | parts[2]


def patch_thin(data, base, sdk):
    magic = struct.unpack_from('<I', data, base)[0]
    if magic not in (MH_MAGIC, MH_MAGIC_64):
        raise ValueError('not a little-endian mach-o at %d' % base)
    ncmds = struct.unpack_from('<I', data, base + 16)[0]
    off = base + (32 if magic == MH_MAGIC_64 else 28)
    patched = 0
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', data, off)
        if cmd == LC_VERSION_MIN_IPHONEOS:
            old = struct.unpack_from('<I', data, off + 12)[0]
            if old < sdk:
                struct.pack_into('<I', data, off + 12, sdk)
            patched += 1
        off += size
    return patched


def main():
    if len(sys.argv) != 3:
        sys.stderr.write('usage: set_sdk_version.py <binary> <x.y>\n')
        return 2
    path, sdk = sys.argv[1], encode(sys.argv[2])
    with open(path, 'rb') as f:
        data = bytearray(f.read())
    magic = struct.unpack_from('>I', data, 0)[0]
    patched = 0
    if magic == FAT_MAGIC:
        count = struct.unpack_from('>I', data, 4)[0]
        for i in range(count):
            offset = struct.unpack_from('>I', data, 8 + i * 20 + 8)[0]
            patched += patch_thin(data, offset, sdk)
    else:
        patched = patch_thin(data, 0, sdk)
    if not patched:
        sys.stderr.write('no LC_VERSION_MIN_IPHONEOS in %s\n' % path)
        return 1
    with open(path, 'wb') as f:
        f.write(data)
    return 0


if __name__ == '__main__':
    sys.exit(main())
