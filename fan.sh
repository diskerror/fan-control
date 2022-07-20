#!/usr/bin/env bash
#

sysdir="/sys/devices/platform/applesmc.768"

declare -a control_file output_file label

# retrieve fan info
declare -i fan=1
while [[ -f "$sysdir/fan${fan}_label" ]]; do
    control_file[$fan]="$sysdir/fan${fan}_manual"
    output_file[$fan]="$sysdir/fan${fan}_output"
    read -r label[$fan] < "$sysdir/fan${fan}_label"
    label[$fan]=${label[$fan],,}                  # lowercase
    ((fan++))
done

# fan() - set fan
# $1 is fan number (starting from 1)
# $2 is percent to apply
fan_function() {
    declare -i manual max min
    declare -i fan_100 fan_net fan_final
    declare -i fan="$1"
    local percent="$2"                  # "auto" or 0-100

    # Getting fan files and data from applesmc.768
    read -r manual < "${control_file[$fan]}"
    read -r max < "$sysdir/fan${fan}_max"
    read -r min < "$sysdir/fan${fan}_min"

    if [ "$percent" = "auto" ]; then
        # Switch back fan1 to auto mode
        echo "0" > "${control_file[$fan]}"
        printf "fan mode set to auto"
    else
        #Putting fan on manual mode
        if [ "$manual" = "0" ]; then
            echo "1" > "${control_file[$fan]}"
        fi

        # Calculating the net value that will be given to the fans
        fan_100=$((max - min))
        # Calculating final percentage value
        fan_net=$((percent * fan_100 / 100))
        fan_final=$((fan_net + min))

        # Writing the final value to the applemc files
        if echo "$fan_final" > "${output_file[$fan]}"; then
            printf "fan set to %d rpm.\n" "$fan_final"
        else
            printf "Try running command as sudo\n"
        fi
    fi
}

usage() {
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
    f=1
    while [[ "${label[$f]}" ]]; do
        printf "  %d  %s\n" $f "${label[((f++))]}"
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
        while [[ "${label[$fan]}" ]]; do
            echo "0" > "${control_file[((fan++))]}"
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
