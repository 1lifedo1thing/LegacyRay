#!/usr/bin/env python3
"""write LegacyRay.xcodeproj for Xcode 4.6 (iOS 6.1 SDK, OS X 10.8).

the project mirrors the make build: the LegacyRay app target and the daemon
tools (legacyrayd, legacyrayctl, legacyray-kick, legacyrayawgd). everything is
armv7 with a 4.3 deployment target (the lowest Xcode 4.6 accepts; the make
build goes down to 4.0). signing is left to ldid, as on a jailbreak build
machine. the daemon targets link the static openssl that
`scripts/build_deps.sh` copies into ./deps.

re-run after adding or removing source files:  python3 scripts/gen_xcodeproj.py
"""
import hashlib
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
PROJ = os.path.join(ROOT, 'LegacyRay.xcodeproj')


def oid(*parts):
    return hashlib.md5('/'.join(parts).encode()).hexdigest()[:24].upper()


def q(s):
    """quote a pbxproj string when it needs it"""
    if re.match(r'^[A-Za-z0-9_./$]+$', s) and s:
        return s
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def ftype(path):
    ext = os.path.splitext(path)[1].lower()
    return {
        '.m': 'sourcecode.c.objc', '.c': 'sourcecode.c.c', '.h': 'sourcecode.c.h',
        '.inc': 'text', '.png': 'image.png', '.wav': 'audio.wav', '.plist': 'text.plist.xml',
        '.txt': 'text', '.pem': 'text',
    }.get(ext, 'text')


def listdir(rel, exts):
    base = os.path.join(ROOT, rel)
    return sorted(f for f in os.listdir(base) if os.path.splitext(f)[1] in exts)


objects = {}          # id -> body string
sections = {}         # isa -> [ids]


def add(isa, ident, body, comment=''):
    objects[ident] = (isa, body, comment)
    sections.setdefault(isa, []).append(ident)
    return ident


# ---------------------------------------------------------------- files
file_refs = {}


def file_ref(path, name=None, source_tree='"<group>"'):
    """path is relative to its group"""
    key = ('file', path, name or '')
    ident = oid(*key)
    if ident in objects:
        return ident
    t = 'folder' if path.endswith('flags') else ftype(path)
    body = '{isa = PBXFileReference; lastKnownFileType = %s; %spath = %s; sourceTree = %s; }' % (
        q(t), ('name = %s; ' % q(name)) if name else '', q(path), source_tree)
    return add('PBXFileReference', ident, body, name or os.path.basename(path))


def group(name, path, children, key):
    ident = oid('group', key)
    body = '{isa = PBXGroup; children = (%s); %s%ssourceTree = "<group>"; }' % (
        ''.join('%s, ' % c for c in children),
        ('name = %s; ' % q(name)) if name else '',
        ('path = %s; ' % q(path)) if path else '')
    return add('PBXGroup', ident, body, name or path)


def build_file(target, ref, flags=None, weak=False):
    ident = oid('build', target, ref)
    settings = []
    if flags:
        settings.append('COMPILER_FLAGS = %s; ' % q(flags))
    if weak:
        settings.append('ATTRIBUTES = (Weak, ); ')
    body = '{isa = PBXBuildFile; fileRef = %s; %s}' % (
        ref, ('settings = {%s}; ' % ''.join(settings)) if settings else '')
    return add('PBXBuildFile', ident, body, objects[ref][2])


# app sources
app_groups = []
app_sources = []
for sub in ['', 'Core', 'Skin', 'Controls', 'Screens', 'iPad']:
    rel = os.path.join('app', 'Sources', sub) if sub else os.path.join('app', 'Sources')
    names = listdir(rel, ('.m', '.h', '.c', '.inc'))
    refs = []
    for n in names:
        ident = oid('file', rel, n)
        t = ftype(n)
        objects[ident] = ('PBXFileReference',
                          '{isa = PBXFileReference; lastKnownFileType = %s; path = %s; sourceTree = "<group>"; }'
                          % (q(t), q(n)), n)
        sections.setdefault('PBXFileReference', []).append(ident)
        refs.append(ident)
        if n.endswith(('.m', '.c')):
            app_sources.append(ident)
    if sub:
        app_groups.append(group(sub, sub, refs, 'app-' + sub))
    else:
        top_app_files = refs
sources_group = group('Sources', 'app/Sources', app_groups + top_app_files, 'app-sources')

# resources
res_rel = os.path.join('app', 'Resources')
res_refs, res_build = [], []
for n in listdir(res_rel, ('.png', '.wav', '.txt', '.plist')):
    ident = oid('file', res_rel, n)
    objects[ident] = ('PBXFileReference', '{isa = PBXFileReference; lastKnownFileType = %s; path = %s; sourceTree = "<group>"; }'
                      % (q(ftype(n)), q(n)), n)
    sections.setdefault('PBXFileReference', []).append(ident)
    res_refs.append(ident)
    if n.endswith(('.png', '.wav', '.txt')):
        res_build.append(ident)
for folder in ('flags', 'server'):
    folder_ref = oid('file', res_rel, folder)
    objects[folder_ref] = ('PBXFileReference', '{isa = PBXFileReference; lastKnownFileType = folder; path = %s; sourceTree = "<group>"; }' % folder, folder)
    sections['PBXFileReference'].append(folder_ref)
    res_refs.append(folder_ref)
    res_build.append(folder_ref)
resources_group = group('Resources', 'app/Resources', res_refs, 'app-resources')

# shared c from the daemon, compiled into the app
shared = ['b64.c', 'control.c', 'amnezia_bundle.c', 'third_party/cJSON.c']
shared_refs = []
for n in shared:
    ident = oid('file', 'daemon/core', n)
    objects[ident] = ('PBXFileReference', '{isa = PBXFileReference; lastKnownFileType = sourcecode.c.c; name = %s; path = %s; sourceTree = "<group>"; }'
                      % (q(os.path.basename(n)), q(n)), os.path.basename(n))
    sections['PBXFileReference'].append(ident)
    shared_refs.append(ident)
shared_group = group('Shared with the daemon', 'daemon/core', shared_refs, 'app-shared')

# zbar
zbar_files = ['config.c', 'error.c', 'symbol.c', 'image.c', 'refcnt.c', 'img_scanner.c', 'scanner.c',
              'decoder.c', 'misc.c', 'decoder/qr_finder.c', 'qrcode/qrdec.c', 'qrcode/qrdectxt.c',
              'qrcode/rs.c', 'qrcode/isaac.c', 'qrcode/bch15_5.c', 'qrcode/binarize.c', 'qrcode/util.c']
zbar_refs = []
for n in zbar_files:
    ident = oid('file', 'zbar', n)
    objects[ident] = ('PBXFileReference', '{isa = PBXFileReference; lastKnownFileType = sourcecode.c.c; name = %s; path = %s; sourceTree = "<group>"; }'
                      % (q(os.path.basename(n)), q(n)), os.path.basename(n))
    sections['PBXFileReference'].append(ident)
    zbar_refs.append(ident)
zbar_group = group('ZBar', 'app/third_party/zbar/zbar', zbar_refs, 'zbar')

# daemon sources
core = ['vless.c', 'b64.c', 'config.c', 'rules.c', 'dns_msg.c', 'dns_cache.c', 'profiles.c', 'happ.c',
        'happ_crypt5.c', 'third_party/cJSON.c', 'net_safe.c', 'socks5.c', 'senko_trace.c', 'senko_replay.c',
        'senko_upload.c', 'vless_conn.c', 'session.c', 'store.c', 'control.c', 'ctl_engine.c', 'http.c',
        'url.c', 'subfetch.c', 'transport_tcp.c', 'transport_tls.c', 'transport_ws.c', 'transport_xhttp.c',
        'transport_pick.c', 'grpc_core.c', 'h2_core.c', 'hpack.c', 'reality_crypto.c', 'reality_auth.c',
        'tls_clienthello.c', 'tls13_kdf.c', 'tls13_keysched.c', 'tls13_record.c', 'tls13_transcript.c',
        'tls13_handshake.c', 'reality_handshake.c', 'socks5_client.c', 'http_client.c', 'vision.c',
        'awg_config.c', 'awg_handshake.c', 'awg_tunnel.c', 'trojan_client.c', 'shadowsocks_client.c',
        'blake2b256.c', 'geo.c', 'frag.c']
daemon_main = ['dialer.c', 'loop.c', 'pf_natlook.c', 'ctl_server.c', 'daemon_ctl.c', 'storefile.c',
               'netwatch.c', 'geo_ctl.c', 'settings.c', 'status.c', 'routing.c', 'routing_exec.c',
               'routing_fwd.c', 'pf_table.c', 'c_backend.c', 'go_config.c', 'go_backend.c', 'awg_utun.c',
               'awg_route.c', 'awg_pfroute.c', 'legacy_ios.c', 'proc_detach.c', 'main.c']
daemon_files = daemon_main + ['senkoctl.c', 'senko_kick.c', 'senkoawgd.c', 'lr_ssh.c', 'legacy_compat.h']
d_refs = {}
for n in core:
    ident = oid('file', 'daemon-core', n)
    objects[ident] = ('PBXFileReference', '{isa = PBXFileReference; lastKnownFileType = sourcecode.c.c; name = %s; path = %s; sourceTree = "<group>"; }'
                      % (q(os.path.basename(n)), q(n)), os.path.basename(n))
    sections['PBXFileReference'].append(ident)
    d_refs['core/' + n] = ident
core_group = group('core', 'core', [d_refs['core/' + n] for n in core], 'daemon-core')
top_d = []
for n in daemon_files:
    ident = oid('file', 'daemon', n)
    objects[ident] = ('PBXFileReference', '{isa = PBXFileReference; lastKnownFileType = %s; path = %s; sourceTree = "<group>"; }'
                      % (q(ftype(n)), q(n)), n)
    sections['PBXFileReference'].append(ident)
    d_refs[n] = ident
    top_d.append(ident)
daemon_group = group('Daemon', 'daemon', [core_group] + top_d, 'daemon')

# frameworks
fw_names = [('UIKit', False), ('Foundation', False), ('CoreGraphics', False), ('QuartzCore', False),
            ('CFNetwork', False), ('SystemConfiguration', False), ('AudioToolbox', False),
            ('MessageUI', False), ('AVFoundation', True), ('CoreMedia', True), ('CoreVideo', True)]
fw_refs = []
for name, weak in fw_names:
    ident = oid('framework', name)
    objects[ident] = ('PBXFileReference', '{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = %s.framework; path = System/Library/Frameworks/%s.framework; sourceTree = SDKROOT; }'
                      % (name, name), name + '.framework')
    sections['PBXFileReference'].append(ident)
    fw_refs.append((ident, weak))
lib_refs = []
for lib in ('libz.dylib', 'libiconv.dylib'):
    ident = oid('lib', lib)
    objects[ident] = ('PBXFileReference', '{isa = PBXFileReference; lastKnownFileType = "compiled.mach-o.dylib"; name = %s; path = usr/lib/%s; sourceTree = SDKROOT; }'
                      % (lib, lib), lib)
    sections['PBXFileReference'].append(ident)
    lib_refs.append(ident)
frameworks_group = group('Frameworks', None, [r for r, _ in fw_refs] + lib_refs, 'frameworks')

# products
products = {}
for name, kind in (('LegacyRay.app', 'wrapper.application'), ('legacyrayd', 'compiled.mach-o.executable'),
                   ('legacyrayctl', 'compiled.mach-o.executable'), ('legacyray-kick', 'compiled.mach-o.executable'),
                   ('legacyrayawgd', 'compiled.mach-o.executable'), ('legacyray-ssh', 'compiled.mach-o.executable')):
    ident = oid('product', name)
    objects[ident] = ('PBXFileReference', '{isa = PBXFileReference; explicitFileType = %s; includeInIndex = 0; path = %s; sourceTree = BUILT_PRODUCTS_DIR; }'
                      % (q(kind), q(name)), name)
    sections['PBXFileReference'].append(ident)
    products[name] = ident
products_group = group('Products', None, list(products.values()), 'products')

main_group = group(None, None, [sources_group, resources_group, shared_group, zbar_group, daemon_group,
                                frameworks_group, products_group], 'main')

# ---------------------------------------------------------------- targets
FAKESIGN = ('if which ldid >/dev/null 2>&1; then\\n'
            '  ldid -S\\"${SRCROOT}/app/Resources/entitlements.plist\\" \\"${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}\\"\\n'
            'else\\n  echo \\"warning: ldid not found; sign on the device with ldid -S before running\\"\\nfi')


def phase(isa, key, files, extra=''):
    ident = oid('phase', key)
    body = '{isa = %s; buildActionMask = 2147483647; files = (%s); %srunOnlyForDeploymentPostprocessing = 0; }' % (
        isa, ''.join('%s, ' % f for f in files), extra)
    return add(isa, ident, body, isa.replace('PBX', '').replace('BuildPhase', ''))


def script(key, name, text):
    ident = oid('script', key)
    body = ('{isa = PBXShellScriptBuildPhase; buildActionMask = 2147483647; files = (); inputPaths = (); '
            'name = %s; outputPaths = (); runOnlyForDeploymentPostprocessing = 0; shellPath = /bin/sh; '
            'shellScript = "%s"; showEnvVarsInLog = 0; }') % (q(name), text)
    return add('PBXShellScriptBuildPhase', ident, body, name)


def config(key, name, settings):
    ident = oid('config', key, name)
    lines = []
    for k in sorted(settings):
        v = settings[k]
        if isinstance(v, list):
            lines.append('%s = (%s);' % (k, ''.join('%s, ' % q(x) for x in v)))
        else:
            lines.append('%s = %s;' % (k, q(v)))
    body = '{isa = XCBuildConfiguration; buildSettings = {%s}; name = %s; }' % (' '.join(lines), name)
    return add('XCBuildConfiguration', ident, body, name)


def config_list(key, debug, release, comment):
    ident = oid('configlist', key)
    body = ('{isa = XCConfigurationList; buildConfigurations = (%s, %s, ); defaultConfigurationIsVisible = 0; '
            'defaultConfigurationName = Release; }') % (debug, release)
    return add('XCConfigurationList', ident, body, comment)


def target(name, product, product_type, phases, settings):
    d = config('t-' + name, 'Debug', dict(settings, GCC_OPTIMIZATION_LEVEL='0'))
    r = config('t-' + name, 'Release', dict(settings))
    cl = config_list('t-' + name, d, r, 'Build configuration list for PBXNativeTarget "%s"' % name)
    ident = oid('target', name)
    body = ('{isa = PBXNativeTarget; buildConfigurationList = %s; buildPhases = (%s); buildRules = (); '
            'dependencies = (); name = %s; productName = %s; productReference = %s; productType = %s; }') % (
        cl, ''.join('%s, ' % p for p in phases), q(name), q(name), products[product], q(product_type))
    return add('PBXNativeTarget', ident, body, name)


zbar_flags = '-w -DSENKO_ZBAR_IOS'
app_src_build = [build_file('app', r) for r in app_sources] + \
                [build_file('app', r) for r in shared_refs] + \
                [build_file('app', r, flags=zbar_flags) for r in zbar_refs]
app_fw_build = [build_file('app', r, weak=w) for r, w in fw_refs] + [build_file('app', r) for r in lib_refs]
app_res_build = [build_file('app', r) for r in res_build]
MARK_IOS7 = ('python \\"${SRCROOT}/scripts/set_sdk_version.py\\" '
             '\\"${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}\\" 7.0')
app_phases = [phase('PBXSourcesBuildPhase', 'app-src', app_src_build),
              phase('PBXFrameworksBuildPhase', 'app-fw', app_fw_build),
              phase('PBXResourcesBuildPhase', 'app-res', app_res_build),
              script('app-ios7', 'Mark for iOS 7', MARK_IOS7),
              script('app-sign', 'Fakesign with ldid', FAKESIGN)]
S = '"$(SRCROOT)'
app_headers = [S + '/app/third_party/zbar/include"', S + '/app/third_party/zbar/zbar"',
               S + '/app/third_party/zbar/zbar/decoder"', S + '/app/third_party/zbar/zbar/qrcode"'] + \
              [S + '/app/Sources' + ('/' + d if d else '') + '"' for d in ('', 'Core', 'Skin', 'Controls', 'Screens', 'iPad')] + \
              [S + '/daemon/core"', S + '/daemon/core/third_party"', S + '/common"']
app_target = target('LegacyRay', 'LegacyRay.app', 'com.apple.product-type.application', app_phases, {
    'INFOPLIST_FILE': 'app/Resources/Info.plist',
    'PRODUCT_NAME': 'LegacyRay',
    'WRAPPER_EXTENSION': 'app',
    'GCC_PREFIX_HEADER': 'app/Sources/LRPrefix.h',
    'GCC_PRECOMPILE_PREFIX_HEADER': 'NO',
    'HEADER_SEARCH_PATHS': app_headers,
    'USE_HEADERMAP': 'NO',
    'TARGETED_DEVICE_FAMILY': '1,2',
})

DAEMON_FLAGS = ['-DSENKO_RELEASE', '-include', S + '/daemon/legacy_compat.h"']
daemon_headers = [S + '/daemon/core"', S + '/daemon/core/third_party"', S + '/daemon"', S + '/common"',
                  S + '/deps/openssl-armv7/include"']
OSSL_LIBS = [S + '/deps/openssl-armv7/lib/libssl.a"', S + '/deps/openssl-armv7/lib/libcrypto.a"', '-lz']


def tool(name, files, libs, extra_headers=()):
    src = [build_file(name, d_refs[f]) for f in files]
    phases = [phase('PBXSourcesBuildPhase', name + '-src', src),
              phase('PBXFrameworksBuildPhase', name + '-fw', []),
              script(name + '-sign', 'Fakesign with ldid', FAKESIGN.replace('${EXECUTABLE_PATH}', '${EXECUTABLE_NAME}'))]
    return target(name, name, 'com.apple.product-type.tool', phases, {
        'PRODUCT_NAME': name,
        'GCC_C_LANGUAGE_STANDARD': 'c99',
        'HEADER_SEARCH_PATHS': daemon_headers + list(extra_headers),
        'OTHER_CFLAGS': DAEMON_FLAGS,
        'OTHER_LDFLAGS': libs,
        'USE_HEADERMAP': 'NO',
        'SKIP_INSTALL': 'YES',
    })


core_all = ['core/' + c for c in core if c != 'awg_tunnel.c']
daemon_targets = [
    tool('legacyrayd', core_all + daemon_main, OSSL_LIBS),
    tool('legacyrayctl', ['senkoctl.c', 'core/b64.c'], []),
    tool('legacyray-kick', ['senko_kick.c'], []),
    tool('legacyrayawgd', ['senkoawgd.c', 'awg_utun.c', 'awg_route.c', 'awg_pfroute.c', 'core/awg_config.c',
                           'core/awg_handshake.c', 'core/awg_tunnel.c', 'core/b64.c', 'core/reality_crypto.c',
                           'status.c', 'legacy_ios.c', 'proc_detach.c'], OSSL_LIBS),
    tool('legacyray-ssh', ['lr_ssh.c', 'core/b64.c'],
         [S + '/deps/libssh2-armv7/lib/libssh2.a"', S + '/deps/openssl-armv7/lib/libcrypto.a"'],
         [S + '/deps/libssh2-armv7/include"']),
]

project_settings = {
    'ALWAYS_SEARCH_USER_PATHS': 'NO',
    'ARCHS': 'armv7',
    'VALID_ARCHS': 'armv7 armv7s',
    'IPHONEOS_DEPLOYMENT_TARGET': '4.3',
    'SDKROOT': 'iphoneos',
    'CLANG_ENABLE_OBJC_ARC': 'NO',
    'GCC_C_LANGUAGE_STANDARD': 'gnu99',
    'CODE_SIGN_IDENTITY': '',
    'CODE_SIGNING_REQUIRED': 'NO',
    'GCC_WARN_ABOUT_RETURN_TYPE': 'YES',
    'GCC_WARN_UNUSED_VARIABLE': 'YES',
    'COPY_PHASE_STRIP': 'NO',
    'DEAD_CODE_STRIPPING': 'YES',
    'GCC_OPTIMIZATION_LEVEL': 's',
}
pd = config('project', 'Debug', dict(project_settings, GCC_OPTIMIZATION_LEVEL='0', ONLY_ACTIVE_ARCH='YES'))
pr = config('project', 'Release', dict(project_settings, VALIDATE_PRODUCT='NO'))
pcl = config_list('project', pd, pr, 'Build configuration list for PBXProject "LegacyRay"')
project_id = oid('project')
all_targets = [app_target] + daemon_targets
add('PBXProject', project_id,
    ('{isa = PBXProject; attributes = {LastUpgradeCheck = 0460; ORGANIZATIONNAME = LegacyRay; }; '
     'buildConfigurationList = %s; compatibilityVersion = "Xcode 3.2"; developmentRegion = English; '
     'hasScannedForEncodings = 0; knownRegions = (en, ru, ); mainGroup = %s; productRefGroup = %s; '
     'projectDirPath = ""; projectRoot = ""; targets = (%s); }') % (
        pcl, main_group, products_group, ''.join('%s, ' % t for t in all_targets)),
    'Project object')

# ---------------------------------------------------------------- write
ORDER = ['PBXBuildFile', 'PBXFileReference', 'PBXFrameworksBuildPhase', 'PBXGroup', 'PBXNativeTarget',
         'PBXProject', 'PBXResourcesBuildPhase', 'PBXShellScriptBuildPhase', 'PBXSourcesBuildPhase',
         'XCBuildConfiguration', 'XCConfigurationList']
out = ['// !$*UTF8*$!', '{', '\tarchiveVersion = 1;', '\tclasses = {', '\t};', '\tobjectVersion = 46;',
       '\tobjects = {', '']
for isa in ORDER:
    ids = sorted(set(sections.get(isa, [])))
    if not ids:
        continue
    out.append('/* Begin %s section */' % isa)
    for ident in ids:
        _, body, comment = objects[ident]
        out.append('\t\t%s /* %s */ = %s;' % (ident, (comment or '').replace('*/', ''), body))
    out.append('/* End %s section */' % isa)
    out.append('')
out += ['\t};', '\trootObject = %s /* Project object */;' % project_id, '}', '']
os.makedirs(PROJ, exist_ok=True)
with open(os.path.join(PROJ, 'project.pbxproj'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))
os.makedirs(os.path.join(PROJ, 'project.xcworkspace'), exist_ok=True)
with open(os.path.join(PROJ, 'project.xcworkspace', 'contents.xcworkspacedata'), 'w') as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n<Workspace\n   version = "1.0">\n'
            '   <FileRef\n      location = "self:LegacyRay.xcodeproj">\n   </FileRef>\n</Workspace>\n')
print('wrote', os.path.relpath(PROJ, ROOT), '(%d objects)' % len(objects))
