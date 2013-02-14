#!/bin/sh

temp=/tmp/GrowlMail-Installation-Temp
running="$temp/running"
mkdir -p "$temp"

if [ `/usr/bin/pgrep Mail` ]; then
    touch $running
fi

echo $running

#####
# We politely asked the user to quit Mail in the installer intro.  Now
# we'll request the same a bit more strongly.
####
osascript -e "quit app \"Mail\""

# Delete any old copies of the bundle
rm -rf ~/Library/Mail/Bundles/GrowlMail.mailbundle
rm -rf /Library/Mail/Bundles/GrowlMail.mailbundle