#!/usr/bin/env python3
"""parse LegacyRay.xcodeproj/project.pbxproj (old-style plist) and check that
every object reference resolves. a cheap stand-in for opening it in Xcode"""
import os
import re
import sys
from collections import Counter

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'LegacyRay.xcodeproj', 'project.pbxproj')


def tokenize(s):
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if c.isspace():
            i += 1
        elif s.startswith('//', i):
            i = s.index('\n', i) if '\n' in s[i:] else n
        elif s.startswith('/*', i):
            i = s.index('*/', i) + 2
        elif c in '{}()=;,':
            yield c
            i += 1
        elif c == '"':
            j, out = i + 1, []
            while s[j] != '"':
                if s[j] == '\\':
                    out.append(s[j + 1])
                    j += 2
                else:
                    out.append(s[j])
                    j += 1
            yield ('S', ''.join(out))
            i = j + 1
        else:
            m = re.match(r'[A-Za-z0-9_$./\-+:<>]+', s[i:])
            if not m:
                raise SyntaxError('bad character %r at %d' % (c, i))
            yield ('S', m.group(0))
            i += len(m.group(0))


def parse(tokens):
    t = next(tokens)
    if t == '{':
        d = {}
        while True:
            k = next(tokens)
            if k == '}':
                return d
            if next(tokens) != '=':
                raise SyntaxError('expected = after %r' % (k,))
            d[k[1]] = parse(tokens)
            if next(tokens) != ';':
                raise SyntaxError('expected ; after value of %r' % (k,))
    if t == '(':
        a = []
        while True:
            v = parse_or_end(tokens)
            if v is None:
                return a
            a.append(v)
            sep = next(tokens)
            if sep == ')':
                return a
            if sep != ',':
                raise SyntaxError('expected , in array')
    return t[1]


def parse_or_end(tokens):
    t = next(tokens)
    if t == ')':
        return None
    return parse(iter_prepend(t, tokens))


def iter_prepend(first, rest):
    yield first
    yield from rest


def main():
    text = open(PATH, encoding='utf-8').read()
    d = parse(tokenize(text))
    objs = d['objects']
    refkeys = ('fileRef', 'buildConfigurationList', 'mainGroup', 'productRefGroup', 'productReference',
               'children', 'files', 'buildPhases', 'targets', 'buildConfigurations')
    missing = []
    for k, o in objs.items():
        for rk in refkeys:
            v = o.get(rk)
            for ref in (v if isinstance(v, list) else [v] if v else []):
                if ref not in objs:
                    missing.append((o.get('isa'), rk, ref))
    grouped = set()
    for o in objs.values():
        if o['isa'] == 'PBXGroup':
            grouped.update(o['children'])
    orphans = [k for k, o in objs.items() if o['isa'] == 'PBXFileReference' and k not in grouped]
    print('objects: %d  root ok: %s' % (len(objs), d['rootObject'] in objs))
    print(dict(Counter(o['isa'] for o in objs.values())))
    print('dangling references: %d  orphan files: %d' % (len(missing), len(orphans)))
    root = os.path.normpath(os.path.join(os.path.dirname(PATH), '..'))
    # resolve every group path to disk
    parents = {}
    for k, o in objs.items():
        if o['isa'] == 'PBXGroup':
            for c in o['children']:
                parents[c] = k
    def full(k):
        o = objs[k]
        if o.get('sourceTree') not in ('<group>',):
            return None
        p = o.get('path', '')
        par = parents.get(k)
        return os.path.join(full(par) or '', p) if par else p
    absent = []
    for k, o in objs.items():
        if o['isa'] == 'PBXFileReference' and o.get('sourceTree') == '<group>':
            fp = os.path.join(root, full(k))
            if not os.path.exists(fp):
                absent.append(fp)
    print('files missing on disk: %d' % len(absent))
    for a in absent[:10]:
        print('  ', a)
    return 1 if missing or orphans or absent else 0


if __name__ == '__main__':
    sys.exit(main())
