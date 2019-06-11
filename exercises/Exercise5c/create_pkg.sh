#!/bin/bash

###
#
#            Name:  create_pkg.sh
#     Description:  This script automatically creates a pkg file that you can
#                   use to deploy the Auto Update Magic script/LaunchDaemon
#                   pair to your managed clients.
#          Author:  Elliot Jordan <elliot@lindegroup.com>
#         Created:  2015-09-18
#   Last Modified:  2016-12-05
#         Version:  1.0.3
#
###

cd "$(dirname "$0")"

if [[ ! -f "./auto_update_magic.sh" ||
      ! -f "./com.jamf.jamfnation.auto_update_magic.plist" ||
      ! -f "./pkg_scripts/preinstall" ||
      ! -f "./pkg_scripts/postinstall" ]]; then
    echo "[ERROR] At least one required file is missing. Ensure that the following files exist in the Exercise5c folder:"
    echo "    auto_update_magic.sh"
    echo "    com.jamf.jamfnation.auto_update_magic.plist"
    echo "    pkg_scripts/preinstall"
    echo "    pkg_scripts/postinstall"
    exit 1
fi

script_md5=$(md5 -q ./auto_update_magic.sh)
if [[ "$script_md5" == "089853e0bbe5cae09634d11d78081072" ]]; then
    echo "[ERROR] It looks like you haven't customized the auto_update_magic.sh script yet. Please do that now, then run create_pkg.sh again."
    exit 2
fi

read -p "[SANITY CHECK] Have you already added the TRIGGERS to auto_update_magic.sh? [y/n]: " -n 1 check_triggers
echo
if [[ "$check_triggers" != "y" && "$check_triggers" != "Y" ]]; then
    echo "You should go back and add the TRIGGERS to auto_update_magic.sh now, then run create_pkg.sh again."
    exit 3
fi

read -p "[SANITY CHECK] Have you already added the BLOCKING_APPS to auto_update_magic.sh? [y/n]: " -n 1 check_blocking_apps
echo
if [[ "$check_blocking_apps" != "y" && "$check_blocking_apps" != "Y" ]]; then
    echo "You should go back and add the BLOCKING_APPS to auto_update_magic.sh now, then run create_pkg.sh again."
    exit 4
fi

read -p "[SANITY CHECK] Have you already adjusted the StartInterval in the com.jamf.jamfnation.auto_update_magic LaunchDaemon to your liking? [y/n]: " -n 1 check_schedule
echo
if [[ "$check_schedule" != "y" && "$check_schedule" != "Y" ]]; then
    echo "You should go back and adjust the StartInterval now, then run create_pkg.sh again."
    exit 5
fi

echo "Great! Sounds like you're good to go."

TMP_PKGROOT="/private/tmp/auto_update_magic/pkgroot"
echo "Building package root in /tmp folder..."
mkdir -p "$TMP_PKGROOT/Library/LaunchDaemons" "$TMP_PKGROOT/Library/Scripts"

echo "Copying the files to the package root..."
cp "./com.jamf.jamfnation.auto_update_magic.plist" "$TMP_PKGROOT/Library/LaunchDaemons/"
cp "./auto_update_magic.sh" "$TMP_PKGROOT/Library/Scripts/"

echo "Setting mode and permissions..."
chown -R root:wheel "$TMP_PKGROOT"
chmod +x "$TMP_PKGROOT/Library/Scripts/auto_update_magic.sh"

echo "Building the package..."
pkgbuild --root "/tmp/auto_update_magic/pkgroot" \
         --scripts "./pkg_scripts" \
         --identifier "com.jamf.jamfnation.auto_update_magic" \
         --version "2.2.1" \
         --install-location "/" \
         "./auto_update_magic-$(date "+%Y%m%d").pkg"

exit 0
