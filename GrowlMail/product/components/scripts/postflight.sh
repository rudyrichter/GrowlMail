#!/bin/sh

running=/tmp/GrowlMail-Installation-Temp/running

# Move our temporary installation into the real destination.
mkdir -p ~/Library/Mail/Bundles
rm -R ~/Library/Mail/Bundles/GrowlMail.mailbundle
mv "/tmp/GrowlMail-Installation-Temp/GrowlMail.mailbundle" ~/Library/Mail/Bundles
chown $USER ~/Library/Mail/
chown -R $USER ~/Library/Mail/Bundles

######
# Note that we are running sudo'd, so these defaults will be written to
# /Library/Preferences/com.apple.mail.plist
#
# Mail must NOT be running by the time this script executes
######
macosx_minor_version=$(sw_vers | /usr/bin/sed -Ene 's/.*[[:space:]]10\.([0-9][0-9]*)\.*[0-9]*/\1/p;')
bundle_compatibility_version=4
if [[ "$macosx_minor_version" -eq 9 ]]; then
    domain=~/Library/Containers/com.apple.mail/Data/Library/Preferences/com.apple.mail
elif [[ "$macosx_minor_version" -eq 10 ]]; then
    domain=~/Library/Containers/com.apple.mail/Data/Library/Preferences/com.apple.mail
    bundle_compatibility_version=7
else
    echo 'Unrecognized Mac OS X version!' > /dev/stderr
    sw_vers > /dev/stderr
fi

echo $domain

sudo -u $USER defaults write "$domain" EnableBundles -bool YES

# Mac OS X 10.5's Mail.app requires bundle version 3 or greater
sudo -u $USER defaults write "$domain" BundleCompatibilityVersion -int "$bundle_compatibility_version"

#relaunch mail if it was running before started
if [ -f "$running" ]; then
    osascript -e "activate app \"Mail\""
fi

# Remove our temporary directory so that another user account on the same system can install.
rm -R /tmp/GrowlMail-Installation-Temp
