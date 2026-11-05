TARGET := iphone:clang:16.5:15.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BluedeckHelper

BluedeckHelper_FILES = Tweak.x
BluedeckHelper_FRAMEWORKS = UIKit
BluedeckHelper_CFLAGS = -fobjc-arc -I../Shared

include $(THEOS_MAKE_PATH)/tweak.mk
