# Makefile for installing GrowlMail
#
# - Build GrowlMail
# - Possibly move old GrowlMail to the Trash
# - Install new GrowlMail
# - Enable the plugin in Mail.
# - Relaunch Mail.

name = GrowlMail

# The build style
# Possible values are Debug and Release
BUILDCONFIGURATION?=Release

all: $(name)

$(name):
	xcodebuild -configuration $(BUILDCONFIGURATION) build
clean:
	xcodebuild clean
dist:
	xcodebuild -configuration $(BUILDCONFIGURATION) -workspace GrowlMail.xcworkspace -scheme "Package GrowlMail" build
