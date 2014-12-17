#!/usr/bin/env bash

###
#
#            Name:  auto_update_magic.sh
#     Description:  A Casper script to assist in automatically updating apps,
#                   meant to be used in conjunction with autopkg, AutoPkgr, and
#                   JSSImporter.
#          Author:  Elliot Jordan <elliot@lindegroup.com>
#         Created:  2013-03-24
#   Last Modified:  2014-12-17
#         Version:  1.4
#
###


################################### SETTINGS ###################################

# Add a line here for each auto-update recipe name. Recipe names do not
# typically contain spaces.
RECIPE_NAME=(
    "Firefox"
    "GoogleChrome"
    "MSOffice2011Updates"
    "AdobeFlashPlayer"
)

# For each recipe above, add a corresponding line here for each "blocking
# application" — apps that must not be open if the app is to be updated. You can
# add multiple comma-separated applications per line, as in the examples below.
BLOCKING_APPS=(
    "Firefox" # Blocking apps for Firefox
    "Google Chrome" # Blocking apps for GoogleChrome
    "Microsoft Word, Microsoft Excel, Microsoft PowerPoint, Microsoft Outlook, Google Chrome, Safari, Firefox" # Blocking apps for MSOffice2011Updates
    "Safari, Firefox" # Blocking apps for AdobeFlashPlayer
)

# Set DEBUG_MODE to true if you wish to do a "dry run" instead of actually
# installing updates.
DEBUG_MODE=true


################################################################################
######################### DO NOT EDIT BELOW THIS LINE ##########################
################################################################################


######################## VALIDATION AND ERROR CHECKING #########################

APPNAME=$(basename $0 | sed "s/\.sh$//")

# Let's make sure we have the right numbers of settings above.
if [[ ${#RECIPE_NAME[@]} != ${#BLOCKING_APPS[@]} ]]; then

    echo "ERROR: Please carefully check the settings in the $APPNAME script. The number of parameters don't match." >&2
    exit 1001

fi

# Number of hours between auto updates is taken from parameter 4, or defaults to 1
if [[ ! -z $4 && $(bc <<< "$4 > 0") == 1 ]]; then
    HOURS=$4
else
    HOURS=1
fi


################################## FUNCTIONS ###################################

# This function checks whether the apps are running, and updates them if not
function fn_AutoUpdateMagic () {

    # Count how many recipes we need to process.
    RECIPE_COUNT=${#RECIPE_NAME[@]}

    # Begin iterating through recipes.
    for (( i = 0; i < $RECIPE_COUNT; i++ )); do

        echo " " # for some visual separation between apps in the log

        # Iterate through each recipe's corresponding blocking apps.
        echo "Checking for apps that would block the ${RECIPE_NAME[$i]} update..."
        IFS=","
        UPDATE_BLOCKED=false
        for APP in ${BLOCKING_APPS[$i]}; do
            APP_CLEAN=$(echo "$APP" | sed 's/^ *//')
            if [[ `ps ax | grep -v grep | grep "$APP_CLEAN" | wc -l` -gt 0 ]]; then
                echo "    $APP_CLEAN is running. Skipping auto update."
                UPDATE_BLOCKED=true
                break
            else
                echo "    $APP_CLEAN is not running."
            fi
        done

        # Only run the auto-update policy if no blocking apps are running.
        if [[ $UPDATE_BLOCKED == false ]]; then
            echo "No apps are blocking the ${RECIPE_NAME[$i]} update. Calling policy trigger autoupdate-${RECIPE_NAME[$i]}."
            if [[ $DEBUG_MODE == false ]]; then
                /usr/sbin/jamf policy -trigger "autoupdate-${RECIPE_NAME[$i]}"
            fi
        fi

    done # End iterating through recipes.

    # Reset the LastAutoUpdate time.
    /usr/bin/defaults write /Library/"Application Support"/JAMF/com.jamfsoftware.jamfnation LastAutoUpdate $(date +%s)
}

# This function calculates whether it's time to run the auto updates
function fn_AutoUpdateTimeCheck () {
    SECONDS=$((60*60*HOURS))
    EPOCH=$(date +%s)
    TIMEDIFF=$((EPOCH-lastAutoUpdateTime))

    if [[ "$TIMEDIFF" -ge "$SECONDS" ]]; then
        fn_AutoUpdateMagic
    else
        if [[ "$TIMEDIFF" -lt "3600" ]]; then
            /bin/echo "Auto updates not needed, last ran $((TIMEDIFF/60)) minutes ago. Will run again in $((HOURS*60-TIMEDIFF/60)) minutes."
        else
            /bin/echo "Auto updates not needed, last ran $((TIMEDIFF/60/60)) hours ago. Will run again in $((HOURS*60-TIMEDIFF/60)) minutes."
        fi
    fi
}


################################# MAIN PROCESS #################################

lastAutoUpdateTime=$(/usr/bin/defaults read /Library/"Application Support"/JAMF/com.jamfsoftware.jamfnation LastAutoUpdate 2> /dev/null)
if [[ "$?" -ne "0" ]]; then
    echo "Auto Update Magic has never run before. Checking for updates now..."
    fn_AutoUpdateMagic
else
    fn_AutoUpdateTimeCheck
fi

printf "\nWe will check again for auto updates after $HOURS hours.\n\n"

exit 0