# shared toolchain settings for every legacyray piece.
#
# this uses the theos toolchain and sdk, but not the theos makefile framework:
# theos refuses project paths with spaces, and the project lives in
# "~/Xcode Projects" so the OS X 10.8 VM can open it over SMB. every rule below
# works on relative paths, so the space in the checkout path never reaches make.
#
# everything is overridable from the environment or the command line:
#   make THEOS=/opt/theos LR_SDK=/opt/theos/sdks/iPhoneOS6.1.sdk

THEOS       ?= $(HOME)/theos
LR_TC       ?= $(THEOS)/toolchain/linux/iphone/bin
LR_SDK      ?= $(THEOS)/sdks/iPhoneOS6.1.sdk
# armv7 covers every device that runs ios 4 through 7 (the 5s runs armv7 too)
LR_IOS_MIN  ?= 4.0
LR_DEPS     ?= $(HOME)/.cache/legacyray-deps
LR_TRIPLE   ?= arm-apple-darwin11

LR_CC       := $(LR_TC)/clang -target $(LR_TRIPLE) -B $(LR_TC)
LR_ARCH     := -arch armv7 -miphoneos-version-min=$(LR_IOS_MIN)
LR_SYSROOT  := -isysroot $(LR_SDK)
LR_LDID     := $(LR_TC)/ldid
LR_STRIP    := $(LR_TC)/strip
LR_OTOOL    := $(LR_TC)/otool

LR_OSSL     ?= $(LR_DEPS)/openssl-armv7
LR_MBED     ?= $(LR_DEPS)/mbedtls-armv7
LR_SSH2  ?= $(LR_DEPS)/libssh2-armv7

# ios 4 dpkg only understands gzip members
LR_DEB_COMPRESSION ?= gzip

ifeq ($(wildcard $(LR_TC)/clang),)
$(error no clang at $(LR_TC): install theos or set THEOS / LR_TC)
endif
ifeq ($(wildcard $(LR_SDK)),)
$(error no sdk at $(LR_SDK): put iPhoneOS6.1.sdk into $(THEOS)/sdks or set LR_SDK)
endif
