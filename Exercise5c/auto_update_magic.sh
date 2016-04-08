#!/bin/bash

###
#
#            Name:  auto_update_magic.sh
#     Description:  A script and LaunchDaemon pair designed to leverage
#                   autopkg, AutoPkgr, JSSImporter, and Casper to keep apps on
#                   Mac endpoints up to date automatically. Details at:
#                   https://github.com/homebysix/auto-update-magic
#          Author:  Elliot Jordan <elliot@lindegroup.com>
#         Created:  2013-03-24
#   Last Modified:  2016-04-08
#         Version:  2.1.1
#
###


################################## SETTINGS ###################################

# Add a line here for each auto update custom trigger. This is almost always
# the same as the recipe's name. Trigger and recipe names may contain spaces.
TRIGGERS=(

    # "Adobe Flash Player"

    # "Firefox"

    # "Google Chrome"

    # "Oracle Java 7"

    # "Oracle Java 8"

    # "Office2011Update"

)

# For each recipe above, add a corresponding line here for each "blocking
# application" (apps/processes that must not be open if the app is to be
# updated automatically). You can add multiple comma-separated applications per
# line. Use `pgrep -ix _____` to test whether the blocking behaves as expected.
BLOCKING_APPS=(

    # "Safari$, Firefox" # blocking apps for Flash

    # "Firefox" # blocking apps for Firefox

    # "Google Chrome" # blocking apps for Chrome

    # "Safari$, Firefox" # blocking apps for Java 7

    # "Safari$, Firefox" # blocking apps for Java 8

    # "MSN Messenger, Microsoft Lync, Microsoft Cert Manager, Microsoft Chart Converter, Microsoft Clip Gallery, Microsoft Entourage, Microsoft Outlook, Microsoft Error Reporting, Microsoft Excel, Microsoft Graph, Microsoft Help Viewer, Microsoft Language Register, Microsoft Communicator, Microsoft Messenger, Microsoft PowerPoint, Microsoft Query, Microsoft Word, My Day, Organization Chart, Expression Media, Remote Desktop Connection" # blocking apps for latest Office 2011 update

)

# Preference list that will be used to track last auto update timestamp.
# Omit ".plist" extension.
PLIST="/Library/Application Support/JAMF/com.jamfsoftware.jamfnation"

# Set DEBUG_MODE to true if you wish to do a "dry run." This means the custom
# triggers that cause the apps to actually update will be logged, but NOT
# actually executed. Set to false prior to deployment.
DEBUG_MODE=true


###############################################################################
######################### DO NOT EDIT BELOW THIS LINE #########################
###############################################################################


######################## VALIDATION AND ERROR CHECKING ########################

APPNAME=$(basename "$0" | sed "s/\.sh$//")

# Let's make sure we have the right numbers of settings above.
if [[ ${#TRIGGERS[@]} != ${#BLOCKING_APPS[@]} ]]; then
    echo "[ERROR] Please carefully check the settings in the $APPNAME script. The number of parameters don't match." >&2
    exit 1001
fi

# Let's verify that DEBUG_MODE is set to true or false.
if [[ $DEBUG_MODE != true && $DEBUG_MODE != false ]]; then
    echo "[ERROR] DEBUG_MODE should be set to either true or false." >&2
    exit 1002
fi

# Locate the jamf binary.
PATH="/usr/sbin:/usr/local/bin:$PATH"
jamf=$(which jamf)
if [[ -z $jamf ]]; then
    echo "[ERROR] The jamf binary could not be found." >&2
    exit 1003
fi

# Verify that the JSS is available before starting.
$jamf checkJSSConnection -retry 0
if [[ $? -ne 0 ]]; then
    echo "[ERROR] Unable to communicate with the JSS right now." >&2
    exit 1004
fi


################################ MAIN PROCESS #################################

# Count how many recipes we need to process.
RECIPE_COUNT=${#TRIGGERS[@]}

# Save the default internal field separator.
OLDIFS=$IFS

# Begin iterating through recipes.
for (( i = 0; i < RECIPE_COUNT; i++ )); do

    echo " " # for some visual separation between apps in the log

    # Iterate through each recipe's corresponding blocking apps.
    echo "Checking for apps that would block the ${TRIGGERS[$i]} update..."
    IFS=","
    UPDATE_BLOCKED=false

    for APP in ${BLOCKING_APPS[$i]}; do

        # Strip leading spaces from app name.
        APP_CLEAN="$(echo "$APP" | sed 's/^ *//')"

        # Check whether the app is running.
        if pgrep -ix "$APP_CLEAN" &> /dev/null; then
            echo "    $APP_CLEAN is running. Skipping auto update."
            UPDATE_BLOCKED=true
            break
        else
            echo "    $APP_CLEAN is not running."
        fi

    done

    # Only run the auto-update policy if no blocking apps are running.
    if [[ $UPDATE_BLOCKED == false ]]; then
        if [[ $DEBUG_MODE == false ]]; then
            echo "No apps are blocking the ${TRIGGERS[$i]} update. Calling policy trigger autoupdate-${TRIGGERS[$i]}."
            $jamf policy -event "autoupdate-${TRIGGERS[$i]}"
        else
            echo "[DEBUG] No apps are blocking the ${TRIGGERS[$i]} update. This is the point where we would run:"
            echo "    $jamf policy -event \"autoupdate-${TRIGGERS[$i]}\""
        fi
    fi

done # End iterating through recipes.

# Reset back to default internal field separator.
IFS=$OLDIFS

# Record the timestamp of the last auto update check.
if [[ $DEBUG_MODE == false ]]; then
    /usr/bin/defaults write "$PLIST" LastAutoUpdate "$(date +%s)"
fi

exit 0
