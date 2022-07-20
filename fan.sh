#!/usr/bin/env bash
#

sysdir="/sys/devices/platform/applesmc.768"

declare -A fan_info
declare -i fan f

function get_fan_info() {
    declare -i fan=$1
    if [[ ! -f "$sysdir/fan${fan}_label" ]]; then
        echo 1
        return
    fi

    fan_info['manual_file']="$sysdir/fan${fan}_manual"
    fan_info['output_file']="$sysdir/fan${fan}_output"
    read -r fan_info['label'] < "$sysdir/fan${fan}_label"
    fan_info['label']=${fan_info['label'],,}                # lower case
    read -r fan_info['manual'] < ${fan_info['manual_file']}
    read -r fan_info['min'] < "$sysdir/fan${fan}_min"
    read -r fan_info['output'] < ${fan_info['output_file']} # target speed
    read -r fan_info['max'] < "$sysdir/fan${fan}_max"
    read -r fan_info['input'] < "$sysdir/fan${fan}_input"   # actual speed
    echo -n
}

# fan() - set fan
# $1 is fan number (starting from 1)
# $2 is percent to apply
function fan_function() {
    declare -i fan_100 fan_net fan_final
    local percent="$2"                  # "auto" or 0-100

    get_fan_info $1

    if [ "$percent" = "auto" ]; then
        # Switch back fan1 to auto mode
        echo "0" > ${fan_info['manual_file']}
        printf "fan mode set to auto"
    else
        #Putting fan on manual mode
        if [ ${fan_info['manual']} = "0" ]; then
            echo "1" > ${fan_info['manual_file']}
        fi

        # Calculating the net value that will be given to the fans
        fan_100=$((fan_info['max'] - fan_info['min']))
        # Calculating final percentage value
        fan_net=$((percent * fan_100 / 100))
        fan_final=$((fan_net + fan_info['min']))

        # Writing the final value to the applemc files
        if echo "$fan_final" > ${fan_info['output_file']}; then
            printf "fan set to %d rpm.\n" "$fan_final"
        else
            printf "Try running command as sudo\n"
        fi
    fi
}

function usage() {
    printf "usage: %s [fan percent|auto]\n" "${0##*/}"
    printf '  fan: fan number or "auto"\n'
    printf '  percent: "auto" or a value between 0 and 100\n'
}

########################################################################################################################
# MAIN

if [[ ! -d $sysdir ]]; then
    echo 'Cannot be used on this hardware.'
    exit 1
fi

if (($# == 0)); then
    printf "Available fans:\n"
    printf "  %s  % -10s % 4s % 4s % 4s  % 7s\n" '#' 'name' 'min' 'set' 'max' 'current'
    f=1
    while [[ $(get_fan_info $f) -eq 0 ]]; do
        get_fan_info $f
        if [[ ${fan_info['manual']} == 0 ]]; then
            target_speed="auto"
        else
            target_speed=${fan_info['output']}
        fi
        printf "  %d  % -10s % 4s % 4s % 4s  % 7s\n" $f ${fan_info['label']} ${fan_info['min']} $target_speed ${fan_info['max']} ${fan_info['input']}
        ((f++))
    done
    exit 0
fi

case "$1" in
    '')
        usage
        exit 0
        ;;

    auto)
        fan=1
        while [[ $(get_fan_info $fan) -eq 0  ]]; do
            get_fan_info $fan
            echo "0" > "${fan_info['manual_file']}"
            ((fan++))
        done
        echo "all fans set to auto"
        ;;

    1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9)
        fan_function "$1" "$2"
        ;;

    *)
        printf 'unknown command %s\n' "$1"
        usage
        exit 1
        ;;
esac
