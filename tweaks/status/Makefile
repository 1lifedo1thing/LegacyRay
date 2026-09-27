# legacyraystatus.dylib: the vpn badge in the springboard status bar
include ../../make/config.mk

BUILD   ?= build
OUT     := $(BUILD)/legacyraystatus.dylib
CFLAGS  := -fno-objc-arc -Wall -Wextra -Wno-unused-parameter -O2 -fPIC $(LR_ARCH) $(LR_SYSROOT)
LDFLAGS := $(LR_ARCH) $(LR_SYSROOT) -dynamiclib -Wl,-no_warn_inits \
           -install_name /usr/lib/legacyraystatus.dylib \
           -framework Foundation -framework UIKit -framework CoreFoundation -lobjc

.PHONY: all clean
all: $(OUT)

$(OUT): legacyray_status.m
	@mkdir -p $(BUILD)
	$(LR_CC) $(CFLAGS) legacyray_status.m -o $@ $(LDFLAGS)
	$(LR_STRIP) -x $@
	$(LR_LDID) -S $@

clean:
	rm -rf $(BUILD)
