TARGET := iphone:clang:16.5:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Bluedeck

# Sources/ is split by feature (Bluetooth, UI/…, Diagnostics); every folder is on the
# include path so headers are imported by name.
SOURCE_DIRS := $(shell find Sources -type d)

Bluedeck_FILES = $(shell find Sources -name '*.m')
Bluedeck_FRAMEWORKS = UIKit CoreGraphics AVFoundation CoreBluetooth
Bluedeck_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I../Shared $(addprefix -I,$(SOURCE_DIRS))
Bluedeck_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
