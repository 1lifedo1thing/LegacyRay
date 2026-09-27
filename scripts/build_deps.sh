#!/usr/bin/env bash
# fetch and build the static libraries legacyrayd and the tls hook link against.
# everything lands in ~/.cache/legacyray-deps (override with LR_DEPS), so a
# clean checkout rebuilds it with one command and nothing is installed
# system-wide.
#
#   scripts/build_deps.sh            armv7 openssl + mbedtls for the device
#   scripts/build_deps.sh host       also a host openssl for `make -C tests test`
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
THEOS="${THEOS:-$HOME/theos}"
TC="${LR_TC:-${THEOS}/toolchain/linux/iphone/bin}"
SDK="${LR_SDK:-${THEOS}/sdks/iPhoneOS6.1.sdk}"
MIN="${LR_IOS_MIN:-4.0}"
# openssl and mbedtls makefiles cannot cope with spaces, and the project
# usually lives in "~/Xcode Projects", so the default is outside the tree
DEPS="${LR_DEPS:-${XDG_CACHE_HOME:-$HOME/.cache}/legacyray-deps}"
OPENSSL_VERSION="${OPENSSL_VERSION:-3.5.8}"
MBEDTLS_VERSION="${MBEDTLS_VERSION:-3.6.7}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

[[ -x "${TC}/clang" ]] || { echo "no clang in ${TC}; set THEOS or LR_TC" >&2; exit 1; }
[[ -d "${SDK}" ]] || { echo "no sdk at ${SDK}; set LR_SDK" >&2; exit 1; }

mkdir -p "${DEPS}/src"

fetch() {
  local url="$1" out="$2"
  [[ -f "${out}" ]] && return 0
  echo "==> fetch ${url}"
  curl -fL --retry 3 -o "${out}.part" "${url}"
  mv "${out}.part" "${out}"
}

unpack() {
  local archive="$1" dir="$2"
  [[ -d "${dir}" ]] && return 0
  mkdir -p "${dir}.tmp"
  tar -xf "${archive}" -C "${dir}.tmp" --strip-components=1
  mv "${dir}.tmp" "${dir}"
}

# one wrapper per target keeps the cross flags out of every configure script
wrap_cc() {
  local out="$1"
  cat > "${out}" <<W
#!/bin/sh
exec "${TC}/clang" -target arm-apple-darwin11 -B "${TC}" -arch armv7 \\
  -miphoneos-version-min=${MIN} -isysroot "${SDK}" "\$@"
W
  chmod +x "${out}"
}

OSSL_TGZ="${DEPS}/src/openssl-${OPENSSL_VERSION}.tar.gz"
OSSL_SRC="${DEPS}/src/openssl-${OPENSSL_VERSION}"
fetch "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" "${OSSL_TGZ}"
unpack "${OSSL_TGZ}" "${OSSL_SRC}"

MBED_TBZ="${DEPS}/src/mbedtls-${MBEDTLS_VERSION}.tar.bz2"
MBED_SRC="${DEPS}/src/mbedtls-${MBEDTLS_VERSION}"
fetch "https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-${MBEDTLS_VERSION}/mbedtls-${MBEDTLS_VERSION}.tar.bz2" "${MBED_TBZ}"
unpack "${MBED_TBZ}" "${MBED_SRC}"

build_openssl_armv7() {
  local prefix="${DEPS}/openssl-armv7"
  local marker="${prefix}/.built-${OPENSSL_VERSION}-ios${MIN}"
  if [[ -f "${marker}" ]]; then echo "openssl armv7 up to date"; return; fi
  local bld="${DEPS}/build/openssl-armv7"
  rm -rf "${bld}" "${prefix}"
  mkdir -p "${bld}" "${prefix}/lib"
  wrap_cc "${bld}/cc"
  echo "==> openssl ${OPENSSL_VERSION} armv7 (iOS ${MIN}+)"
  (
    cd "${bld}"
    # ios-cross wants CROSS_TOP/CROSS_SDK; point them at the theos sdk
    mkdir -p cross/SDKs
    ln -sfn "${SDK}" cross/SDKs/iPhoneOS.sdk
    export CROSS_TOP="${bld}/cross" CROSS_SDK="iPhoneOS.sdk"
    # no-asm: the perlasm armv7 paths assume a newer assembler than old ios
    # accepts; no-async: ucontext is missing from the ios sdk
    "${OSSL_SRC}/Configure" ios-cross \
      "CC=${bld}/cc" "AR=${TC}/llvm-ar" "RANLIB=${TC}/llvm-ranlib" \
      no-asm no-async no-shared no-dso no-tests no-engine no-ui-console \
      no-docs no-apps no-quic no-comp -DBROKEN_CLANG_ATOMICS \
      -O2 -fno-strict-aliasing --prefix="${prefix}" >/dev/null
    make -j"${JOBS}" build_libs >/dev/null
    cp libssl.a libcrypto.a "${prefix}/lib/"
    mkdir -p "${prefix}/include"
    cp -R "${OSSL_SRC}/include/openssl" "${prefix}/include/"
    cp include/openssl/*.h "${prefix}/include/openssl/"
  )
  touch "${marker}"
}

build_openssl_host() {
  local prefix="${DEPS}/openssl-host"
  local marker="${prefix}/.built-${OPENSSL_VERSION}"
  if [[ -f "${marker}" ]]; then echo "openssl host up to date"; return; fi
  local bld="${DEPS}/build/openssl-host"
  rm -rf "${bld}" "${prefix}"
  mkdir -p "${bld}"
  echo "==> openssl ${OPENSSL_VERSION} host (tests only)"
  (
    cd "${bld}"
    "${OSSL_SRC}/Configure" no-shared no-tests no-docs no-apps \
      --prefix="${prefix}" --libdir=lib >/dev/null
    make -j"${JOBS}" build_libs >/dev/null
    make install_dev >/dev/null
  )
  touch "${marker}"
}

build_mbedtls_armv7() {
  local prefix="${DEPS}/mbedtls-armv7"
  local marker="${prefix}/.built-${MBEDTLS_VERSION}-ios${MIN}"
  if [[ -f "${marker}" ]]; then echo "mbedtls armv7 up to date"; return; fi
  local bld="${DEPS}/build/mbedtls-armv7"
  rm -rf "${bld}" "${prefix}"
  mkdir -p "${bld}" "${prefix}/lib"
  wrap_cc "${bld}/cc"
  echo "==> mbedtls ${MBEDTLS_VERSION} armv7 (iOS ${MIN}+)"
  cp -R "${MBED_SRC}/." "${bld}/src"
  make -C "${bld}/src/library" -j"${JOBS}" \
    CC="${bld}/cc" AR="${TC}/llvm-ar" \
    CFLAGS="-O2 -fPIC -DMBEDTLS_PLATFORM_MS_TIME_ALT" \
    libmbedtls.a libmbedx509.a libmbedcrypto.a >/dev/null
  cp "${bld}/src/library/libmbedtls.a" "${bld}/src/library/libmbedx509.a" \
     "${bld}/src/library/libmbedcrypto.a" "${prefix}/lib/"
  cp -R "${MBED_SRC}/include" "${prefix}/include"
  touch "${marker}"
}

# the xcode daemon targets link openssl from ./deps inside the project, which
# is what the os x vm sees over the shared folder
copy_for_xcode() {
  local dst="${ROOT}/deps/openssl-armv7"
  rm -rf "${dst}"
  mkdir -p "${dst}"
  cp -R "${DEPS}/openssl-armv7/lib" "${DEPS}/openssl-armv7/include" "${dst}/"
}

build_openssl_armv7
build_mbedtls_armv7
if [[ "${1:-}" == "host" ]]; then build_openssl_host; fi
copy_for_xcode
echo "deps ready in ${DEPS} (openssl copied to deps/ for xcode)"
