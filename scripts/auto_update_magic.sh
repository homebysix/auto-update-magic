#!/usr/bin/env bash

###
#
#            Name:  auto_update_magic.sh
#     Description:  A Casper script to assist in automatically updating apps,
#                   meant to be used in conjunction with autopkg/AutoPkgr and
#                   the jss-autopkg-addon.
#          Author:  Elliot Jordan <elliot@lindegroup.com>
#         Created:  2013-03-24
#   Last Modified:  2014-10-22
#         Version:  1.3
#
###

apps=(
############################# EDIT BELOW THIS LINE #############################
# Add a line for each auto-updated app. The first part of the line is the name
# of the app itself. The second part of the line is the name of the recipe.
# The first and second parts are separated by a comma. Each line should be
# wrapped in double quotes. Like so:

#          "Firefox, Firefox"
#    "Google Chrome, GoogleChrome"
#            "Skype, Skype"



############################# EDIT ABOVE THIS LINE #############################
    );

function AutoUpdateMagic () {
    for app in "${apps[@]}"; do
        echo " " # for some visual separation between apps in the log
        process=$(echo $app | awk -F',' {'print $1'} | awk '{$1=$1}{ print }')
        recipe=$(echo $app | awk -F',' {'print $2'} | awk '{$1=$1}{ print }')

        if [[ `ps ax | grep -v grep | grep "$process" | wc -l` -gt 0 ]]; then
            echo "$process is running. Skipping auto update."
        else
            echo "$process is not running. Calling policy trigger autoupdate-$recipe."
            /usr/sbin/jamf policy -trigger "autoupdate-$recipe"
        fi
    done
    /usr/bin/defaults write /Library/"Application Support"/JAMF/com.jamfsoftware.jamfnation LastAutoUpdate $(date +%s)
}

function AutoUpdateTimeCheck () {
    ## Determine difference in seconds between the last time stamp and current time
    seconds=$((60*60*Hours))
    timeNow=$(date +%s)
    timeDiff=$((timeNow-lastAutoUpdateTime))

    if [[ "$timeDiff" -ge "$seconds" ]]; then
        AutoUpdateMagic
        exit 0
    else
        if [[ "$timeDiff" -lt "3600" ]]; then
            /bin/echo "Auto updates not needed, last ran $((timeDiff/60)) minutes ago. Will run again in $((Hours*60-timeDiff/60)) minutes."
        else
            /bin/echo "Auto updates not needed, last ran $((timeDiff/60/60)) hours ago. Will run again in $((Hours*60-timeDiff/60)) minutes."
        fi
        exit 0
    fi
}

# Number of hours between auto updates is taken from parameter 4, or defaults to 1
if [[ $4 != "" ]]; then
    Hours=$4
else
    Hours=1
fi
echo "We are checking for auto updates every $Hours hours."

lastAutoUpdateTime=$(/usr/bin/defaults read /Library/"Application Support"/JAMF/com.jamfsoftware.jamfnation LastAutoUpdate 2> /dev/null)
if [[ "$?" -ne "0" ]]; then
    echo "Auto Update Magic has never run before. Checking for updates now..."
    AutoUpdateMagic
    exit 0
else
    # Otherwise, we need to check to see how long it's been since the last run.
    AutoUpdateTimeCheck
fi

exit 0