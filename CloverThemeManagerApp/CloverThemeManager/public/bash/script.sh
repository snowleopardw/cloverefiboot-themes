#!/bin/bash

# A script for Clover Theme Manager
# Copyright (C) 2014 Blackosx
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Credits:
# Thanks to SoThOr for helping with svn communications
# Thanks to apianti for setting up the Clover git theme repository.
# Thanks to apianti, dmazar & JrCs for their git know-how. 
# Thanks to alexq, asusfreak, chris1111, droplets, eMatoS, kyndder & oswaldini for testing.

VERS="0.75.7"

export DEBUG=1
#set -x

# =======================================================================================
# Helper Functions/Routines
# =======================================================================================



# ---------------------------------------------------------------------------------------
CreateSymbolicLinks()
{
    local checkCount=0
    
    # Create symbolic link to local images
    WriteToLog "Creating symbolic link to ${WORKING_PATH}/${APP_DIR_NAME}/themes"
    ln -s "${WORKING_PATH}/${APP_DIR_NAME}"/themes "$ASSETS_DIR" && ((checkCount++))
    
    # Create symbolic link to local help page
    WriteToLog "Creating symbolic link to ${WORKING_PATH}/${APP_DIR_NAME}/CloverThemeManagerApp/help/add_theme.html"
    ln -s "${WORKING_PATH}/${APP_DIR_NAME}"/CloverThemeManagerApp/help/add_theme.html "$PUBLIC_DIR" && ((checkCount++))
    
    # Add messages in to log for initialise.js to detect.
    if [ $checkCount -eq 2 ]; then
        WriteToLog "CTM_SymbolicLinksOK"
    else
        WriteToLog "CTM_SymbolicLinksFail"
    fi
}

# ---------------------------------------------------------------------------------------
WriteToLog() {
    if [ $COMMANDLINE -eq 0 ]; then
        printf "@${1}@\n" >> "$logFile"
    else
        printf "@${1}@\n"
    fi
}

# ---------------------------------------------------------------------------------------
WriteLinesToLog() {
    if [ $COMMANDLINE -eq 0 ]; then
        printf "@===================================@\n" >> "$logFile"
    else
        printf "@===================================@\n"
    fi
}

# ---------------------------------------------------------------------------------------
SendToUI() {
    echo "${1}" >> "$logBashToJs"
}

# ---------------------------------------------------------------------------------------
SendToUIUVersionedDir() {
    echo "${1}" >> "$logBashToJsVersionedDir"
}

# ---------------------------------------------------------------------------------------
FindStringInPlist() {
    # Check if file contains carriage returns (CR) as opposed to Line Feed (LF)
    checkForCR=$( tr -cd '\r' < "$2" | wc -c )
    if [ $checkForCR -gt 0 ]; then
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}${2##*/} contains carriage returns (CR)"
        local a=$( cat -v "$2" )
        local b="${a##*${1}</key>}"
        local c="${b%%</string>*}"
        local string="${c##*<string>}"
    else
        local string=$( grep -A 1 "<key>${1}</key>" "${2}" | head -n 2 | tail -2 | sed 1d | sed -e 's/<\/string>//g' )
    fi
    string=${string#*<string>}
    echo "$string"
}

# ---------------------------------------------------------------------------------------
FindStringInPlistVariable() {
    local string=$( echo "${2}" | grep -A 1 "<key>${1}</key>" | head -n 2 | tail -2 | sed 1d | sed -e 's/<\/string>//g' )
    string=${string#*<string>}
    echo "$string"
}

# ---------------------------------------------------------------------------------------
RemoveFile()
{
    if [ -f "$1" ]; then
        rm "$1"
    fi
}

# ---------------------------------------------------------------------------------------
CalculateMd5() {
	local hash=$( md5 "$1" )
    echo "${hash##*= }"
}

# ---------------------------------------------------------------------------------------
ResetNewlyInstalledThemeVars()
{
    # Reset vars for newly installed theme
    gNewInstalledThemeName=""
    gNewInstalledThemePath=""
    gNewInstalledThemePathDevice=""
    gNewinstalledThemePartitionGUID=""
}

# ---------------------------------------------------------------------------------------
ResetUnInstalledThemeVars()
{
    # Reset vars for newly installed theme
    gUnInstalledThemeName=""
    gUnInstalledThemePath=""
    gUnInstalledThemePathDevice=""
    gUninstalledThemePartitionGUID=""
}

# ---------------------------------------------------------------------------------------
ResetInternalThemeArrays()
{
    # Reset arrays for newly installed theme
    unset installedThemeName
    unset installedThemePath
    unset installedThemePathDevice
    unset installedThemePartitionGUID
}

# ---------------------------------------------------------------------------------------
ResetInternalDiskArrays()
{
    # Reset arrays for newly installed theme
    unset duIdentifier
    unset duVolumeName
    unset duVolumeMountPoint
    unset duContent
    unset duPartitionGuid
    unset themeDirPaths
    unset unmountedEsp
}

# ---------------------------------------------------------------------------------------
RenameInternalESPMountPointToEFI()
{
    # Rename internal ESP internal mountpoint in supplied path to EFI
    if [[ "$1" == *"$gESPMountPrefix"* ]]; then
        local tmpVolume="${1%/EFI*}"
        local tmpPath="${1##*$tmpVolume}"
        local finalPath="/Volumes/EFI${tmpPath}"
        [[ DEBUG -eq 1 ]] && WriteToLog "Renaming for UI $1 to $finalPath"
    else
        finalPath="$1"
    fi
    echo "$finalPath"
}

# ---------------------------------------------------------------------------------------
MaintainInstalledThemeListInPrefs()
{
    # This routine creates the InstalledThemes array which is
    # then written to the user's preferences file.
    
    # The InstalledThemes array keeps track of the current state
    # of all theme installations done by this application.
    # It also records the update state of each installed theme.
    
    # When themes are UnInstalled/deleted by the user, the pref
    # entry is also removed.
    
    chmod 755 "$gUserPrefsFile".plist 

    openArray="<array>"
    closeArray="</array>"
    openDict="<dict>"
    closeDict="</dict>"
    
    InsertDictionaryIntoArray()
    {
        local passedPath="$1"
        local passedDevice="$2"
        local passedUuid="$3"
        local passedUpdate="$4"
        
        # Rename any ESP internal mountpoint to EFI
        passedPath=$( RenameInternalESPMountPointToEFI "$passedPath" )
        
        # open dictionary
        arrayString="${arrayString}$openDict"

        # Add theme entries
        arrayString="${arrayString}<key>ThemePath</key>"
        arrayString="${arrayString}<string>$passedPath</string>"
        arrayString="${arrayString}<key>ThemePathDevice</key>"
        arrayString="${arrayString}<string>$passedDevice</string>"
        arrayString="${arrayString}<key>VolumeUUID</key>"
        arrayString="${arrayString}<string>$passedUuid</string>"
        #arrayString="${arrayString}<key>UpdateAvailable</key>"
        #arrayString="${arrayString}<string>$passedUpdate</string>"

        # close dictionary
        arrayString="${arrayString}$closeDict"
    }
        
    # Is there a newly installed theme to add?
    # And on a partition with a unique partition GUID?
    if [ "$gNewInstalledThemeName" != "" ] && [ "$gNewinstalledThemePartitionGUID" != "$zeroUUID" ]; then
        WriteToLog "Newly installed theme to be added to prefs: $gNewInstalledThemeName"
        # Is this new theme already installed elsewhere?
        local themeToAppend=0
        for ((n=0; n<${#installedThemeName[@]}; n++ ));
        do
            if [ "$gNewInstalledThemeName" == "${installedThemeName[$n]}" ]; then
                themeToAppend=1
                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}$gNewInstalledThemeName is already in prefs - will append to entry"
                break
            fi
        done
    fi

    # Is there an UnInstalled theme to remove?
    local dontReAddThemeId=9999
    if [ "$gUnInstalledThemeName" != "" ] && [ "$gNewinstalledThemePartitionGUID" != "$zeroUUID" ]; then
        WriteToLog "UnInstalled theme to be removed: $gUnInstalledThemeName"
        
        # Check for ESP mountpoint
        local pathToCheck
        if [[ "$gUnInstalledThemePath" == *$gESPMountPrefix* ]]; then
            local tmpStrip="${themeDirPaths[$entry]#*/}"
            tmpStrip="${tmpStrip#*/}"
            tmpStrip="${tmpStrip#*/}"
            pathToCheck="/Volumes/EFI/${tmpStrip}"
        else
            pathToCheck="$gUnInstalledThemePath"
        fi
            
        # Loop though array of installed themes to find ID of theme to remove.
        for ((n=0; n<${#installedThemeName[@]}; n++ ));
        do 
            if [ "${installedThemeName[$n]}" == "$gUnInstalledThemeName" ] && [ "${installedThemePath[$n]}" == "$pathToCheck" ] && [ "${installedThemePartitionGUID[$n]}" == "$gUninstalledThemePartitionGUID" ]; then
                WriteToLog "Will remove ${installedThemeName[$n]},${installedThemePath[$n]},${installedThemePartitionGUID[$n]}"
                dontReAddThemeId=$n
                ResetUnInstalledThemeVars
                break
            fi
        done
    fi

    # Construct InstalledThemes array
    arrayString=""
    lastAddedThemeName=""
    WriteToLog "Updating InstalledThemes prefs"
    for ((n=0; n<${#installedThemeName[@]}; n++ ));
    do
         # Don't write back a theme if marked to be removed
         if [ $n -ne $dontReAddThemeId ]; then

            # Housekeeping can change a theme name to a dash.
            # This indicates the theme entry in no longer required.
            if [ "${installedThemeName[$n]}" != "-" ]; then
            
                # Add theme key
                if [ "${installedThemeName[$n]}" != "$lastAddedThemeName" ]; then

                    # Check if there's a newly installed theme to append to this current array
                    if [ $themeToAppend -eq 1 ] && [ "$lastAddedThemeName" == "$gNewInstalledThemeName" ]; then
                        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Appending $gNewInstalledThemeName dictionary to existing array."
                        InsertDictionaryIntoArray "$gNewInstalledThemePath" "$gNewInstalledThemePathDevice" "$gNewinstalledThemePartitionGUID" ""
                        themeToAppend=0
                        ResetNewlyInstalledThemeVars
                    fi

                    # close any previous arrays
                    if [ "$lastAddedThemeName" != "" ]; then
                        arrayString="${arrayString}$closeArray"
                    fi

                    # Write new theme key
                    arrayString="${arrayString}<key>${installedThemeName[$n]}</key>"

                    # open array
                    arrayString="${arrayString}$openArray"
                    lastAddedThemeName="${installedThemeName[$n]}"
                fi
                InsertDictionaryIntoArray "${installedThemePath[$n]}" "${installedThemePathDevice[$n]}" "${installedThemePartitionGUID[$n]}"
            fi
        fi
    done
    
    # Did the loop finish before appending a newly installed theme to an existing them entry?
    # Check if there's a newly installed theme to append to this current array
    if [ $themeToAppend -eq 1 ] && [ "$lastAddedThemeName" == "$gNewInstalledThemeName" ]; then
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Append didn't happen. Attempting to appending $gNewInstalledThemeName now."
        InsertDictionaryIntoArray "$gNewInstalledThemePath" "$gNewInstalledThemePathDevice" "$gNewinstalledThemePartitionGUID"
        themeToAppend=0
        ResetNewlyInstalledThemeVars
    fi
    
    # Was the above loop run?
    if [ "$lastAddedThemeName" != "" ]; then
        # close array
        arrayString="${arrayString}$closeArray"
    fi

    # Did the newly installed theme get appended? If not then it needs adding at end.
    if [ "$gNewInstalledThemeName" != "" ]; then
        # Write new theme key
        arrayString="${arrayString}<key>${gNewInstalledThemeName}</key>"
        # open array
        arrayString="${arrayString}$openArray"
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Append still hasn't completed. Appending $gNewInstalledThemeName now."
        InsertDictionaryIntoArray "$gNewInstalledThemePath" "$gNewInstalledThemePathDevice" "$gNewinstalledThemePartitionGUID"
        # close array
        arrayString="${arrayString}$closeArray"
        lastAddedThemeName="$gNewInstalledThemeName"
        ResetNewlyInstalledThemeVars
    fi
    
    # Delete existing and write new InstalledThemes prefs key
    [[ DEBUG -eq 1 ]] && WriteToLog "Removing previous InstalledThemes array from prefs file"
    defaults delete "$gUserPrefsFile" "InstalledThemes"
    
    # Only add back if there's something to write.
    if [ "$lastAddedThemeName" != "" ]; then
        [[ DEBUG -eq 1 ]] && WriteToLog "Inserting InstalledThemes array in to prefs file"
        defaults write "$gUserPrefsFile" InstalledThemes -array "$openDict$arrayString$closeDict"
    fi
    chmod 755 "$gUserPrefsFile".plist 
    ReadPrefsFile
}

# ---------------------------------------------------------------------------------------
UpdatePrefsKey()
{
    local passedKey="$1"
    local passedValue="$2"
    
    # Rename any ESP internal mountpoint to EFI
    if [ "$passedKey" == "LastSelectedPath" ]; then
        passedValue=$( RenameInternalESPMountPointToEFI "$passedValue" )
    fi
    
    if [ -f "$gUserPrefsFile".plist ]; then
        defaults delete "$gUserPrefsFile" "$passedKey"
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Writing prefs key $passedKey = $passedValue"
        defaults write "$gUserPrefsFile" "$passedKey" "$passedValue"
    else
        WriteToLog "Error! ${gUserPrefsFile}.plist not found."
    fi
}

# ---------------------------------------------------------------------------------------
ClearTopOfMessageLog()
{
    # removes the first line of the log file.
    local log=$(tail -n +2 "$1"); > "$1" && if [ "$log" != "" ]; then echo "$log" > "$1"; fi
}

# ---------------------------------------------------------------------------------------
RunThemeAction()
{
    local passedAction="$1" # Will be either Install, UnInstall or Update
    local themeTitleToActOn="$2"
    local successFlag=1

    CheckPathIsWriteable "${TARGET_THEME_DIR}"
    local isPathWriteable=$? # 1 = not writeable / 0 = writeable

    case "$passedAction" in
                "Install")  WriteToLog "Installing theme $themeTitleToActOn to ${TARGET_THEME_DIR}"
                            local successFlag=1
    
                            # Only clone the theme from the Clover repo if not already installed
                            # in which case the bare repo will already be in the local support dir.
                            if [ ! -d "${WORKING_PATH}/${APP_DIR_NAME}"/"$themeTitleToActOn".git ]; then
                                WriteToLog "Creating a bare git clone of $themeTitleToActOn"
                                local themeNameWithSpacesFixed=$( echo "$themeTitleToActOn" | sed 's/ /%20/g' )

                                cd "${WORKING_PATH}/${APP_DIR_NAME}"
                                feedbackCheck=$("$gitCmd" clone --progress --depth=1 --bare "$remoteRepositoryUrl"/themes.git/themes/"${themeNameWithSpacesFixed}"/theme.git "$themeTitleToActOn".git 2>&1 )
                                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Install git clone: $feedbackCheck"
                                
                            else
                                WriteToLog "Bare git clone of $themeTitleToActOn already exists. Will checkout from that."
                            fi
                            
                            if [ -d "${WORKING_PATH}/${APP_DIR_NAME}"/"$themeTitleToActOn".git ]; then
                                WriteToLog "Checking out bare git clone of ${themeTitleToActOn}."
                                
                                # Theme currently gets checked out as /path/to/EFI/Clover/Themes/<theme>/themes/<theme>/
                                # Desired path is                     /path/to/EFI/Clover/Themes/<theme>
                                # So checkout to a directory for unpacking first.
                                if [ -d "$UNPACKDIR" ]; then
                                    cd "${WORKING_PATH}/${APP_DIR_NAME}"
                                    feedbackCheck=$("$gitCmd" --git-dir="$themeTitleToActOn".git --work-tree="$UNPACKDIR" checkout . 2>&1 )
                                    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}checkout .: $feedbackCheck"
                                    feedbackCheck=$("$gitCmd" --git-dir="$themeTitleToActOn".git --work-tree="$UNPACKDIR" checkout HEAD -- 2>&1 ) && successFlag=0
                                    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}checkout HEAD --: $feedbackCheck"
                                else
                                    WriteToLog "Error. UnPack dir does not exist."
                                fi
                                
                                # Read current hash from packed-refs file.
                                local currentThemeHash=$( cat "${WORKING_PATH}/${APP_DIR_NAME}"/"$themeTitleToActOn".git/packed-refs | grep refs/heads/master )
                                currentThemeHash="${currentThemeHash% refs*}"
                                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}hash=$currentThemeHash"
                            fi

                            if [ ${successFlag} -eq 0 ]; then 
                            
                                # Write hash to file in to unpacked theme dir.
                                local addFile=0
                                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Writing hash to ${UNPACKDIR}/themes/${themeTitleToActOn}/.hash"
                                echo $currentThemeHash > "$UNPACKDIR"/themes/"$themeTitleToActOn"/.hash && addFile=1
                                if [ $addFile -eq 1 ]; then
                                    WriteToLog "${debugIndent}Added hash successfully"
                                    chmod 755 "$UNPACKDIR"/themes/"$themeTitleToActOn"/.hash && WriteToLog "${debugIndent}Set hash file permissions"
                                    # Enable glob to match dot files.
                                    shopt -s dotglob
                                fi
                                
                                # Create theme dir on target and move unpacked theme files to the target dir.
                                targetThemeDir="${TARGET_THEME_DIR}"/"$themeTitleToActOn"

                                if [ $isPathWriteable -eq 1 ]; then # Not Writeable
                                    if [ $(CheckOsVersion) -ge 13 ]; then
                                        successFlag=$( /usr/bin/osascript -e 'tell application "SecurityAgent" to activate'; /usr/bin/osascript -e "do shell script \"$uiSudoChanges \" & \"@Move\" & \"@$targetThemeDir\" & \"@$UNPACKDIR\" & \"@$themeTitleToActOn\" with administrator privileges" )
                                    else
                                        successFlag=$( /usr/bin/osascript -e "do shell script \"$uiSudoChanges \" & \"@Move\" & \"@$targetThemeDir\" & \"@$UNPACKDIR\" & \"@$themeTitleToActOn\" with administrator privileges" )
                                    fi  
                                else
                                    chckDir=0
                                    mkdir "$targetThemeDir" && chckDir=1
                                    if [ $chckDir -eq 1 ]; then
                                        # Move unpacked files to target theme path.
                                        cd "$UNPACKDIR"/themes
                                        if [ -d "$themeTitleToActOn" ]; then
                                            mv "$themeTitleToActOn"/* "$targetThemeDir" && successFlag=0
                                        fi
                                    fi
                                fi
                                
                                # Remove the unpacked files.
                                if [ -d "$UNPACKDIR"/themes ]; then
                                    rm -rf "$UNPACKDIR"/themes 
                                fi
                                
                                # Disable glob to match dot files.
                                shopt -u dotglob
                            fi
                            ;;
                            
               "UnInstall") WriteToLog "Deleting ${TARGET_THEME_DIR}/$themeTitleToActOn"

                            # Check if theme needs elevated privileges to remove
                            CheckPathIsWriteable "${TARGET_THEME_DIR}/$themeTitleToActOn"
                            local isPathWriteable=$? # 1 = not writeable / 0 = writeable

                            if [ $isPathWriteable -eq 1 ]; then # Not Writeable
                                if [ $(CheckOsVersion) -ge 13 ]; then
                                    successFlag=$( /usr/bin/osascript -e 'tell application "SecurityAgent" to activate'; /usr/bin/osascript -e "do shell script \"$uiSudoChanges \" & \"@UnInstall\" & \"@${TARGET_THEME_DIR}\" & \"@$themeTitleToActOn\" with administrator privileges" )
                                else
                                    successFlag=$( /usr/bin/osascript -e "do shell script \"$uiSudoChanges \" & \"@UnInstall\" & \"@${TARGET_THEME_DIR}\" & \"@$themeTitleToActOn\" with administrator privileges" )
                                fi 
                            else
                                cd "${TARGET_THEME_DIR}"
                                if [ -d "$themeTitleToActOn" ]; then
                                    rm -rf "$themeTitleToActOn" && WriteToLog "Deletion was successful." && successFlag=0
                                fi
                            fi
                            ;;
                 
                "Update")   WriteToLog "Updating ${TARGET_THEME_DIR}/$themeTitleToActOn"

                            # Check if bare git repo for this theme exists and delete if yes.
                            if [ -d "${WORKING_PATH}/${APP_DIR_NAME}"/"$themeTitleToActOn".git ]; then
                                WriteToLog "bare repo for $themeTitleToActOn exists. Deleting"
                                cd "${WORKING_PATH}/${APP_DIR_NAME}"
                                rm -rf "$themeTitleToActOn".git
                            fi

                            # Clone theme from repo.
                            WriteToLog "Creating a bare git clone of $themeTitleToActOn"
                            local themeNameWithSpacesFixed=$( echo "$themeTitleToActOn" | sed 's/ /%20/g' )
                            cd "${WORKING_PATH}/${APP_DIR_NAME}"
                            feedbackCheck=$("$gitCmd" clone --progress --depth=1 --bare "$remoteRepositoryUrl"/themes.git/themes/"${themeNameWithSpacesFixed}"/theme.git "$themeTitleToActOn".git 2>&1 )
                            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Install git clone: $feedbackCheck"

                            # Checkout the bare repo to the unpack dir then replace on target dir.
                            if [ -d "${TARGET_THEME_DIR}"/"$themeTitleToActOn" ] && [ -d "${WORKING_PATH}/${APP_DIR_NAME}"/"$themeTitleToActOn".git ]; then

                                WriteToLog "Force checking out bare git clone of ${themeTitleToActOn}."
                                cd "${WORKING_PATH}/${APP_DIR_NAME}"
                                feedbackCheck=$("$gitCmd" --git-dir="$themeTitleToActOn".git --work-tree="$UNPACKDIR" checkout --force 2>&1) && successFlag=0
                                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}checkout git clone: $feedbackCheck"
                                
                                if [ $successFlag -eq 0 ]; then

                                    # Read current hash from packed-refs file.
                                    local currentThemeHash=$( cat "${WORKING_PATH}/${APP_DIR_NAME}"/"$themeTitleToActOn".git/packed-refs | grep refs/heads/master )
                                    #currentThemeHash="${currentThemeHash% refs*}"
                                    currentThemeHash="${currentThemeHash:0:40}"
                                    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}hash=$currentThemeHash"

                                    # Write hash to file in to unpacked theme dir.
                                    local addFile=0
                                    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Writing hash to ${UNPACKDIR}/themes/${themeTitleToActOn}/.hash"
                                    echo $currentThemeHash > "$UNPACKDIR"/themes/"$themeTitleToActOn"/.hash && addFile=1
                                    if [ $addFile -eq 1 ]; then
                                        WriteToLog "${debugIndent}Added hash successfully"
                                        chmod 755 "$UNPACKDIR"/themes/"$themeTitleToActOn"/.hash && WriteToLog "${debugIndent}Set hash file permissions"
                                        # Enable glob to match dot files.
                                        shopt -s dotglob
                                    fi
                                                                
                                    targetThemeDir="${TARGET_THEME_DIR}"/"$themeTitleToActOn"
                            
                                    if [ $isPathWriteable -eq 1 ]; then # Not Writeable
                                       if [ $(CheckOsVersion) -ge 13 ]; then
                                            successFlag=$( /usr/bin/osascript -e 'tell application "SecurityAgent" to activate'; /usr/bin/osascript -e "do shell script \"$uiSudoChanges \" & \"@Update\" & \"@$targetThemeDir\" & \"@$UNPACKDIR\" & \"@$themeTitleToActOn\" with administrator privileges" )
                                        else
                                            successFlag=$( /usr/bin/osascript -e "do shell script \"$uiSudoChanges \" & \"@Update\" & \"@$targetThemeDir\" & \"@$UNPACKDIR\" & \"@$themeTitleToActOn\" with administrator privileges" )
                                        fi
                                    else
                                        if [ -d "$targetThemeDir" ]; then
                                            chckDir=0
                                            WriteToLog "Removing existing $targetThemeDir files"
                                            rm -rf "$targetThemeDir"/* && chckDir=1
                                            if [ $chckDir -eq 1 ]; then
                                                # Move unpacked files to target theme path.
                                                cd "$UNPACKDIR"/themes
                                                if [ -d "$themeTitleToActOn" ]; then
                                                    WriteToLog "Moving updated $themeTitleToActOn theme files to $targetThemeDir"
                                                    mv "$themeTitleToActOn"/* "$targetThemeDir" && successFlag=0
                                                fi
                                            fi
                                        fi
                                    fi
                                    # Remove the unpacked files.
                                    if [ -d "$UNPACKDIR"/themes ]; then
                                        rm -rf "$UNPACKDIR"/themes 
                                    fi

                                    # Disable glob to match dot files.
                                    shopt -u dotglob
                                fi
                            fi
                            ;;
    esac

    # Was install operation a success?
    if [ $successFlag -eq 0 ]; then
        if [ $COMMANDLINE -eq 0 ]; then
            WriteToLog "$themeTitleToActOn : ${passedAction} : Success"
            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: Success@${passedAction}@$themeTitleToActOn"
            SendToUI "Success@${passedAction}@$themeTitleToActOn"
            
            if [ "$passedAction" == "Install" ] && [ "$TARGET_THEME_PARTITIONGUID" != "$zeroUUID" ]; then
                WriteToLog "Saving settings for newly installed theme."
                # Save new theme details for adding to prefs file
                gNewInstalledThemeName="$themeTitleToActOn"
                gNewInstalledThemePath="$TARGET_THEME_DIR"
                gNewInstalledThemePathDevice="$TARGET_THEME_DIR_DEVICE"
                gNewinstalledThemePartitionGUID="$TARGET_THEME_PARTITIONGUID"
            fi

            if [ "$passedAction" == "UnInstall" ] && [ "$TARGET_THEME_PARTITIONGUID" != "$zeroUUID" ]; then
                WriteToLog "Saving settings for UnInstalled theme."
                # Save new theme details for adding to prefs file
                gUnInstalledThemeName="$themeTitleToActOn"
                gUnInstalledThemePath="$TARGET_THEME_DIR"
                gUnInstalledThemePathDevice="$TARGET_THEME_DIR_DEVICE"
                gUninstalledThemePartitionGUID="$TARGET_THEME_PARTITIONGUID"
            fi     
                 
            # Record what theme was installed where.
            MaintainInstalledThemeListInPrefs
            
            if [ "$passedAction" == "UnInstall" ]; then
                # Delete <theme name>.git from local support directory if no longer needed
                CheckIfThemeNoLongerInstalledThenDeleteLocalTheme "$themeTitleToActOn"
            fi
        fi
        return 0
    else
        if [ $COMMANDLINE -eq 0 ]; then
            WriteToLog "$themeTitleToActOn : ${passedAction} : Fail"
            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: Fail@${passedAction}@$themeTitleToActOn"
            SendToUI "Fail@${passedAction}@$themeTitleToActOn"
        fi
        return 1
    fi
}

# ---------------------------------------------------------------------------------------
CreateThemeListHtml()
{
    # Build html for each theme.    
    WriteToLog "Creating html theme list."
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Number of theme titles=${#themeTitle[@]}"
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Number of theme description=${#themeDescription[@]}"
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Number of theme author=${#themeAuthor[@]}"
    
    local imageFormat="png"
    
    if [ ${#themeTitle[@]} -eq ${#themeDescription[@]} ] && [ ${#themeTitle[@]} -eq ${#themeAuthor[@]} ]; then
        WriteToLog "Found ${#themeTitle[@]} Titles, Descriptions and Authors"
        WriteLinesToLog
        for ((n=0; n<${#themeTitle[@]}; n++ ));
        do
            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Creating html for ${themeTitle[$n]} theme"
            themeHtml="${themeHtml}\
        <div id=\"ThemeBand\" class=\"accordion\">\
        <div id=\"ThemeItems\">\
            <div class=\"thumbnail\"><img src=\"assets/themes/${themeTitle[$n]}/screenshot.$imageFormat\" onerror=\"imgErrorThumb(this);\"></div>\
            <div id=\"ThemeText\"><p class=\"themeTitle\">${themeTitle[$n]}<br><span class=\"themeDescription\">${themeDescription[$n]}</span><br><span class=\"themeAuthor\">${themeAuthor[$n]}</span></p></div>\
            <div class=\"versionControl\" id=\"indicator_${themeTitle[$n]}\"></div>\
            <div class=\"buttonInstall\" id=\"button_${themeTitle[$n]}\"></div>\
        </div> <!-- End ThemeItems -->\
    </div> <!-- End ThemeBand -->\
    <div class=\"accordionContent\"><img src=\"assets/themes/${themeTitle[$n]}/screenshot.$imageFormat\" onerror=\"imgErrorPreview(this);\" width=\"100%\"></div>\
    \
    "
        done
        WriteToLog "CTM_ThemeListOK"
    else
        WriteToLog "Error: Title(${#themeTitle[@]}), Author(${#themeAuthor[@]}), Description(${#themeDescription[@]}) mismatch."
        for ((n=0; n<${#themeTitle[@]}; n++ ));
        do
            WriteToLog "$n : ${themeTitle[$n]} | ${themeDescription[$n]} | ${themeAuthor[$n]}"
        done
        WriteToLog "CTM_ThemeListFail"
    fi
    WriteLinesToLog
}

# ---------------------------------------------------------------------------------------
InsertThemeListHtmlInToManageThemes()
{
    local passedOptionalCommand="$1"
    local check=1
        
    if [ "$passedOptionalCommand" == "file" ]; then
        # Read previously saved file
        themeHtml=$( cat "${WORKING_PATH}/${APP_DIR_NAME}"/theme.html )
        # Escape all ampersands
        themeHtml=$( echo "$themeHtml" | sed 's/&/\\\&/g' );
    else
        # Use internal string var
        # Escape forward slashes
        themeHtml=$( echo "$themeHtml" | sed 's/\//\\\//g' )
        # Save html to file
        echo "$themeHtml" > "${WORKING_PATH}/${APP_DIR_NAME}"/theme.html
    fi

    # Insert Html in to placeholder
    WriteToLog "Inserting HTML in to managethemes.html"
    LANG=C sed -ie "s/<!--INSERT_THEMES_HERE-->/${themeHtml}/g" "${PUBLIC_DIR}"/managethemes.html && check=0

    # Clean up
    if [ -f "${PUBLIC_DIR}"/managethemes.htmle ]; then
        rm "${PUBLIC_DIR}"/managethemes.htmle
    fi
    
    # Add messages in to log for initialise.js to detect.
    if [ $check -eq 0 ]; then
        WriteToLog "CTM_InsertHtmlOK"
    else
        WriteToLog "CTM_InsertHtmlFail"
    fi
}

# ---------------------------------------------------------------------------------------
InsertNotificationCodeInToJS()
{
    local check=1
    
    codeToInsert="macgap.notice.notify({ title: 'Clover Theme Manager', content: messageBody, sound: true});"
    
    # Insert Html in to placeholder
    WriteToLog "Inserting JS notification code in to cloverthememanager.js"
    LANG=C sed -ie "s/\/\/ INSERT_NOTIFICATION_CODE_HERE/${codeToInsert}/g" "${PUBLIC_DIR}"/scripts/cloverthememanager.js && check=0
    
    # Add messages in to log for initialise.js to detect.
    if [ $check -eq 0 ]; then
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Inserting notification code was successful."
    else
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Inserting notification code failed."
    fi
}

# ---------------------------------------------------------------------------------------
CheckOsVersion()
{
    local osVer=$( uname -r )
    echo ${osVer%%.*}
}


# =======================================================================================
# Routines for checking ownership and elevating privileges, if necessary
# =======================================================================================



# ---------------------------------------------------------------------------------------
GetAndCheckUIPassword()
{
    # Commas in the message causes osascript to fail!
    # So strip any commas before continuing.
    message=$( echo "$1" | sed 's/,//g' )
     
    # revoke sudo permissions
    sudo -k

    gPw="$( /usr/bin/osascript << EOF -e 'set MyApplVar to do shell script "echo '"${message}"'"' -e 'Tell application "System Events" to display dialog MyApplVar default answer "" with hidden answer with icon 1' -e 'text returned of result' 2>/dev/null)"
    
    # Is result not null AND not empty
    if [ -n "$gPw" ] && [ ! -z "$gPw" ]; then
        local userNow=$( echo "$gPw" | sudo -S whoami )
        if [ "$userNow" == "root" ]; then
            return 0
        else
            return 1
        fi
    else
        gPw="$gUiPwCancelledStr"
    fi
}

# ---------------------------------------------------------------------------------------
ResolveMountPointFromUUID()
{
    # Resolve volume mountpoint from UUID
    local mountpoint=""
    
    # MBR partition scheme does not use UUID's so check
    if [ "$1" != "$zeroUUID" ]; then
        for (( u=0; u<${#themeDirPaths[@]}; u++ ))
        do
            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Matching ${duPartitionGuid[$u]} : $1"
            if [[ "${duPartitionGuid[$u]}" == "$1" ]]; then
                mountpoint="${themeDirPaths[$u]}"
                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Match: Mountpoint=$mountpoint"
                break
            fi
        done
    else
        mountpoint=""
    fi
    echo "$mountpoint"
}
    
# ---------------------------------------------------------------------------------------
CheckPathIsWriteable()
{
    local passedMountPoint="$1"     
    local isWriteable=1
    
    if [ "$passedMountPoint" != "" ]; then
        touch "$passedMountPoint"/.test 2>/dev/null && rm -f "$passedMountPoint"/.test || isWriteable=0
    fi

    if [ $isWriteable -eq 0 ]; then
        return 1
    else
        return 0
    fi
}

# ---------------------------------------------------------------------------------------
FindArrayIdFromTarget()
{
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}FindArrayIdFromTarget()"
    local success=0
    for ((a=0; a<${#duIdentifier[@]}; a++))
    do
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Does ${duPartitionGuid[$a]}=${TARGET_THEME_PARTITIONGUID} && ${themeDirPaths[$a]}=${TARGET_THEME_DIR}"
        if [ "${duPartitionGuid[$a]}" == "${TARGET_THEME_PARTITIONGUID}" ] && [ "${themeDirPaths[$a]}" == "${TARGET_THEME_DIR}" ]; then
            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Match found. Returning $a"
            echo $a
            success=1
            break
        fi 
    done
    
    [[ $success -eq 0 ]] && echo -
}


# =======================================================================================
# Initialisation Routines
# =======================================================================================



# ---------------------------------------------------------------------------------------
ReadRepoUrlList()
{
    WriteToLog "Looking for URL list"
    if [ -f "$gThemeRepoUrlFile" ]; then
        WriteToLog "Reading URL list"
        oIFS="$IFS"; IFS=$'\n'
        while read -r line
        do
            if [ ! "${line:0:1}" == "#" ]; then
                WriteToLog "Found URL $line"
                repositoryUrls+=( "${line##*#}" )
            fi
        done < "$gThemeRepoUrlFile"
        IFS="$oIFS"
        WriteToLog "Number of repositories found: ${#repositoryUrls[@]}"
    else
        WriteToLog "$gThemeRepoUrlFile not found."
    fi
}

# ---------------------------------------------------------------------------------------
RefreshHtmlTemplates()
{
    passedTemplate="$1"
    local check=1
    
    # For now remove previous managethemes.html and copy template
    if [ -f "${PUBLIC_DIR}"/$passedTemplate ]; then
        if [ -f "${PUBLIC_DIR}"/$passedTemplate.template ]; then
            WriteToLog "Setting $passedTemplate to default."
            rm "${PUBLIC_DIR}"/$passedTemplate
            cp "${PUBLIC_DIR}"/$passedTemplate.template "${PUBLIC_DIR}"/$passedTemplate && check=0
        else
            WriteToLog "Error: missing ${PUBLIC_DIR}/$passedTemplate.template"
        fi
    else
        WriteToLog "Creating: $passedTemplate"
        cp "${PUBLIC_DIR}"/$passedTemplate.template "${PUBLIC_DIR}"/$passedTemplate && check=0
    fi
    
    # Add message in to log for initialise.js to detect.
    if [ $check -eq 0 ]; then
        WriteToLog "CTM_HTMLTemplateOK"
    else
        WriteToLog "CTM_HTMLTemplateFail"
    fi
    
    WriteLinesToLog
}

# ---------------------------------------------------------------------------------------
IsRepositoryLive()
{
    local gitRepositoryUrl=$( echo ${remoteRepositoryUrl}/ | sed 's/http:/git:/' )
    [[ DEBUG -eq 1 ]] && WriteToLog "$gitRepositoryUrl"
    local testConnection=$( "$gitCmd" ls-remote ${gitRepositoryUrl}themes )
    [[ DEBUG -eq 1 ]] && WriteToLog "$testConnection"
    if [ ! "$testConnection" ]; then
        # Repository not alive.
        WriteToLog "CTM_RepositoryError: No response from Repository ${gitRepositoryUrl}/themes"
        # The initialise.js should pick this up, notify the user, then quit.
        exit 1
    else
        WriteToLog "CTM_RepositorySuccess"
    fi
}

# ---------------------------------------------------------------------------------------
EnsureLocalSupportDir()
{    
    # Check for local support directory
    local pathToCreate="${WORKING_PATH}/${APP_DIR_NAME}"
    if [ ! -d "$pathToCreate" ]; then
        WriteToLog "Creating $pathToCreate"
        mkdir -p "$pathToCreate"
    fi
    
    # Create unpacking directory for checking out cloned bare theme repo's
    # from clover repo. This is because the themes checkout as:
    # /path/to/EFI/Clover/Themes/<theme>/themes/<theme>/
    if [ ! -d "$UNPACKDIR" ]; then
        mkdir "$UNPACKDIR"
    fi
    
    # Add message in to log for initialise.js to detect.
    if [ -d "$pathToCreate" ] && [ -d "$UNPACKDIR" ]; then
        WriteToLog "CTM_SupportDirOK"
    else
        WriteToLog "CTM_SupportDirFail"
    fi
}

# ---------------------------------------------------------------------------------------
EnsureSymlinks()
{
    # Rather than check if a valid one exists, it's quicker to simply re-create it.
    if [ -h "$ASSETS_DIR"/themes ] || [ -L "$ASSETS_DIR"/themes ]; then
        rm "$ASSETS_DIR"/themes
    fi
    
    if [ -h "$PUBLIC_DIR"/add_theme.html ] || [ -L "$PUBLIC_DIR"/add_theme.html ]; then
        rm "$PUBLIC_DIR"/add_theme.html
    fi
    
    CreateSymbolicLinks
    WriteLinesToLog
}

# ---------------------------------------------------------------------------------------
RespondToUserUpdateApp()
{
    local messageFromUi="$1"

    # remove everything up until, and including, the first @
    messageFromUi="${messageFromUi#*@}"
    chosenOption="${messageFromUi##*:}"

    if [ ! "$chosenOption" == "" ]; then
        WriteLinesToLog
        if [ "$chosenOption" == "Yes" ]; then
            WriteToLog "User chose to update app."
            DownloadPublicDirFromServer
            if [ $? -eq 0 ]; then
                CreateUpdateScript
                PerformUpdates
                SendToUI "UpdateAppFeedback@Success@"
            fi
        else
            WriteToLog "User chose not to update app."
            # As the user decided to not update right now then now check for theme updates
            CheckForThemeUpdates &
        fi
    fi
}

# ---------------------------------------------------------------------------------------
CheckForAppUpdate()
{
    # Remove app files from a previous run
    if [ -d "${WORKING_PATH}/${APP_DIR_NAME}"/CloverThemeManagerApp/CloverThemeManager ]; then
        WriteToLog "Removing previous CloverThemeManagerApp/CloverThemeManager directory"
        rm -rf "${WORKING_PATH}/${APP_DIR_NAME}"/CloverThemeManagerApp/CloverThemeManager
    fi

    # ======================================
    # Get the version of main app on server.
    local themeManagerInfoPlistPath="CloverThemeManagerApp/CloverThemeManager/MacGap"
    local themeManagerInfoPlistFile="CloverThemeManager-Info.plist"
    local pathToWorkingInfoPlist="${WORKING_PATH}/${APP_DIR_NAME}"/"${themeManagerInfoPlistPath}"
    local gitRepositoryUrl=$( echo ${remoteRepositoryUrl}/ | sed 's/http:/git:/' )
    cd "${WORKING_PATH}/${APP_DIR_NAME}"
    git archive --remote="${gitRepositoryUrl}themes" HEAD "${themeManagerInfoPlistPath}"/"${themeManagerInfoPlistFile}" | tar -x
    if [ -f "${pathToWorkingInfoPlist}"/"${themeManagerInfoPlistFile}" ]; then
        serverAppVersion=$( /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${pathToWorkingInfoPlist}"/"${themeManagerInfoPlistFile}" )
        rm "${pathToWorkingInfoPlist}"/"${themeManagerInfoPlistFile}"
    else
        local serverAppVersion=$mainAppVersion
    fi
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}serverAppVersion=$serverAppVersion"
    
    # Compare local vs server main app versions
    if [ $serverAppVersion != $mainAppVersion ]; then
        # If this differs then prompt user to download a new version of the app.
        # This is because I can't replace the currently running binary.
        WriteToLog "Main app update available. Current=$mainAppVersion | Server=$serverAppVersion"
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: UpdateAvailApp@${serverAppVersion}@"
        SendToUI "UpdateAvailApp@${serverAppVersion}@"
        return 0
    else
        # The main app version is the same.
        # Continue to check if the public dir has changed as that can be updated still.
        WriteToLog "Main app is at latest version: $serverAppVersion"
   
        # ======================================
        # Get current app update version for the public DIR
        if [ -f "${PUBLIC_DIR}"/.updateID ]; then
            local currentVersion=$( cat "${PUBLIC_DIR}"/.updateID )
        else
            local currentVersion=0
        fi
    
        # Get server version  
        local updateIDFilePath="CloverThemeManagerApp/CloverThemeManager/public/.updateID"
        local pathToWorkingPublicDir="${WORKING_PATH}/${APP_DIR_NAME}"/CloverThemeManagerApp/CloverThemeManager/public
        local gitRepositoryUrl=$( echo ${remoteRepositoryUrl}/ | sed 's/http:/git:/' )
        cd "${WORKING_PATH}/${APP_DIR_NAME}"
        git archive --remote="${gitRepositoryUrl}themes" HEAD "$updateIDFilePath" | tar -x
        if [ -f "${pathToWorkingPublicDir}"/.updateID ]; then
            local serverVersion=$( cat "${pathToWorkingPublicDir}"/.updateID )
        else
            local serverVersion=0
        fi
    
        if [ $serverVersion -gt $currentVersion ]; then
            WriteToLog "App update available. Current=$currentVersion | Server=$serverVersion"
            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: UpdateAvailApp@${serverVersion}@"
            SendToUI "UpdateAvailApp@${serverVersion}@"
            return 0
        else
            WriteToLog "No app update available. Current=$currentVersion | Server=$serverVersion"
            return 1
        fi
    fi
    
    cd "${WORKING_PATH}"
}

# ---------------------------------------------------------------------------------------
DownloadPublicDirFromServer()
{
    # Remove app files from a previous run
    if [ -d "${WORKING_PATH}/${APP_DIR_NAME}"/CloverThemeManagerApp ]; then
        WriteToLog "Removing previous CloverThemeManagerApp directory"
        rm -rf "${WORKING_PATH}/${APP_DIR_NAME}"/CloverThemeManagerApp
    fi
    
    # Download public dir
    local success=0
    local filePath="CloverThemeManagerApp/CloverThemeManager/public"
    local pathToWorkingPublicDir="${WORKING_PATH}/${APP_DIR_NAME}"/CloverThemeManagerApp/CloverThemeManager/public
    local gitRepositoryUrl=$( echo ${remoteRepositoryUrl}/ | sed 's/http:/git:/' )
    cd "${WORKING_PATH}/${APP_DIR_NAME}"
    "$gitCmd" archive --remote="${gitRepositoryUrl}themes" HEAD "$filePath" | tar -x && success=1
    if [ $success -eq 1 ]; then
        WriteToLog "Downloading app files from the repo was successful."
        return 0
    else
        WriteToLog "Error. Downloading app files from the repo failed."
        return 1
    fi
}

# ---------------------------------------------------------------------------------------
CreateUpdateScript()
{
    AddCopyCommandToFile()
    {
        if [ "$1" == "" ]; then
            local destination="$PUBLIC_DIR"
        else
            local destination="${PUBLIC_DIR}/${1}"
        fi
        # Escape any spaces
        tmpA=$( echo "$2" | sed 's/ /\\ /g' )
        tmpB=$( echo "$destination" | sed 's/ /\\ /g' )
        printf "cp ${tmpA} ${tmpB}\n" >> "$updateScript"
    }
    
    AddOrUpdateIfNewer()
    {
        local dirName="$1"
        local fileName="${2##*/}"
        
        if [ "$dirName" == "" ]; then
            local pathAndName="$fileName"
        else
            local pathAndName="${dirName}/${fileName}"
        fi

        #[[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Found File: ${pathAndName}"
        if [ ! -f "${PUBLIC_DIR}/${pathAndName}" ]; then
            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}File $pathAndName is new. Adding"
            AddCopyCommandToFile "$dirName" "$2"
            echo 0
        else
            # file already exists. Is it different?
            if [[ $(CalculateMd5 "${PUBLIC_DIR}/${pathAndName}") != $(CalculateMd5 "$2") ]]; then
                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}File $fileName has been updated."
                AddCopyCommandToFile "$dirName" "$2"
                echo 0
            else
                echo 2
            fi
        fi
    }

    local needUpdating=1
    local updateAvailAppStr=""
    
    # Delete any previous update script
    RemoveFile "$updateScript"
    
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Checking App updates" 
    local pathToDownloadedPublicDir="${WORKING_PATH}/${APP_DIR_NAME}"/CloverThemeManagerApp/CloverThemeManager/public
    if [ -d "$pathToDownloadedPublicDir" ]; then
        # Check each item against current ones in app
        
        for item in "$pathToDownloadedPublicDir"/*
        do
            needUpdating=1
            # Is this item a directory?
            if [[ -d "$item" ]]; then
                # if directory does not currently exist in app then add it.
                local dirName="${item##*/}"
                #[[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Found Directory: $dirName" 
                if [ ! -d "${PUBLIC_DIR}/${dirName}" ]; then
                    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Directory $dirName is new. Adding" 
                    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}cp $item $PUBLIC_DIR"
                    tmpA=$( echo "$item" | sed 's/ /\\ /g' )
                    tmpB=$( echo "$PUBLIC_DIR" | sed 's/ /\\ /g' )
                    printf "cp -R ${tmpA} ${tmpB}\n" >> "$updateScript"
                    updateAvailAppStr="${updateAvailAppStr},$dirName (New Directory)"
                else
                    # Directory already exists. Check each file for update.
                    # Note: No plans here for sub directories
                    for items in "$item"/*
                    do
                        if [[ -f "$items" ]]; then  
                            needUpdating=$( AddOrUpdateIfNewer "$dirName" "$items" )
                            if [ $needUpdating -eq 0 ]; then
                                updateAvailAppStr="${updateAvailAppStr},${dirName}/${items##*/}"
                            fi
                        fi
                    done
                fi
            
            # Is this item a file?
            elif [[ -f "$item" ]]; then
                needUpdating=$( AddOrUpdateIfNewer "" "$item" )
                if [ $needUpdating -eq 0 ]; then
                    updateAvailAppStr="${updateAvailAppStr},${item##*/}"
                fi
            fi

        done
    fi
    
    # Add copying .updateID to app public dir
    if [ -f "${pathToDownloadedPublicDir}"/.updateID ]; then
        AddCopyCommandToFile "" "${pathToDownloadedPublicDir}/.updateID"
    fi    
    
    if [ "$updateAvailAppStr" != "" ] && [ "${updateAvailAppStr:0:1}" == "," ]; then
        # Remove leading comma from string
        updateAvailAppStr="${updateAvailAppStr#?}"
        # Make note of scripts md5
        updateScriptChecksum=$(CalculateMd5 "$updateScript")
    else
        # No app update in the downloaded files. Can remove
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}No app updates. Deleting $pathToDownloadedPublicDir" 
        rm -rf "$pathToDownloadedPublicDir"
    fi
}

# ---------------------------------------------------------------------------------------
PerformUpdates()
{
    local successFlag=1
    if [ -f "$updateScript" ]; then

        # Check update script md5
        if [ $(CalculateMd5 "$updateScript") == $updateScriptChecksum ]; then

            WriteToLog "md5 matches."
            chmod 755 "$updateScript"
        
            # Check public directory is writeable
            CheckPathIsWriteable "${PUBLIC_DIR}"
            local isPathWriteable=$? # 1 = not writeable / 0 = writeable

            WriteToLog "Performing Updates"
            if [ $isPathWriteable -eq 1 ]; then # Not Writeable
               if [ $(CheckOsVersion) -ge 13 ]; then
                    successFlag=$( /usr/bin/osascript -e 'tell application "SecurityAgent" to activate'; /usr/bin/osascript -e "do shell script \"$uiSudoChanges \" & \"@UpdateApp\" & \"@$updateScript\" with administrator privileges" )
                else
                    successFlag=$( /usr/bin/osascript -e "do shell script \"$uiSudoChanges \" & \"@UpdateApp\" & \"@$updateScript\" with administrator privileges" )
                fi
           else
                WriteToLog "Public DIR is writeable"
                "$updateScript" && successFlag=0
            fi
        else
            WriteToLog "Error. $updateScript has invalid md5. Update not done."
        fi
    else
        WriteToLog "$updateScript not found."
    fi
    
    if [ $successFlag -eq 0 ]; then
        WriteToLog "Updates were successful."
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: UpdateAppFeedback@Success@"
        SendToUI "UpdateAppFeedback@Success@"
        
        # Remove update files
        cd "${WORKING_PATH}/${APP_DIR_NAME}"/CloverThemeManagerApp
        if [ -d "CloverThemeManager/public" ]; then
            rm -rf "CloverThemeManager/public"
        fi
        
        # Remove update script
        if [ -f "$updateScript" ]; then
            rm "$updateScript"
        fi
    else
        WriteToLog "Updates failed."
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: UpdateAppFeedback@Fail@"
        SendToUI "UpdateAppFeedback@Fail@"
    fi
    
    WriteLinesToLog
}

# ---------------------------------------------------------------------------------------
GetLatestIndexAndEnsureThemeHtml()
{
    BuildThemeTextInformation()
    {
        # Read local theme.plists and parse author and description info.
        # Create array of directory list alphabetically
        oIFS="$IFS"; IFS=$'\r\n'
        themeList=( $( ls -d "${WORKING_PATH}/${APP_DIR_NAME}"/themes/* | sort -f ))
    
        WriteToLog "Reading theme plists."
    
        # Read each themes' theme.plist from the repository to extract Author & Description.
        for ((n=0; n<${#themeList[@]}; n++ ));
        do
            tmpTitle="${themeList[$n]##*/}"
            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Reading theme plists for $tmpTitle" 
            themeTitle+=("$tmpTitle")
            themeAuthor+=( $(FindStringInPlist "Author" "${WORKING_PATH}/${APP_DIR_NAME}/themes/${tmpTitle}/theme.plist"))
            themeDescription+=( $(FindStringInPlist "Description" "${WORKING_PATH}/${APP_DIR_NAME}/themes/${tmpTitle}/theme.plist"))
        done
        IFS="$oIFS"
    }
    
    CloneAndCheckoutIndex()
    {
        local check=1
        
        # Remove index.git from a previous run
        if [ -d "${WORKING_PATH}/${APP_DIR_NAME}"/index.git ]; then
            WriteToLog "Removing previous index.git"
            rm -rf "${WORKING_PATH}/${APP_DIR_NAME}"/index.git
        fi
    
        # Remove any images from a previous run
        if [ -d "${WORKING_PATH}/${APP_DIR_NAME}"/images ]; then
            WriteToLog "Removing previous index images directory"
            rm -rf "${WORKING_PATH}/${APP_DIR_NAME}"/images
        fi
    
        # Remove any theme.plists from a previous run
        if [ -d "${WORKING_PATH}/${APP_DIR_NAME}"/themes ]; then
            WriteToLog "Removing previous index themes directory"
            rm -rf "${WORKING_PATH}/${APP_DIR_NAME}"/themes
        fi
            
        # Get new index.git from CloverRepo
        cd "${WORKING_PATH}/${APP_DIR_NAME}"
        WriteToLog "CTM_IndexCloneAndCheckout"
        WriteToLog "Cloning bare repo index.git"
        "$gitCmd" clone --depth=1 --bare "$remoteRepositoryUrl"/themes.git/index.git
        WriteToLog "Checking out index.git"
        "$gitCmd" --git-dir="${WORKING_PATH}/${APP_DIR_NAME}"/index.git --work-tree="${WORKING_PATH}/${APP_DIR_NAME}" checkout --force && check=0
        
        # Add message in to log for initialise.js to detect.
        if [ $check -eq 0 ]; then
            WriteToLog "CTM_IndexOK"
        else
            WriteToLog "CTM_IndexFail"
        fi
    }

    GetIndexAndProcessThemeList()
    {
        CloneAndCheckoutIndex
        BuildThemeTextInformation
        CreateThemeListHtml
        InsertThemeListHtmlInToManageThemes
    }
    
    if [ ! -d "${WORKING_PATH}/${APP_DIR_NAME}"/index.git ]; then
        GetIndexAndProcessThemeList
    else
        # Check existing index.git is not older than when repo was rebuilt
        # Clover Theme Repo was rebuilt on 14th December 2014. Any index.git
        # from before then will not fetch and needs to be deleted.
        # To be safe I am using 15th December 2104 as date to check.
        # epoch for that is calculated with: date -j -f "%d-%B-%y" 15-DEC-14 +%s
        # Giving epoch of: 1418667240
        repoRebuildEpoch=1418667240

        # Get epoch of existing index.git
        indexFileEpoch=$( stat -f "%m" "${WORKING_PATH}/${APP_DIR_NAME}"/index.git )
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}indexFileEpoch=$indexFileEpoch"
        if [ $indexFileEpoch -lt $repoRebuildEpoch ]; then
            WriteToLog "index.git is from before repo was rebuilt"
            GetIndexAndProcessThemeList
        else
            # Check for updates to index.git
            WriteToLog "Checking for update to index.git"
            cd "${WORKING_PATH}/${APP_DIR_NAME}"/index.git
            local updateCheck=$( "$gitCmd" fetch --progress origin master:master 2>&1 )
            if [[ "$updateCheck" == *done.*  ]]; then
                WriteToLog "index.git has been updated. Re-downloading"
                GetIndexAndProcessThemeList
            else
                WriteToLog "No updates to index.git"
                WriteToLog "CTM_IndexOK"
            
                # Use previously saved theme.html
                if [ -f "${WORKING_PATH}/${APP_DIR_NAME}"/theme.html ]; then
                    WriteToLog "CTM_ThemeListOK"
                    InsertThemeListHtmlInToManageThemes "file"
                else
                    WriteToLog "Error!. ${WORKING_PATH}/${APP_DIR_NAME}/theme.html not found"
                    BuildThemeTextInformation
                    CreateThemeListHtml
                    InsertThemeListHtmlInToManageThemes
                fi 
            fi
        fi
        
        # Check for help directory and add_theme.html file.
        addThemeHelpFile=$( find "${WORKING_PATH}/${APP_DIR_NAME}"/ -type f -name "add_theme.html" 2>/dev/null )
        if [ ! "$addThemeHelpFile" ]; then
            "$gitCmd" --git-dir="${WORKING_PATH}/${APP_DIR_NAME}"/index.git --work-tree="${WORKING_PATH}/${APP_DIR_NAME}" checkout --force
        fi  
    fi  

    WriteLinesToLog
}

# ---------------------------------------------------------------------------------------
GetFreeSpaceOfTargetDeviceAndSendToUI()
{
    # Read available space on volume and send to the UI.
    WriteToLog "Getting free space on target device $TARGET_THEME_DIR_DEVICE"

    oIFS="$IFS"; IFS=$'\r\n'
    deviceResult=( $( df -laH | grep "$TARGET_THEME_DIR_DEVICE" | awk '{print $1}' ))
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}deviceResult=$deviceResult"
    IFS="$oIFS"

    local found=99
    for (( d=0; d<${#deviceResult[@]}; d++ ))
    do
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}In Loop: d=$d"
        if [ "${deviceResult[$d]##*/}" == "$TARGET_THEME_DIR_DEVICE" ]; then
           found=$d
           [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}found=$found"
        fi
    done

    if [ $found -lt 99 ]; then
        local freeSpace=$(df -laH | grep "$TARGET_THEME_DIR_DEVICE" | awk '{print $4}' | head -n$(( found + 1 )) | tail -n1)
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: FreeSpace:$freeSpace"
    else
        local freeSpace="0M"
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}*Couldn't get free space."
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: FreeSpace:$freeSpace"
    fi
    SendToUI "FreeSpace@${freeSpace}@"
}

# ---------------------------------------------------------------------------------------
ReadThemeDirList()
{
    # Read /tmp/CloverThemeManager/themeDirInfo.txt file and populate
    # arrays for theme directory information.
    # themeDirInfo.txt is created by findThemeDirs.sh script.
    
    if [ -f "$themeDirInfo" ]; then
        oIFS="$IFS"; IFS=$'\r\n'
        while read -r line
        do
            duIdentifier+=( $( cut -d@ -f1 <<<"${line}" ))
            duVolumeName+=( $( cut -d@ -f2 <<<"${line}" ))
            duVolumeMountPoint+=( $( cut -d@ -f3 <<<"${line}" ))
            duContent+=( $( cut -d@ -f4 <<<"${line}" ))
            duPartitionGuid+=( $( cut -d@ -f5 <<<"${line}" ))
            themeDirPaths+=( $( cut -d@ -f6 <<<"${line}" ))
        done < "$themeDirInfo"
        IFS="$oIFS"
            
        # Check array contents match and send message to UI via log
        local total=${#duIdentifier[@]}
        if [ ${#duVolumeName[@]} -ne $total ] || [ ${#duVolumeMountPoint[@]} -ne $total ] || [ ${#duContent[@]} -ne $total ] || [ ${#duPartitionGuid[@]} -ne $total ] || [ ${#themeDirPaths[@]} -ne $total ]; then
            WriteToLog "CTM_ThemeDirsFail"
        
            # Print results
            for (( s=0; s<${#duIdentifier[@]}; s++ ))
            do
                WriteToLog "${duIdentifier[$s]} | ${duVolumeName[$s]} | ${duVolumeMountPoint[$s]} | ${duContent[$s]} | ${duPartitionGuid[$s]} | ${themeDirPaths[$s]}"
            done   
            exit 1 
        else
            WriteToLog "CTM_ThemeDirsOK" 
        fi
    else
        WriteToLog "Error. Missing $themeDirInfo file"
        WriteToLog "CTM_ThemeDirsOKFail"
    fi
}

# ---------------------------------------------------------------------------------------
ManageESP()
{
    # Read espList.txt file
    # Store indentifiers for unmounted ESP's in array
    # espList.txt is created by findThemeDirs.sh script.
    if [ -f "$espList" ]; then
        oIFS="$IFS"; IFS=$'\r\n'
        while read -r line
        do
            if [[ "$line" == *@U ]]; then
                unmountedEsp+=( "${line%@*}" )
            fi
        done < "$espList"
        IFS="$oIFS"

        # Loop through partitions
        for (( s=0; s<${#unmountedEsp[@]}; s++ ))
        do

            successFlag=1
            local mountPoint=`/usr/bin/mktemp -d /Volumes/${gESPMountPrefix}XXXXXXXXX`
            if [ ! "$mountPoint" == "" ]; then
               if [ $(CheckOsVersion) -ge 13 ]; then
                    successFlag=$( /usr/bin/osascript -e 'tell application "SecurityAgent" to activate'; /usr/bin/osascript -e "do shell script \"$uiSudoChanges \" & \"@MountESP\" & \"@/dev/${unmountedEsp[$s]}\" & \"@$mountPoint\" with administrator privileges" )
                else
                    successFlag=$( /usr/bin/osascript -e "do shell script \"$uiSudoChanges \" & \"@MountESP\" & \"@/dev/${unmountedEsp[$s]}\" & \"@$mountPoint\" with administrator privileges" )
                fi
               if [ $successFlag -eq 0 ]; then
                    (( gEspMounted++ ))
                fi
            fi
        done
    else
        WriteToLog "Error. Missing $espList file"
    fi
}

# ---------------------------------------------------------------------------------------
CreateAndSendVolumeDropDownMenu()
{
    # Send new dropdown list for UI
    for (( p=0; p<${#themeDirPaths[@]}; p++ ))
    do
        # Check if mountpoint is temporary for ESP partition.
        # If yes then make it human readable by changing to EFI.
        if [[ "${themeDirPaths[$p]}" == *$gESPMountPrefix* ]]; then
            local tmpStrip="${themeDirPaths[$p]#*/}"
            tmpStrip="${tmpStrip#*/}"
            tmpStrip="${tmpStrip#*/}"
            pathToPrint="/Volumes/EFI/${tmpStrip}"
            espID=$p
        else
            pathToPrint="${themeDirPaths[$p]}"
        fi
        local newPathList="${newPathList}","${p};${pathToPrint} [${duIdentifier[$p]}] [${duPartitionGuid[$p]}]"
    done

    if [ "$newPathList" != "" ]; then
        # Remove leading comma from string
        newPathList="${newPathList#?}"
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI message: NewVolumeDropDown@${newPathList}@"
        SendToUI "NewVolumeDropDown@${newPathList}@"
        return 0
    else
        # Still send UI DropDown message, even though there are no entries.
        SendToUI "NewVolumeDropDown@@"
        return 1
    fi
}

# ---------------------------------------------------------------------------------------
MountESPAndSearchThemesPath()
{
    WriteLinesToLog
    WriteToLog "User selected to Mount ESP and find EFI/Clover/Themes"
    WriteToLog "Searching for ESP's with /EFI/Clover/Themes"
    
    gEspMounted=0
    local currentMountedEspCount=$gEspMounted
    
    ManageESP
    if [ $gEspMounted -gt $currentMountedEspCount ]; then
    
        "$findThemeDirs"
        ResetInternalDiskArrays
        ReadThemeDirList
        
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI message: Mounted@${gEspMounted}"
        SendToUI "MessageESP@Mounted@${gEspMounted}"
        
        CreateAndSendVolumeDropDownMenu

        # As volume selector dropdown menu entries have changed,
        # send UI a partition to select
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: Target@$espID"
        SendToUI "Target@$espID"
        
        RespondToUserDeviceSelection "@$espID"
    else
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI message: Mounted@${gEspMounted}"
        SendToUI "MessageESP@Mounted@${gEspMounted}"
    fi
}

# ---------------------------------------------------------------------------------------
ReadPrefsFile()
{
    WriteToLog "Read user preferences file"
    # Check for preferences file
    if [ -f "$gUserPrefsFile".plist ]; then

        gLastSelectedPath=$( defaults read "$gUserPrefsFile" LastSelectedPath )
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}gLastSelectedPath=$gLastSelectedPath"
        
        gLastSelectedPathDevice=$( defaults read "$gUserPrefsFile" LastSelectedPathDevice )
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}gLastSelectedPathDevice=$gLastSelectedPathDevice"
        
        gLastSelectedPartitionGUID=$( defaults read "$gUserPrefsFile" LastSelectedPartitionGUID )
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}gLastSelectedPartitionGUID=$gLastSelectedPartitionGUID"
     
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Resetting internal theme arrays"
        ResetInternalThemeArrays
        
        gSnow=$( defaults read "$gUserPrefsFile" Snow )
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}gSnow=$gSnow"
        
        local tmp=$( defaults read "$gUserPrefsFile" Thumbnail )
        if [ "$tmp" != "" ]; then
            echo "$tmp" >> ~/Desktop/a.txt
            gThumbSizeX="${tmp% *}"
            gThumbSizeY="${tmp#* }"
            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}ThumbnailSize=${gThumbSizeX}x${gThumbSizeY}"
        fi
        
        gUISettingViewUnInstalled=$( defaults read "$gUserPrefsFile" UnInstalledButton )
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}gUISettingViewUnInstalled=${gUISettingViewUnInstalled}"
        
        gUISettingViewThumbnails=$( defaults read "$gUserPrefsFile" ViewThumbnails )
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}gUISettingViewThumbnails=${gUISettingViewThumbnails}"
        
        gUISettingViewPreviews=$( defaults read "$gUserPrefsFile" ShowPreviewsButton )
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}gUISettingViewPreviews=${gUISettingViewPreviews}"
        
        # Find installed themes
        oIFS="$IFS"; IFS=$'\n'
        local readVar=( $( defaults read "$gUserPrefsFile" InstalledThemes | grep = ) )
        IFS="$oIFS"

        # get total count of lines, less one for zero based index.
        local count=(${#readVar[@]}-1)
        foundThemeName=0
        for (( x=0; x<=$count; x++ ))
        do
            if [ $foundThemeName -eq 1 ] || [[ "${readVar[$x]}" == *ThemePath* ]]; then
                local tmpOption="${readVar[$x]%=*}"
                tmpOption="${tmpOption//[[:space:]]}"           # Remove whitespace
                local tmpValue="${readVar[$x]#*=}"
                tmpValue=$( echo "$tmpValue" | sed 's/^ *//')   # Remove leading whitespace  
                tmpValue=$( echo "$tmpValue" | tr -d '";' )     # Remove quotes and semicolon from the string
                case "$tmpOption" in
                           "ThemePath"       )   installedThemeName+=( "$themeName" )
                                                 installedThemePath+=("$tmpValue") ;;
                           "ThemePathDevice" )   installedThemePathDevice+=("$tmpValue") ;;
                           "VolumeUUID"      )   installedThemePartitionGUID+=("$tmpValue")
                                                 ;;
                esac
            fi

            # Look for an open parenthesis to indicate start of array entry
            if [[ "${readVar[$x]}" == *\(* ]]; then
                themeName="${readVar[$x]% =*}"                      # Remove all after ' ='    
                themeName=$( echo "$themeName" | sed 's/^ *//')     # Remove leading whitespace  
                themeName=$( echo "$themeName" | sed 's/\"//g' )    # Remove any quotes
                foundThemeName=1
            fi
        done
        
        # Map $gLastSelectedPath against $gLastSelectedPartitionGUID to catch differences
        # which will occur when using ESP. Internal random mountpoint gets written to 
        # prefs as /Volumes/EFI because random mountpoint will not happen again.
        if [ "$gLastSelectedPartitionGUID" != "" ] && [ "$gLastSelectedPath" != "" ] && [ "$gLastSelectedPathDevice" != "" ]; then
            
            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Mapping last selected partition GUID against mounted partition GUIDs"
            local checkPath=""
            for (( u=0; u<${#themeDirPaths[@]}; u++ ))
            do
                # Note: Two MBR partitioned, FAT32 formatted USB sticks will both have zero UUID.
                if [ $gLastSelectedPartitionGUID == $zeroUUID ]; then
                    if [ "${duPartitionGuid[$u]}" == "$zeroUUID" ]; then
                        # Attempt to match theme path
                        if [ "${themeDirPaths[$u]}" == "$TARGET_THEME_DIR" ]; then
                            checkPath="${themeDirPaths[$u]}"
                            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Match found:checkPath=$checkPath"
                            break
                        fi
                    fi
                else
                    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Checking ${duPartitionGuid[$u]} = $gLastSelectedPartitionGUID"
                    if [ "${duPartitionGuid[$u]}" == "$gLastSelectedPartitionGUID" ]; then
                        checkPath="${themeDirPaths[$u]}"
                        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Match found:checkPath=$checkPath"
                    fi
                fi
            done
            
            if [ "$checkPath" != "" ]; then
                TARGET_THEME_DIR="$checkPath"
            else
                TARGET_THEME_DIR="$gLastSelectedPath"
            fi
            TARGET_THEME_DIR_DEVICE="$gLastSelectedPathDevice"
            TARGET_THEME_PARTITIONGUID="$gLastSelectedPartitionGUID"
        else
            TARGET_THEME_DIR="-"
            TARGET_THEME_DIR_DEVICE="-"
            TARGET_THEME_PARTITIONGUID="-"
        fi
        
        # Add message in to log for initialise.js to detect.
        [[ $gFirstRun -eq 0 ]] && WriteToLog "CTM_ReadPrefsOK" && gFirstRun=1
        
    else
        WriteToLog "Preferences file not found."
        WriteLog "Creating initial prefs file: $gUserPrefsFile"
        defaults write "$gUserPrefsFile" "LastSelectedPath" "-"
        defaults write "$gUserPrefsFile" "LastSelectedPathDevice" "-"
        defaults write "$gUserPrefsFile" "LastSelectedPartitionGUID" "-"
        TARGET_THEME_DIR="-"
        TARGET_THEME_DIR_DEVICE="-"
        TARGET_THEME_PARTITIONGUID="-"
        
        # Add message in to log for initialise.js to detect.
        WriteToLog "CTM_ReadPrefsCreate"
    fi
    
    if [ "$gSnow" == "" ]; then
        gSnow="On"
    fi
    
    WriteToLog "TARGET_THEME_DIR=$TARGET_THEME_DIR"
    WriteToLog "TARGET_THEME_DIR_DEVICE=$TARGET_THEME_DIR_DEVICE"
    WriteToLog "TARGET_THEME_PARTITIONGUID=$TARGET_THEME_PARTITIONGUID"
        
    [[ DEBUG -eq 1 ]] && SendInternalThemeArraysToLogFile
}

# ---------------------------------------------------------------------------------------
SendInternalThemeArraysToLogFile()
{
    # This is only called if DEBUG is set to 1
    # It will loop through the internal arrays for installed themes and
    # print them to the log file.
    # They arrays are saved to prefs in MaintainInstalledThemeListInPrefs()
    
    WriteLinesToLog
    local totalPath="${#installedThemePath[@]}"
    local totalPathDevice="${#installedThemePathDevice[@]}"
    local totalVolUuid="${#installedThemePartitionGUID[@]}"
    if [ $totalPath -ne $totalPathDevice ] && [ $totalPath -ne $totalVolUuid ]; then
        WriteToLog "${debugIndent}Error. Preferences are corrupt"
        exit 1
    else
        WriteToLog "${debugIndent}Prefs shows total number of installed themes=${#installedThemeName[@]}"
        for ((n=0; n<${#installedThemeName[@]}; n++ ));
        do
            WriteToLog "${debugIndent}$n: ${installedThemeName[$n]}, ${installedThemePath[$n]}, ${installedThemePathDevice[$n]}, ${installedThemePartitionGUID[$n]}"
        done
    fi  
    WriteLinesToLog 
}

# ---------------------------------------------------------------------------------------
SendUIInitData()
{
    # This is called once after much of the initialisation routines have run.
    
    if [ ! "$TARGET_THEME_DIR" == "" ] && [ ! "$TARGET_THEME_DIR" == "-" ] ; then

        local entry=$( FindArrayIdFromTarget )
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}entry=$entry"
        CheckThemePathIsStillValid
        retVal=$? # returns 1 if invalid / 0 if valid
        if [ $retVal -eq 0 ]; then

            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: Target@$entry"
            SendToUI "Target@$entry"

            GetListOfInstalledThemesAndSendToUI
            GetFreeSpaceOfTargetDeviceAndSendToUI
        fi
        
        # Run this regardless of path chosen as JS is waiting to hear it. 
        CheckAndRecordUnManagedThemesAndSendToUI

        # Set redirect from initial page
        #WriteToLog "Redirect managethemes.html"
    else
        WriteToLog "NoPathSelected"
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: NoPathSelected@@"
        SendToUI "NoPathSelected@@"
        
        # Send list of updated themes to UI otherwise the UI interface will not be enabled.
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: UpdateAvailThemes@@"
        SendToUI "UpdateAvailThemes@@"
    fi
    
    # Send thumbnail size
    if [ $gThumbSizeX -gt 0 ] && [ $gThumbSizeY -gt 0 ]; then
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: ThumbnailSize@${gThumbSizeX}@${gThumbSizeY}"
        SendToUI "ThumbnailSize@${gThumbSizeX}@${gThumbSizeY}"
    fi
    
    # Send UI view choice for UnInstalled themes
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: UnInstalledView@${gUISettingViewUnInstalled}@"
    SendToUI "UnInstalledView@${gUISettingViewUnInstalled}@"
    
    # Send UI view choice for Thumbnails
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: ThumbnailView@${gUISettingViewThumbnails}@"
    SendToUI "ThumbnailView@${gUISettingViewThumbnails}@"
    
    # Send UI view choice for Previews
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: PreviewView@${gUISettingViewPreviews}@"
    SendToUI "PreviewView@${gUISettingViewPreviews}@"
    
    # Send UI setting for Snow
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: Snow@${gSnow}@"
    SendToUI "Snow@${gSnow}@"
    
    # Add message in to log for initialise.js to detect.
    WriteToLog "CTM_InitInterface"
}




# =======================================================================================
# After Initialisation Routines
# =======================================================================================




# ---------------------------------------------------------------------------------------
RespondToUserDeviceSelection()
{
    # Called from the Main Message Loop when a user has changed the
    # themes file path from the drop down menu in the UI.
    #
    # This routine takes the message, and splits it to find the device
    # and volume name. Then providing the user has not chosen 'Please Choose'
    # from the menu (indicated by a - for each device and volumeName), the 
    # path is double checked before writing the choice to the user prefs file.
    #
    # Two routines are then called:
    # 1 - to get a list of theme directories at selected file path.
    # 2 - to check for any updates to those theme directories.
        
    local messageFromUi="$1"

    WriteLinesToLog

    # parse message
    # remove everything up until, and including, the first @
    local messageFromUi="${messageFromUi#*@}"
    local pathOption="${messageFromUi##*@}"
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}RespondToUserDeviceSelection() messageFromUi=$messageFromUi | pathOption=$pathOption"
    # Check user did actually change from default
    if [ ! "$pathOption" == "-" ]; then

        WriteToLog "User selected path: ${themeDirPaths[$pathOption]} on device ${duIdentifier[$pathOption]} with UUID ${duPartitionGuid[$pathOption]}" 

        local mountpoint=$( ResolveMountPointFromUUID "${duPartitionGuid[$pathOption]}" )
        if [ "$mountpoint" != "" ]; then
            TARGET_THEME_DIR="$mountpoint"
        else
            TARGET_THEME_DIR="${themeDirPaths[$pathOption]}"
        fi
        TARGET_THEME_DIR_DEVICE="${duIdentifier[$pathOption]}"
        TARGET_THEME_PARTITIONGUID="${duPartitionGuid[$pathOption]}"

        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}TARGET_THEME_DIR=$TARGET_THEME_DIR"
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}TARGET_THEME_DIR_DEVICE=$TARGET_THEME_DIR_DEVICE"
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}TARGET_THEME_PARTITIONGUID=$TARGET_THEME_PARTITIONGUID"
        
        CheckThemePathIsStillValid
        retVal=$? # returns 1 if invalid / 0 if valid
        if [ $retVal -eq 0 ]; then
        
            UpdatePrefsKey "LastSelectedPath" "$TARGET_THEME_DIR"  
            UpdatePrefsKey "LastSelectedPathDevice" "$TARGET_THEME_DIR_DEVICE"
            UpdatePrefsKey "LastSelectedPartitionGUID" "$TARGET_THEME_PARTITIONGUID"
        
            GetListOfInstalledThemesAndSendToUI
            GetFreeSpaceOfTargetDeviceAndSendToUI
            CheckAndRecordUnManagedThemesAndSendToUI
            CheckAndRemoveBareClonesNoLongerNeeded
            ReadAndSendCurrentNvramTheme
            CheckForThemeUpdates &
        else
            # Run these regardless of path chosen as JS is waiting to hear it. 
            CheckAndRecordUnManagedThemesAndSendToUI
            CheckForThemeUpdates &
        fi
    else
        WriteToLog "User de-selected Volume path and chose menu title. Do Nothing."
        TARGET_THEME_DIR="-"
        TARGET_THEME_DIR_DEVICE="-"
        TARGET_THEME_PARTITIONGUID="-"
        
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Setting prefs for default dir,path & GUID to -"
        UpdatePrefsKey "LastSelectedPath" "$TARGET_THEME_DIR"  
        UpdatePrefsKey "LastSelectedPathDevice" "$TARGET_THEME_DIR_DEVICE"
        UpdatePrefsKey "LastSelectedPartitionGUID" "$TARGET_THEME_PARTITIONGUID"
        
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: InstalledThemes@-@"
        SendToUI "InstalledThemes@-@"
    fi
}

# ---------------------------------------------------------------------------------------
RespondToUserThemeAction()
{
    local messageFromUi="$1"

    # remove everything up until, and including, the first @
    messageFromUi="${messageFromUi#*@}"
    chosenTheme="${messageFromUi%%@*}"
    desiredAction="${messageFromUi##*@}"
    
    # further strip theme name and action
    chosenTheme="${chosenTheme##*button_}"
    desiredAction="${desiredAction##*button}"

    # Note - desiredAction will be either: Install, UnInstall or Update
    
    if [ ! "$chosenTheme" == "" ] && [ ! "$desiredAction" == "" ]; then
        WriteLinesToLog
        WriteToLog "User chose to $desiredAction theme $chosenTheme"
        
        CheckThemePathIsStillValid
        retVal=$? # returns 1 if invalid / 0 if valid
        if [ $retVal -eq 0 ]; then
            RunThemeAction "$desiredAction" "$chosenTheme"
            return $?
        else
            return 1
        fi
    fi
}

# ---------------------------------------------------------------------------------------
RespondToUserSnowToggle()
{
    local messageFromUi="$1"

    # remove everything up until, and including, the first @
    messageFromUi="${messageFromUi#*@}"
    chosenOption="${messageFromUi##*:}"

    if [ ! "$chosenOption" == "" ]; then
        WriteLinesToLog
        if [ "$chosenOption" == "On" ]; then
            WriteToLog "User chose to set enable Snow."
            gSnow="On"
            UpdatePrefsKey "Snow" "On"
        elif [ "$chosenOption" == "Off" ]; then
            WriteToLog "User chose to set disable Snow."
            gSnow="Off"
            UpdatePrefsKey "Snow" "Off"
        fi
    fi
}

# ---------------------------------------------------------------------------------------
CheckThemePathIsStillValid()
{
    local findDevice=""
    local stillMounted=0
    
    # Find device by previously used UUID.
    if [ "$TARGET_THEME_PARTITIONGUID" != "$zeroUUID" ]; then
        findDevice=$( "$partutil" --search-uuid $TARGET_THEME_PARTITIONGUID )
    else
        findDevice="$TARGET_THEME_DIR_DEVICE"
    fi
    
    # Match device to current list of mounted partitions with valid theme paths.
    if [ "$findDevice" != "" ]; then
        for ((i=0; i<${#duIdentifier[@]}; i++))
        do
            if [ $findDevice == ${duIdentifier[$i]} ]; then
                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Device $TARGET_THEME_PARTITIONGUID is ${duIdentifier[$i]}"
                stillMounted=1
                # Ensure current TARGET_THEME_DIR_DEVICE matches device
                TARGET_THEME_DIR_DEVICE=${duIdentifier[$i]}
            fi
        done
    fi
            
    if [ $stillMounted -eq 0 ]; then
        WriteToLog "Theme directory $TARGET_THEME_DIR on $TARGET_THEME_PARTITIONGUID does not exist! Setting to -"
        
        local entry=$( FindArrayIdFromTarget )
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}entry=$entry"
        local pathToPrint="$TARGET_THEME_DIR"
        if [ "$entry" != "-" ]; then
            if [[ "${themeDirPaths[$entry]}" == *$gESPMountPrefix* ]]; then
                local tmpStrip="${themeDirPaths[$entry]#*/}"
                tmpStrip="${tmpStrip#*/}"
                tmpStrip="${tmpStrip#*/}"
                pathToPrint="/Volumes/EFI/${tmpStrip}"
            fi
        fi
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: NotExist@${TARGET_THEME_PARTITIONGUID}@${pathToPrint}@$entry"
        SendToUI "NotExist@${TARGET_THEME_PARTITIONGUID}@${pathToPrint}@$entry"

        WriteToLog "NoPathSelected"
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: NoPathSelected@@"
        SendToUI "NoPathSelected@@"
        
        # Re-build theme directory list
        "$findThemeDirs"
        ResetInternalDiskArrays
        ReadThemeDirList
        CreateAndSendVolumeDropDownMenu
        SendToUI "Target@-@"
        RespondToUserDeviceSelection "@-"

        return 1
    else
        WriteToLog "Theme directory $TARGET_THEME_DIR exists."
        return 0
    fi
}

# ---------------------------------------------------------------------------------------
GetListOfInstalledThemesAndSendToUI()
{
    # Scan the selected EFI/Clover/Themes directory for a list of installed themes.
    # The user could add themes without using the app so we need to keep to track of
    # what's there.
    # Send the list of installed themes to the UI.
    
    installedThemeStr=""
    unset installedThemesFoundAfterSearch
    unset installedThemesOnCurrentVolume
    if [ "$TARGET_THEME_DIR" != "" ] && [ "$TARGET_THEME_DIR" != "-" ]; then
        WriteToLog "Looking for installed themes at $TARGET_THEME_DIR on $TARGET_THEME_DIR_DEVICE"
        oIFS="$IFS"; IFS=$'\r\n'
        installedThemesFoundAfterSearch=( $( find "$TARGET_THEME_DIR"/* -type d -depth 0 ))
        for ((i=0; i<${#installedThemesFoundAfterSearch[@]}; i++))
        do
            installedThemesOnCurrentVolume[$i]="${installedThemesFoundAfterSearch[$i]##*/}"
            # Create comma separated string for sending to the UI
            installedThemeStr="${installedThemeStr},${installedThemesOnCurrentVolume[$i]}"
            WriteToLog "Found installed theme: ${installedThemesOnCurrentVolume[$i]}"
        done
        IFS="$oIFS"
        # Remove leading comma from string
        installedThemeStr="${installedThemeStr#?}"
    else
        WriteToLog "Can't check for installed themes at $TARGET_THEME_DIR"
    fi
    
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: InstalledThemes@${installedThemeStr}@"
    SendToUI "InstalledThemes@${installedThemeStr}@"
}

# ---------------------------------------------------------------------------------------
CheckThemeIsInPrefs()
{
    # Check for any inconsistency where a theme entry in user prefs may be missing when
    # it's clearly installed in the users EFI/Clover/Themes directory AND has a parent
    # bare clone in the support directory.
    # If found - Add this theme in to prefs.
    
    local themeToFind="$1"
    local inPrefs=0
    
    for ((n=0; n<${#installedThemeName[@]}; n++ ))
    do
        if [ "${installedThemeName[$n]}" == "$themeToFind" ] && [ "${installedThemePartitionGUID[$n]}" == "$TARGET_THEME_PARTITIONGUID" ]; then
            inPrefs=1
        fi
    done
    
    if [ $inPrefs -eq 0 ]; then
        # Should add in to prefs
        WriteToLog "* $themeToFind is in ${TARGET_THEME_DIR} and bare clone exists but not in prefs! Adding now."

        # Add the details for this theme for adding to prefs file
        gNewInstalledThemeName="$themeToFind"
        gNewInstalledThemePath="$TARGET_THEME_DIR"
        gNewInstalledThemePathDevice="$TARGET_THEME_DIR_DEVICE"
        gNewinstalledThemePartitionGUID="$TARGET_THEME_PARTITIONGUID"
        
        # Run routine to update prefs file.
        MaintainInstalledThemeListInPrefs  
    fi
}

# ---------------------------------------------------------------------------------------
CheckAndRecordUnManagedThemesAndSendToUI()
{
    # Note: installedThemesOnCurrentVolume[] contains list of themes installed on the current theme path.
    # Plan: loop through this array and check for existence of .hash file
    #       Create list of any installed themes missing a .hash file in $unversionedThemeStr
    # Send the list to the UI so a cross is drawn to the right of the 'UnInstall' button.
    
    if [ ! "$TARGET_THEME_DIR" == "-" ]; then
        WriteToLog "Checking $TARGET_THEME_DIR for any unmanaged themes (without a .hash)."
        unversionedThemeStr=""
        local prefsNeedUpdating=0
        for ((t=0; t<${#installedThemesOnCurrentVolume[@]}; t++))
        do
        
            #if [ ! -d "${WORKING_PATH}/${APP_DIR_NAME}"/"${installedThemesOnCurrentVolume[$t]}.git" ]; then
                #WriteToLog "${TARGET_THEME_DIR}/${installedThemesOnCurrentVolume[$t]} is missing parent bare clone from support dir!"
                
            # Check for .hash inside installed theme dir
            if [ ! -f "$TARGET_THEME_DIR"/"${installedThemesOnCurrentVolume[$t]}"/.hash ]; then
                WriteToLog "${TARGET_THEME_DIR}/${installedThemesOnCurrentVolume[$t]} has no hash"
        
                # Append to list of themes that cannot be checked for updates
                unversionedThemeStr="${unversionedThemeStr},${installedThemesOnCurrentVolume[$t]}"
            
                # Remove any pref entry for this theme
                for ((d=0; d<${#installedThemeName[@]}; d++))
                do
                    if [ "${installedThemeName[$d]}" == "${installedThemesOnCurrentVolume[$t]}" ] && [ "${installedThemePartitionGUID[$d]}" == "${TARGET_THEME_PARTITIONGUID}" ] && [ "$TARGET_THEME_PARTITIONGUID" != "$zeroUUID" ]; then
                        # Doing this will effectively delete the theme from prefs as it 
                        # will be skipped in the loop in MaintainInstalledThemeListInPrefs()
                        WriteToLog "Housekeeping: Will remove prefs entry for ${installedThemeName[$d]} on $TARGET_THEME_PARTITIONGUID"
                        prefsNeedUpdating=1
                        installedThemeName[$d]="-"
                    fi
                done
            else
                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}${TARGET_THEME_DIR}/${installedThemesOnCurrentVolume[$t]} has parent bare clone in support dir"
                # Match - theme dir in users theme path that also has a parent bare clone in app support dir.
                # Double check this is also in user prefs file.
                if [ "$TARGET_THEME_PARTITIONGUID" != "$zeroUUID" ]; then
                    CheckThemeIsInPrefs "${installedThemesOnCurrentVolume[$t]}"
                fi
            fi
        done
    
        # Run routine to update prefs file.
        if [ $prefsNeedUpdating -eq 1 ]; then
            MaintainInstalledThemeListInPrefs  
        fi
    
        # Remove leading comma from string
        unversionedThemeStr="${unversionedThemeStr#?}"
    
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI list of themes not installed by this app: UnversionedThemes@${unversionedThemeStr}@"
        SendToUI "UnversionedThemes@${unversionedThemeStr}@"
    fi
}

# ---------------------------------------------------------------------------------------
ReadAndSendCurrentNvramTheme()
{
    readNvramVar=$( nvram -p | grep Clover.Theme | tr -d '\011' )

    # Extract theme name
    local themeName="${readNvramVar##*Clover.Theme}"

    if [ ! -z "$readNvramVar" ]; then
        WriteToLog "Clover.Theme NVRAM variable is set to $themeName"
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: Nvram@${themeName}@"
        SendToUI "Nvram@${themeName}@"
        # Add message in to log for initialise.js to detect.
        WriteToLog "CTM_NvramFound"
    else
        WriteToLog "Clover.Theme NVRAM variable is not set"
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: Nvram@-@"
        SendToUI "Nvram@-@"
        # Add message in to log for initialise.js to detect.
        WriteToLog "CTM_NvramNotFound"
    fi
}

# ---------------------------------------------------------------------------------------
SetNvramTheme()
{
    local messageFromUi="$1"

    # remove everything up until, and including, the first @
    messageFromUi="${messageFromUi#*@}"
    chosenTheme="${messageFromUi%%@*}"
    if [ $(CheckOsVersion) -ge 13 ]; then
        # com.apple.security.agentStub on Mavericks?
        successFlag=$( /usr/bin/osascript -e 'tell application "SecurityAgent" to activate'; /usr/bin/osascript -e  "do shell script \"$uiSudoChanges \" & \"@SetNVRAMVar\" & \"@${chosenTheme}\" with administrator privileges" )
    else
        successFlag=$( /usr/bin/osascript -e  "do shell script \"$uiSudoChanges \" & \"@SetNVRAMVar\" & \"@${chosenTheme}\" with administrator privileges" )
    fi
    # Was operation a success?
    if [ $successFlag -eq 0 ]; then
        WriteToLog "Setting NVRAM Variable was successful."
    else
        WriteToLog "Setting NVRAM Variable failed."
    fi
    
    # Read current Clover.Theme Nvram variable and send to UI.
    ReadAndSendCurrentNvramTheme
}

# ---------------------------------------------------------------------------------------
CheckIfThemeNoLongerInstalledThenDeleteLocalTheme()
{
    # If all instances of a local bare repo theme.git have been uninstalled
    # then delete the local bare repo.
    
    local passedThemeName="$1"
    local foundTheme=0
    for ((n=0; n<${#installedThemeName[@]}; n++ ));
    do
        if [ "${installedThemeName[$n]}" == "$passedThemeName" ]; then
            WriteToLog "Keeping ${passedThemeName}.git local bare repo as it's still in use."
            foundTheme=1
            break
        fi
    done
    if [ $foundTheme -eq 0 ]; then
        if [ -d "${WORKING_PATH}/${APP_DIR_NAME}/${passedThemeName}".git ]; then
            #WriteToLog "Local bare repo ${passedThemeName}.git is no longer in use. Deleting."
            WriteToLog "Local bare repo ${passedThemeName}.git is now being deleted."
            rm -rf "${WORKING_PATH}/${APP_DIR_NAME}/${passedThemeName}".git
        fi
    fi
}

# ---------------------------------------------------------------------------------------
CheckForThemeUpdates()
{
    # Note: installedThemesOnCurrentVolume[] contains list of themes installed on the current theme path.
    # Plan: loop through this array and check for parent bare-repo theme.git in Support Dir.
    #       If parent-repo theme.git is found then cd in to it and run a git fetch.

    #local updateWasFound=0
    
    # Send UI a blank update message to enable UI.
    SendToUI "UpdateAvailThemes@@"
    
    local updateAvailThemeStr=""

    if [ "$TARGET_THEME_DIR" != "-" ]; then
    
        WriteToLog "Checking $TARGET_THEME_DIR for any theme updates."
    
        for ((t=0; t<${#installedThemesOnCurrentVolume[@]}; t++))
        do
            # read hash from currently installed theme
            if [ -f "$TARGET_THEME_DIR"/"${installedThemesOnCurrentVolume[$t]}"/.hash ]; then
                local themeHashLocal=$( cat "$TARGET_THEME_DIR"/"${installedThemesOnCurrentVolume[$t]}"/.hash )
                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}themeHashLocal=$themeHashLocal"

                # get hash of theme in the repo
                local themeHashRepo=$( "$gitCmd" ls-remote git://git.code.sf.net/p/cloverefiboot/themes.git/themes/"${installedThemesOnCurrentVolume[$t]}"/theme | grep refs/heads/master )
                themeHashRepo="${themeHashRepo:0:40}"
                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}themeHashRepo=$themeHashRepo"

                if [ "$themeHashRepo" != "" ]; then
                    if [ "$themeHashLocal" != "$themeHashRepo" ]; then
                        # Theme has been updated.
                        WriteToLog "${installedThemesOnCurrentVolume[$t]} has an update available."
                        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}hash diff: $themeHashLocal | $themeHashRepo"
                        updateAvailThemeStr="${updateAvailThemeStr},${installedThemesOnCurrentVolume[$t]}" 
                    else
                        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}hash matches. No update for ${installedThemesOnCurrentVolume[$t]}"
                    fi
                else
                    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Failed to read hash for ${installedThemesOnCurrentVolume[$t]} from repository."
                fi
            fi
        done
        
        if [ "$updateAvailThemeStr" != "" ] && [ "${updateAvailThemeStr:0:1}" == "," ]; then
            # Remove leading comma from string
            updateAvailThemeStr="${updateAvailThemeStr#?}"
        fi
        
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}Sending UI: UpdateAvailThemes@${updateAvailThemeStr}@"
        SendToUI "UpdateAvailThemes@${updateAvailThemeStr}@"
    fi
    
    WriteToLog "Checking for updates complete."
}

# ---------------------------------------------------------------------------------------
CheckAndRemoveBareClonesNoLongerNeeded()
{   
    # Check each installed theme entry in prefs against themes installed in current
    # /EFI/Clover/Themes dir selected by user.
    # If prefs says a theme should be on selected volume but it's not (maybe user
    # manually removed it?), then remove entry from prefs.
    # Also check to see if the bare clone in support dir can be deleted.
    
    if [ ! "$TARGET_THEME_DIR" == "-" ]; then
    
        foundCloneToDelete=0
        prefsNeedUpdating=0
        # Loop through themes installed in prefs file
        for ((n=0; n<${#installedThemeName[@]}; n++ ));
        do
            # Check current partition GUID in prefs matches current partition GUID
            if [ "${installedThemePartitionGUID[$n]}" == "$TARGET_THEME_PARTITIONGUID" ]; then
                # Is theme installed in current theme dir?
                local themeIsInDir=0
                for ((t=0; t<${#installedThemesOnCurrentVolume[@]}; t++))
                do
                    if [ "${installedThemeName[$n]}" == "${installedThemesOnCurrentVolume[$t]}" ]; then
                        themeIsInDir=1
                        break
                    fi
                done
                if [ $themeIsInDir -eq 0 ]; then
                    WriteToLog "Housekeeping: ${installedThemeName[$n]} exists in prefs for $TARGET_THEME_DIR but it's not installed!"
                    foundCloneToDelete=1

                    # if bare clone exists in support dir then there's a chance it could be deleted.
                    if [ -d "${WORKING_PATH}/${APP_DIR_NAME}/${installedThemeName[$n]}".git ]; then

                        # Need to check the bare clone is not needed for a different volume though..
                        for ((x=0; x<${#installedThemeName[@]}; x++ ));
                        do
                            if [ "${installedThemeName[$n]}" == "${installedThemeName[$x]}" ]; then
                                if [ "${installedThemePath[$n]}" != "${installedThemePath[$x]}" ]; then
                                   foundCloneToDelete=0
                                fi
                            fi
                        done

                        if [ $foundCloneToDelete -eq 1 ]; then
                            WriteToLog "Housekeeping: Deleting bare clone ${installedThemeName[$n]}.git"
                            cd "${WORKING_PATH}/${APP_DIR_NAME}"
                            rm -rf "${installedThemeName[$n]}".git
                        else
                            WriteToLog "Housekeeping: Keeping bare clone ${installedThemeName[$n]}.git as it's used on another volume."
                        fi
                    fi
                
                    # Set theme name to -
                    # Doing this will effectively delete the theme from prefs as it 
                    # will be skipped in the loop in MaintainInstalledThemeListInPrefs()
                    WriteToLog "Housekeeping: Will remove prefs entry for ${installedThemeName[$n]} in $TARGET_THEME_DIR"
                    prefsNeedUpdating=1
                    installedThemeName[$n]="-"
                fi
            fi
        done
    
        # Run routine to update prefs file.
        if [ $foundCloneToDelete -eq 1 ] || [ $prefsNeedUpdating -eq 1 ]; then
            MaintainInstalledThemeListInPrefs  
        fi
    fi
}

# ---------------------------------------------------------------------------------------
CleanInstalledThemesPrefEntries()
{
    # Check for and remove any duplicate installed theme entries from prefs.
    # This should not happen in the first place but I have found some examples
    # during my local testing here. Could be a bug that needs finding!
    
    foundEntryToDelete=0
    for ((n=0; n<${#installedThemeName[@]}; n++ ));
    do
        for ((m=0; m<${#installedThemeName[@]}; m++ ));
        do
            if [ $m -ne $n ] && [ "${installedThemeName[$n]}" == "${installedThemeName[$m]}" ]; then
                # Found another theme entry by same name
                # Is this installed elsewhere or a duplicate entry?
                if [ "${installedThemePath[$n]}" == "${installedThemePath[$m]}" ] && [ "${installedThemePathDevice[$n]}" == "${installedThemePathDevice[$m]}" ] && [ "${installedThemePartitionGUID[$n]}" == "${installedThemePartitionGUID[$m]}" ]; then
                    # Duplicate entry. Remove
                    foundEntryToDelete=1
                    WriteToLog "Housekeeping: Removing duplicate prefs entry for ${installedThemeName[$n]} at ${installedThemePath[$n]}."
                    installedThemeName[$n]="-"
                fi
            fi
        done
    done
    
    # Run routine to update prefs file.
    if [ $foundEntryToDelete -eq 1 ]; then
        MaintainInstalledThemeListInPrefs  
    fi
}

# ---------------------------------------------------------------------------------------
IsGitInstalled()
{
    WriteLinesToLog
    local tmp=$( which -a git )
    local num=$( which -a git | wc -l )
    WriteToLog "Number of git installations: ${num##* }"
    WriteToLog "git installations: $tmp"
    
    if [ $( which -s git) ]; then 
        # Alert user in UI
        WriteToLog "CTM_GitFail"
    else
        # a git file exists which is a start.
        gitCmd=$( which git )
           
        # However....
        # File /usr/bin/git exists by default from virgin OS X install.
        # But this is not the actual git executable that's installed
        # with Xcode command line tools.
        # /usr/bin/xcrun can find and return true location.
        
        # $ /usr/bin/xcrun --find git
        # Applications/Xcode.app/Contents/Developer/usr/bin/git
        
        # But....
        # If user has not installed the Xcode command line developer tools
        # then trying to run /usr/bin/git or /usr/bin/xcrun will result in a
        # dialog in the Finder and also the following command line message:
        #     xcode-select: note: no developer tools were found at
        #     '/Applications/Xcode.app', requesting  install. Choose an option
        #     in the dialog to download the command line developer tools.
        # Thing is, we don't want to see a dialog box pop up in the Finder,
        # well not yet anyway.
        
        # Also, user may not want to install full Xcode command line tools.
        # They have the option to just install git from http://git-scm.com
        # If they install only git then we can use that.
        # Note: git installer creates:
        #       directory /usr/local/git contain git files.
        #       file /etc/paths.d/git containing /usr/local/git/bin
        #       file /etc/manpaths.d/git containing /usr/local/git/bin/share/man
        # The paths.d entry appends /usr/local/git/bin to the end of $PATH
        # So we can't call git using just 'git' or /usr/bin/git gets called.
        
        # Also.... 
        # We can't prepend /usr/local/git/bin to $PATH because
        # the users local command line returns different results to
        # what's returned from the command line when launched from a GUI app.
        # This could be a Yosemite? bug but any adjusted $PATH from say
        # a users ~/.bash_profile does not get presented to script from GUI. 
            
        # For example from the users local command line:
        # $ which -a git
        # /usr/local/git/bin/git    <-- $PATH entry added in ~/.bash_profile
        # /usr/bin/git

        # But from script launched from app
        # $ which -a git
        # /usr/bin/git              <-- $PATH entry (above) is missing
        
        # So let's check for the full path and use that (if present).
        # Check for installed git from http://git-scm.com
        if [ -f /usr/local/git/bin/git ]; then
            gitCmd="/usr/local/git/bin/git"
        else
            # Nope..
            # Time to actually run /usr/bin/git and see if Xcode developer
            # tools have been installed. If not a dialog will show in Finder.
            if [ "$gitCmd" == "/usr/bin/git" ]; then
                local catchReturn=$( /usr/bin/git 2>&1)
                if [[ "$catchReturn" == *"no developer tools were found"* ]]; then
                    WriteToLog "CTM_GitFail"
                    gitCmd=""
                else
                    gitCmd="/usr/bin/git"
                fi
            fi
        fi
        
        if [ "$gitCmd" != "" ]; then
            WriteToLog "using git at:$gitCmd"
            WriteToLog "$( $gitCmd --version )"
            WriteToLog "CTM_GitOK"
        fi
    fi
    WriteLinesToLog
}

# ---------------------------------------------------------------------------------------
CleanUp()
{
    RemoveFile "$logJsToBash"
    RemoveFile "$logFile"
    RemoveFile "$themeDirInfo"
    RemoveFile "$logBashToJs"
    RemoveFile "$updateScript"
    RemoveFile "$espList"
    
    if [ -d "$tmp_dir" ]; then
        rm -rf "$tmp_dir"
    fi
    if [ -d "/tmp/CloverThemeManager" ]; then
        rmdir "/tmp/CloverThemeManager"
    fi
    if [ -f "${PUBLIC_DIR}"/managethemes.html ]; then
        rm "${PUBLIC_DIR}"/managethemes.html
    fi
    if [ -f "${PUBLIC_DIR}"/scripts/cloverthememanager.jse ]; then
        rm "${PUBLIC_DIR}"/scripts/cloverthememanager.js
        mv "${PUBLIC_DIR}"/scripts/cloverthememanager.jse "${PUBLIC_DIR}"/scripts/cloverthememanager.js
    fi
}

#===============================================================
# Main
#===============================================================


# Make sure this script exits when parent app is closed.
# Get process ID of this script
scriptPid=$( echo "$$" )
# Get process ID of parent
appPid=$( ps -p ${pid:-$$} -o ppid= )

# Resolve path
SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P) && SELF_PATH=$SELF_PATH/$(basename -- "$0")

# Set out other directory paths based on SELF_PATH
PUBLIC_DIR="${SELF_PATH%/*}"
PUBLIC_DIR="${PUBLIC_DIR%/*}"
ASSETS_DIR="$PUBLIC_DIR"/assets
SCRIPTS_DIR="$PUBLIC_DIR"/bash
JSSCRIPTS_DIR="$PUBLIC_DIR"/scripts
TOOLS_DIR="$PUBLIC_DIR"/tools
WORKING_PATH="${HOME}/Library/Application Support"
APP_DIR_NAME="CloverThemeManager"
TARGET_THEME_DIR=""
TARGET_THEME_DIR_DEVICE=""
TARGET_THEME_PARTITIONGUID=""
TMPDIR="/tmp/CloverThemeManager"
UNPACKDIR="${WORKING_PATH}/${APP_DIR_NAME}/UnPack"
COMMANDLINE=0

logFile="${TMPDIR}/CloverThemeManagerLog.txt"
themeDirInfo="${TMPDIR}/themeDirInfo.txt"
espList="${TMPDIR}/espList.txt"
logJsToBash="${TMPDIR}/jsToBash" # Note - this is created in AppDelegate.m
logBashToJs="${TMPDIR}/bashToJs" # Note - this is created in AppDelegate.m
updateScript="${TMPDIR}/updateScript.sh"
gUserPrefsFileName="org.black.CloverThemeManager"
gUserPrefsFile="$HOME/Library/Preferences/$gUserPrefsFileName"
gThemeRepoUrlFile="$PUBLIC_DIR"/theme_repo_url_list.txt
uiSudoChanges="${SCRIPTS_DIR}/uiSudoChangeRequests.sh"
findThemeDirs="${SCRIPTS_DIR}/findThemeDirs.sh"
gUiPwCancelledStr="zYx1!ctm_User_Cancelled!!xYz"
remoteRepositoryUrl="http://git.code.sf.net/p/cloverefiboot"
debugIndent="    "
gThumbSizeX=0
gThumbSizeY=0
gUISettingViewUnInstalled="Show"
gUISettingViewThumbnails="Show"
gUISettingViewPreviews="Hide"
gFirstRun=0
gEspMounted=0
gitCmd=""
gESPMountPrefix="ctmTempMp"
gSnow="On"

export zeroUUID="00000000-0000-0000-0000-000000000000"
export partutil="$TOOLS_DIR"/partutil

# Get versions of js scripts
#jsScriptInitVersion=$( grep "//Version=" "$JSSCRIPTS_DIR"/initialise.js )
#jsScriptInitVersion="${jsScriptInitVersion##*=}"
#jsScriptCtmVersion=$( grep "//Version=" "$JSSCRIPTS_DIR"/cloverthememanager.js )
#jsScriptCtmVersion="${jsScriptCtmVersion##*=}"
updateIdVersion=$( cat "${PUBLIC_DIR}"/.updateID )

# Find version of main app.
mainAppInfoFilePath="${SELF_PATH%Resources*}"
mainAppVersion=$( /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$mainAppInfoFilePath"/Info.plist  )

# Begin log file
RemoveFile "$logFile"
WriteToLog "CTM_VersionApp ${mainAppVersion} (updateID ${updateIdVersion})"
WriteToLog "Started Clover Theme Manager script"
WriteLinesToLog
WriteToLog "scriptPid=$scriptPid | appPid=$appPid"
WriteLinesToLog
WriteToLog "PATH=$PATH"

# Ensure permissions of findThemeDirs script
if [ -f "$findThemeDirs" ]; then
    chmod 755 "$findThemeDirs"
    WriteToLog "Set permissions of findThemeDirs script"
fi

IsGitInstalled

# Only continue if git is installed
if [ "$gitCmd" != "" ]; then

    # Was this script called from a script or the command line
    identityCallerCheck=`ps -o stat= -p $$`
    if [ "${identityCallerCheck:1:1}" == "+" ]; then
        # Called from command line so interpret arguments.

        # Will expect 2 arguments
        # 1 - The install path
        # 2 - The theme name

        if [ "$#" -eq 2 ]; then
	        TARGET_THEME_DIR="$1"
	        themeToInstall="$2"
        else
	        echo "Error - wrong number of arguments passed."
	        echo "Expects 1st as full target path. 2nd Theme name"
	        exit 1
        fi

        # Redirect all log file output to stdout
        COMMANDLINE=1

        # Should we be checking the theme exists on the repo?
        # Currently this does not happen.
    
        # Does theme path exist?
        if [ -d "$TARGET_THEME_DIR" ]; then
            RunThemeAction "Install" "$themeToInstall"
            returnValue=$?
            if [ ${returnValue} -eq 0 ]; then
                # Operation was successful
                echo "Theme $themeToInstall was successfully installed to $TARGET_THEME_DIR"
                exit 0
            else
                echo "Error - Theme $themeToInstall failed to be installed to $TARGET_THEME_DIR"
                exit 1
            fi
        else
            echo "Error - Target path $TARGET_THEME_DIR does not exist."
            exit 1
        fi
    
    else
        # Called from Clover Theme Manager.app

        declare -a themeList
        declare -a themeTitle
        declare -a themeAuthor
        declare -a themeDescription
        declare -a dfMounts
        declare -a tmpArray
    
        # Arrays for saving volume info
        declare -a duIdentifier
        declare -a duVolumeName
        declare -a duVolumeMountPoint
        declare -a duContent
        declare -a duPartitionGuid
        declare -a unmountedEsp
    
        # Arrays for theme
        declare -a themeDirPaths
        declare -a installedThemesOnCurrentVolume
        declare -a installedThemesFoundAfterSearch
    
        # Arrays for list of what themes are installed where.
        declare -a installedThemeName
        declare -a installedThemePath
        declare -a installedThemePathDevice
        declare -a installedThemePartitionGUID

        # Globals for newly installed theme before adding to prefs
        ResetNewlyInstalledThemeVars
        ResetUnInstalledThemeVars

        # For using additional theme repositories.
        # Not working in this version
        #declare -a repositoryUrls
        #declare -a repositoryThemes
        #tmp_dir=$(mktemp -d -t theme_manager)
        #ReadRepoUrlList

        # Begin        
        "$findThemeDirs" &
        RefreshHtmlTemplates "managethemes.html"
        IsRepositoryLive
        EnsureLocalSupportDir

        # Clean any old files from support dir from previous app versions
        if [ -f "${WORKING_PATH}/${APP_DIR_NAME}"/*.plist ]; then
            rm "${WORKING_PATH}/${APP_DIR_NAME}"/*.plist
        fi
        if [ -f "${WORKING_PATH}/${APP_DIR_NAME}"/dropdown_html ]; then
            rm "${WORKING_PATH}/${APP_DIR_NAME}"/dropdown_html
        fi
        if [ -f "${WORKING_PATH}/${APP_DIR_NAME}"/theme_html ]; then
            rm "${WORKING_PATH}/${APP_DIR_NAME}"/theme_html
        fi
        
        EnsureSymlinks
        GetLatestIndexAndEnsureThemeHtml
        WriteToLog "CTM_ThemeDirsScan"
        wait
        ReadThemeDirList
        CreateAndSendVolumeDropDownMenu
        if [ $? -eq 0 ]; then
            WriteToLog "CTM_DropDownListOK"
        else
            WriteToLog "CTM_DropDownListNone"
        fi
        ReadPrefsFile
        CleanInstalledThemesPrefEntries
        SendUIInitData

        # Read current Clover.Theme Nvram variable and send to UI.
        ReadAndSendCurrentNvramTheme
        
        # If OS is newer than Lion then enable notifications
        if [ $(CheckOsVersion) -gt 11 ]; then
            InsertNotificationCodeInToJS
        fi
    
        # Write string to mark the end of init file.
        # initialise.js looks for this to signify initialisation is complete.
        # At which point it then redirects to the main UI page.
        WriteToLog "Complete!"      
        
        # Feedback for command line
        echo "Initialisation complete. Entering loop."

        # Remember parent process id
        parentId=$appPid

        CheckAndRemoveBareClonesNoLongerNeeded
        CheckForAppUpdate
        retVal=$? # returns 1 if no update / 0 if valid is available
        # If update available then user will be notified so do not check for theme updates.
        if [ $retVal -eq 1 ]; then
            CheckForThemeUpdates &
        fi

        # The messaging system is event driven and quite simple.
        # Run a loop for as long as the parent process ID still exists
        while [ "$appPid" == "$parentId" ];
        do
            sleep 0.25  # Check every 1/4 second.
    
            #===============================================================
            # Main Message Loop for responding to UI feedback
            #===============================================================

            # Read first line of log file
            logLine=$(head -n 1 "$logJsToBash")
        
            # Has user selected partition for an /EFI/Clover/themes directory?
            if [[ "$logLine" == *CTM_selectedPartition* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                # js sends "CTM_selectedPartition@" + selectedPartition
                # where selectedPartition is the array element id of 
                RespondToUserDeviceSelection "$logLine"
    
            # Has the user clicked the OpenPath button?
            elif [[ "$logLine" == *OpenPath* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                CheckThemePathIsStillValid
                retVal=$? # returns 1 if invalid / 0 if valid
                if [ $retVal -eq 0 ]; then
                    [[ ! "$TARGET_THEME_DIR" == "-" ]] && Open "$TARGET_THEME_DIR"
                fi
                WriteToLog "User selected to open $TARGET_THEME_DIR"

            # Has the user clicked the MountESP button?
            elif [[ "$logLine" == *MountESP* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                MountESPAndSearchThemesPath

            # Has the user pressed a theme button to install, uninstall or update?
            elif [[ "$logLine" == *CTM_ThemeAction* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                RespondToUserThemeAction "$logLine"
                returnValue=$?
                if [ ${returnValue} -eq 0 ]; then
                    # Operation was successful
                    GetListOfInstalledThemesAndSendToUI
                    GetFreeSpaceOfTargetDeviceAndSendToUI
                    CheckAndRecordUnManagedThemesAndSendToUI
                    CheckForThemeUpdates &
                    ReadAndSendCurrentNvramTheme
                fi 

            # Has user selected a theme for NVRAM variable?
            elif [[ "$logLine" == *CTM_chosenNvramTheme* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                WriteToLog "User chose to set nvram theme."
                SetNvramTheme "$logLine"
            
            # Has user changed the thumbnail size?
            elif [[ "$logLine" == *CTM_thumbSize* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                # parse message
                # remove everything up until, and including, the first @
                thumbSize="${logLine#*@}"
                UpdatePrefsKey "Thumbnail" "$thumbSize"
                WriteToLog "User changed thumbnail size to $thumbSize"
            
            # Has user chosen to hide uninstalled themes?
            elif [[ "$logLine" == *CTM_hideUninstalled* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                UpdatePrefsKey "UnInstalledButton" "Show"
                WriteToLog "User chose to show uninstalled themes"
            
            # Has user chosen to show uninstalled themes?
            elif [[ "$logLine" == *CTM_showUninstalled* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                UpdatePrefsKey "UnInstalledButton" "Hide"
                WriteToLog "User chose to hide uninstalled themes"
            
            # Has user chosen to show thumbnails?
            elif [[ "$logLine" == *CTM_hideThumbails* ]]; then
               ClearTopOfMessageLog "$logJsToBash"
                UpdatePrefsKey "ViewThumbnails" "Show"
                WriteToLog "User chose to show thumbnails"
            
            # Has user chosen to hide thumbnails?
            elif [[ "$logLine" == *CTM_showThumbails* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                UpdatePrefsKey "ViewThumbnails" "Hide"
                WriteToLog "User chose to hide thumbnails"
            
            # Has user chosen to hide previews?
            elif [[ "$logLine" == *CTM_hidePreviews* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                UpdatePrefsKey "ShowPreviewsButton" "Hide"
                WriteToLog "User chose to hide previews"
            
            # Has user chosen to show preview?
            elif [[ "$logLine" == *CTM_showPreviews* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                UpdatePrefsKey "ShowPreviewsButton" "Show"
                WriteToLog "User chose to show previews"
            
            # Has user chosen to show preview?
            elif [[ "$logLine" == *CTM_updateApp* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                RespondToUserUpdateApp "$logLine"
                
            # Has user chosen to toggle snow?
            elif [[ "$logLine" == *CTM_Snow* ]]; then
                ClearTopOfMessageLog "$logJsToBash"
                RespondToUserSnowToggle "$logLine"
                
            elif [[ "$logLine" == *started* ]]; then
                ClearTopOfMessageLog "$logJsToBash"  
            fi

            # Get process ID of parent
            appPid=$( ps -p ${pid:-$$} -o ppid= )
        done
        CleanUp    
        exit 0
    fi
else
    WriteToLog "CTM_GitFail"
    exit 1
fi