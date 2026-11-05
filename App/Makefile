TARGET := iphone:clang:16.5:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Bluedeck

Bluedeck_FILES = $(wildcard *.m)
Bluedeck_FRAMEWORKS = UIKit CoreGraphics AVFoundation CoreBluetooth
Bluedeck_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I../Shared
Bluedeck_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
