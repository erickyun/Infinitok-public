TARGET := iphone:clang:16.5
INSTALL_TARGET_PROCESSES = TikTok
THEOS_DEVICE_IP = 192.168.100.246
THEOS_DEVICE_USER = root
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Infinitok

# Keeps the version shown in Settings in sync with control automatically, instead of a second
# hardcoded copy that could drift out of sync with the .deb's actual version.
INFINITOK_VERSION := $(shell awk -F': ' '/^Version:/{print $$2}' control)

Infinitok_FILES = Tweak.x clean_identity/identity.x clean_identity/CleanIdentityPrefs.m $(wildcard *.m JGProgressHUD/*.m Settings/*.m)
Infinitok_FRAMEWORKS = UIKit Foundation CoreGraphics Photos ImageIO CoreServices SystemConfiguration SafariServices Security QuartzCore
Infinitok_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-unused-value -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-incompatible-pointer-types -Wno-arc-performSelector-leaks -DINFINITOK_VERSION_STRING='"$(INFINITOK_VERSION)"'

include $(THEOS)/makefiles/tweak.mk

after-stage::
	@echo "Staged Infinitok.dylib + layout/Library/Application Support/Infinitok.bundle"
