TARGET := iphone:clang:16.5:15.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BluedeckSystem

BluedeckSystem_FILES = Tweak.x MixHooks.x SpringBoard.x
BluedeckSystem_FRAMEWORKS = UIKit AVFoundation
BluedeckSystem_CFLAGS = -fobjc-arc -I../Shared

include $(THEOS_MAKE_PATH)/tweak.mk
