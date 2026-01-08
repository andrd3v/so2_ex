ARCHS := arm64
TARGET := iphone:clang:16.5
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
INSTALL_TARGET_PROCESSES := crepware

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := crepware

$(APPLICATION_NAME)_USE_MODULES := 0
$(APPLICATION_NAME)_FILES += $(wildcard sources/*.mm sources/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard sources/KIF/*.mm sources/KIF/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard esp/drawing_view/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard esp/drawing_view/*.mm)
$(APPLICATION_NAME)_FILES += $(wildcard esp/drawing_view/*.cpp)
$(APPLICATION_NAME)_FILES += $(wildcard esp/helpers/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard esp/helpers/*.mm)
$(APPLICATION_NAME)_FILES += $(wildcard esp/unity_api/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard esp/unity_api/*.mm)

#$(APPLICATION_NAME)_CFLAGS += -mllvm -enable-acdobf -mllvm -bcf_cond_compl=2 -mllvm -bcf_prob=40 -mllvm -bcf_loop=5 -mllvm -enable-strcry -mllvm -bcf_junkasm -mllvm -bcf_junkasm_minnum=1 -mllvm -bcf_junkasm_maxnum=2 -mllvm -enable-adb

# -mllvm -enable-funcwra  -mllvm -enable-indibran -mllvm -enable-constenc 

sources/KIF/UITouch-KIFAdditions.m_CFLAGS := $(filter-out -mllvm -enable-fco,$(crepware_CFLAGS))

$(APPLICATION_NAME)_CFLAGS += -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-module-import-in-extern-c -Wunused-but-set-variable
$(APPLICATION_NAME)_CFLAGS += -Iheaders
$(APPLICATION_NAME)_CFLAGS += -Isources
$(APPLICATION_NAME)_CFLAGS += -Isources/KIF
$(APPLICATION_NAME)_CFLAGS += -DNOTIFY_DESTROY_HUD="\"dev.metaware.external.hud.destroy\""
$(APPLICATION_NAME)_CFLAGS += -DPID_PATH="@\"/var/mobile/Library/Caches/dev.metaware.external.pid\""
$(APPLICATION_NAME)_CCFLAGS += -std=c++17

$(APPLICATION_NAME)_FRAMEWORKS += CoreGraphics CoreServices QuartzCore IOKit UIKit
$(APPLICATION_NAME)_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices SpringBoardServices
$(APPLICATION_NAME)_CODESIGN_FLAGS += -Slayout/entitlements.plist
$(APPLICATION_NAME)_RESOURCE_DIRS = ./layout/Resources

include $(THEOS_MAKE_PATH)/application.mk

include $(THEOS_MAKE_PATH)/aggregate.mk


after-package::
	@sudo rm -r packages
	@mkdir Payload
	@sudo cp -r .theos/_/Applications/$(APPLICATION_NAME).app Payload
	@sudo zip -rq $(APPLICATION_NAME).tipa Payload
	@sudo chmod +s Payload/$(APPLICATION_NAME).app/$(APPLICATION_NAME)
	@sudo chown root Payload/$(APPLICATION_NAME).app/$(APPLICATION_NAME)
	@sudo rm -rf Payload
	@mkdir packages
	@sudo mv $(APPLICATION_NAME).tipa packages
	
