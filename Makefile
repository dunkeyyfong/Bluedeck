TARGET := iphone:clang:16.5:15.0
ARCHS = arm64
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += App SettingsHelper

include $(THEOS_MAKE_PATH)/aggregate.mk
