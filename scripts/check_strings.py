#!/usr/bin/env python3
"""list the L(@"...") strings in the app sources and the ones LRStrings.inc
has no translation for.   python3 scripts/check_strings.py [--missing]"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'app', 'Sources')
PAT = re.compile(r'L\(@"((?:[^"\\]|\\.)*)"\)')


def keys():
    found = []
    for d, _, files in os.walk(ROOT):
        for f in sorted(files):
            if f.endswith(('.m', '.h')):
                for k in PAT.findall(open(os.path.join(d, f), encoding='utf-8').read()):
                    if k not in found:
                        found.append(k)
    return found


def translated():
    inc = open(os.path.join(ROOT, 'Core', 'LRStrings.inc'), encoding='utf-8').read()
    return set(re.findall(r'^\s*\{\s*"((?:[^"\\]|\\.)*)"', inc, re.M))


if __name__ == '__main__':
    k = keys()
    t = translated()
    missing = [x for x in k if x not in t]
    for x in (missing if '--missing' in sys.argv else k):
        print(x)
    print('%d strings, %d missing' % (len(k), len(missing)), file=sys.stderr)
