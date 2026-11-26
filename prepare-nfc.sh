#!/bin/sh
set -eu

gpio=/sys/class/gpio
if [ ! -c /dev/i2c-1 ] || [ ! -e "$gpio/export" ]; then
    printf '%s
' 'NFC needs /dev/i2c-1 and the host sysfs GPIO interface.' >&2
    exit 1
fi

# The PN7160 driver uses global sysfs numbers, not GPIO line offsets.
header_gpio=$gpio/gpiochip0
if [ ! -d "$header_gpio" ] ||
    [ "$(head -n 1 "$header_gpio/label")" != pinctrl-bcm2711 ] ||
    ! [ "$(head -n 1 "$header_gpio/ngpio")" -gt 25 ]; then
    printf '%s
' 'NFC needs the Pi 4 header GPIO controller at sysfs base 0 with lines 23–25.' >&2
    exit 1
fi

for pin in 23 24 25; do
    if [ ! -d "$gpio/gpio$pin" ]; then
        printf '%s
' "$pin" > "$gpio/export"
    fi
done
