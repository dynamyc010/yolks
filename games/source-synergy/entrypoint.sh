#!/bin/bash

#
# Copyright (c) 2021 Matthew Penner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Give everything time to initialize for preventing SteamCMD deadlock
sleep 1

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
# variable format of "${VARIABLE}" before evaluating the string and automatically
# replacing the values.
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

## just in case someone removed the defaults.
if [ "${STEAM_USER}" == "" ]; then
    echo -e "steam user is not set.\n"
    echo -e "Using anonymous user.\n"
    echo -e "!! THIS WILL LIKELY FAIL AS ANONYMOUS DOESN'T HAVE ACCESS TO THE RIGHT LICENSES !!\n"
    echo -e "(or HL2, for that matter)\n"
    STEAM_USER=anonymous
else
    echo -e "user set to ${STEAM_USER}\n"
    echo -e "attempting to use cached details; might fail, but i'll try my best!\n"
fi

## if auto_update is not set or to 1 update
if [ -z ${AUTO_UPDATE} ] || [ $AUTO_UPDATE == "1" ]; then
    # Update Synergy Server
    ./steamcmd/steamcmd.sh +@NoPromptForPassword 1 +@ShutdownOnFailedCommand 1 +force_install_dir /home/container/Synergy +login ${STEAM_USER} +app_update 17520 validate +quit || FAILED_UPDATE=1
    if [ -z "${FAILED_UPDATE}" ]; then
        ./steamcmd/steamcmd.sh +@NoPromptForPassword 1 +@ShutdownOnFailedCommand 1 +force_install_dir /home/container/Half-Life\ 2 +login ${STEAM_USER} +app_update 220 validate +quit || FAILED_UPDATE=1
    fi
else
    echo -e "Not updating game server as auto update was set to 0. Starting Server"
fi

## We failed to update... :(
if [[ ${FAILED_UPDATE} -eq 1 ]]; then
    echo -e "failed to update server... \n"
    if [[ $STEAM_USER == "anonymous" ] || [ $STEAM_PASS == ""]]; then
        echo -e "no proper credentials; giving up and starting server.\n"
    else
        # echo -e "user set to ${STEAM_USER}\n"
        echo -e "attempting to use given credentials; be sure to update your Auth code!\n"
        ./steamcmd/steamcmd.sh +@NoPromptForPassword 1 +@ShutdownOnFailedCommand 1 +force_install_dir /home/container/Synergy +login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH} +app_update 17520 validate +quit || FAILED_UPDATE_2=1
        if [ -z "${FAILED_UPDATE_2}" ]; then
            ./steamcmd/steamcmd.sh +@NoPromptForPassword 1 +@ShutdownOnFailedCommand 1 +force_install_dir /home/container/Half-Life\ 2 +login ${STEAM_USER} +app_update 220 validate +quit
        else
            echo -e "Failed again; giving up and starting server.\n"
        fi
    fi
fi

# Display the command we're running in the output, and then execute it with the env
# from the container itself.
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"
# shellcheck disable=SC2086
exec env ${PARSED}
