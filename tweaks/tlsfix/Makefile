# legacyraytlsfix.dylib: modern tls roots and the connect() proxy hook for
# old ios. self-contained on purpose: mobilesubstrate is optional at runtime
include ../../make/config.mk

ifeq ($(wildcard $(LR_MBED)/lib/libmbedtls.a),)
$(error no armv7 mbedtls at $(LR_MBED): run scripts/build_deps.sh first)
endif

BUILD   ?= build
OUT     := $(BUILD)/legacyraytlsfix.dylib
CFLAGS  := -std=c99 -Wall -Wextra -Wno-unused-parameter -O2 -fPIC $(LR_ARCH) $(LR_SYSROOT) \
           -include ../../daemon/legacy_compat.h -I../../daemon \
           -I$(LR_MBED)/include -DMBEDTLS_PLATFORM_MS_TIME_ALT
LDFLAGS := $(LR_ARCH) $(LR_SYSROOT) -dynamiclib -Wl,-no_warn_inits \
           -install_name /usr/lib/legacyraytlsfix.dylib \
           -framework Security -framework CoreFoundation
SRC     := fishhook.c stl_gate.c stl_log.c stl_proxy.c stl_roots.c stl_shadow.c \
           stl_trust.c stl_init.c ms_time_ios.c builtins.c ../../daemon/legacy_ios.c
LIBS    := $(LR_MBED)/lib/libmbedtls.a $(LR_MBED)/lib/libmbedx509.a \
           $(LR_MBED)/lib/libmbedcrypto.a

.PHONY: all clean
all: $(OUT)

$(OUT): $(SRC)
	@mkdir -p $(BUILD)
	$(LR_CC) $(CFLAGS) $(SRC) -o $@ $(LDFLAGS) $(LIBS)
	$(LR_STRIP) -x $@
	$(LR_LDID) -S $@

clean:
	rm -rf $(BUILD)
