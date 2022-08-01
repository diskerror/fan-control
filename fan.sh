#!/usr/bin/env bash

declare -r SYSDIR="/sys/devices/platform/applesmc.768"

declare -Ax fan_info
declare -i f

function fan_exists() {
    declare -i fan=$1
    if [[ ! -f "$SYSDIR/fan${fan}_label" ]]; then
        echo -n 1
        return
    fi
    echo -n
}

function get_fan_info() {
    declare -i fan=$1

    fan_info['manual_file']="$SYSDIR/fan${fan}_manual"
    fan_info['output_file']="$SYSDIR/fan${fan}_output"
    read -r fan_info['label'] < "$SYSDIR/fan${fan}_label"
    fan_info['label']=${fan_info['label'],,}                # lower case
    read -r fan_info['manual'] < ${fan_info['manual_file']}
    read -r fan_info['min'] < "$SYSDIR/fan${fan}_min"
    read -r fan_info['output'] < ${fan_info['output_file']} # target speed
    read -r fan_info['max'] < "$SYSDIR/fan${fan}_max"
    read -r fan_info['input'] < "$SYSDIR/fan${fan}_input"   # actual speed
}

# fan() - set fan
# $1 is fan number (starting from 1)
# $2 is speed to apply
function set_fan_speed() {
    declare -i fan_100 fan_net fan_final
    local speed="$2"                  # "auto" or 0-100

    get_fan_info $1

    if [ "$speed" = "auto" ]; then
        # Switch back fan1 to auto mode
        echo "0" > ${fan_info['manual_file']}
        printf "fan %d mode set to auto\n" $1
    else
        #Putting fan on manual mode
        if [ ${fan_info['manual']} = "0" ]; then
            echo "1" > $fan_info['manual_file']
        fi

        if [ "$speed" -le 100 ]; then
            # Calculating the net value that will be given to the fans
            fan_100=$((fan_info['max'] - fan_info['min']))

            # Calculating final speedage value
            fan_net=$((speed * fan_100 / 100))
            fan_final=$((fan_net + fan_info['min']))
        elif [ "$speed" -lt ${fan_info['min']} ]; then
            fan_final=$fan_info['min']
        elif [ "$speed" -gt ${fan_info['max']} ]; then
            fan_final=$fan_info['max']
        else
            fan_final=$speed
        fi

        # Writing the final value to the applemc files
        echo "$fan_final" > ${fan_info['output_file']}
    fi
}

function usage() {
    printf "usage: %s get [<fan>]|set <fan> <speed>]\n" "${0##*/}"
    printf '  command: get or set\n'
    printf '  fan: fan number or "all"\n'
    printf '  speed: "auto", a percentage between min and max, or absolute value\n'
}

########################################################################################################################
# MAIN

if [[ ! -d $SYSDIR ]]; then
    echo 'Cannot be used on this hardware.'
    exit 1
fi

case "$1" in
    '')
        usage
        exit 0
        ;;

    'get')
        case "$2" in
            'all' | '')
                printf "Available fans:\n"
                printf "  %s  % -10s % 4s % 4s % 4s  % 7s\n" '#' 'label' 'min' 'set' 'max' 'current'
                f=1
                while [[ $(fan_exists $f) -eq 0 ]]; do
                    get_fan_info $f
                    if [[ ${fan_info['manual']} == 0 ]]; then
                        target_speed="auto"
                    else
                        target_speed=${fan_info['output']}
                    fi
                    printf "  %d  % -10s % 4s % 4s % 4s  % 7s\n" $f ${fan_info['label']} ${fan_info['min']} $target_speed ${fan_info['max']} ${fan_info['input']}
                    ((f++))
                done
                ;;

            1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9)
                echo "not implemented yet"
                ;;

            *)
                printf 'unknown fan choice %s\n' "$2"
                usage
                exit 1
                ;;
        esac
        ;;

    'set')
        if [[ "root" != $(whoami) ]]; then
	        echo "must be root"
	        exit 1
        fi

        case "$2" in
            'all')
                f=1
                while [[ $(fan_exists $f) -eq 0 ]]; do
                    set_fan_speed "$f" "$3"
                    ((f++))
                done
                ;;

            1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9)
                set_fan_speed "$2" "$3"
                ;;

            *)
                printf 'unknown fan choice %s\n' "$2"
                usage
                exit 1
                ;;
        esac
        ;;

    *)
        printf 'unknown command %s\n' "$1"
        usage
        exit 1
        ;;
esac

exit 0
