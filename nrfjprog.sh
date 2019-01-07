#!/bin/bash

read -d '' USAGE <<- EOF
nrfprog.sh

This is a loose shell port of the nrfjprog.exe program distributed by Nordic,
which relies on JLinkExe to interface with the JLink hardware.

usage:

nrfjprog.sh <action> [action parameters]

where action is one of
  --info
  --reset
  --pin-reset
  --erase-all
  --flash               <hexfile>
  --flash-softdevice    <hexfile>
  --rtt
  --gdbserver
  --memwr <addr> --val <val>
  --memrd <addr> [--w <width>]
  --savebin             <binfile>

Parameters:
  --familiy     specify a custom device family, <nRF52 (default), nRF52840_xxAA, etc.>

EOF

GREEN="\033[32m"
RESET="\033[0m"
STATUS_COLOR=$GREEN


TOOLCHAIN_PREFIX=arm-none-eabi
# assume the tools are on the system path
TOOLCHAIN_PATH=
JLINK="JLinkExe"
JLINKGDBSERVER="JLinkGDBServer"
JLINKRTTSERVER=JLinkExe
JLINKRTTCLIENT=JLinkRTTClient

# Defaults
DEVICE="nRF52"
IF="SWD"
SPEED="4000"
EMUSERIAL=""
GDB_PORT=2331
WIDTH=4
EXITONERROR=1


function msg {
    echo ""
    echo -e "${STATUS_COLOR}${1}${RESET}"
    echo ""
}


# As long as there is at least one more argument, keep looping
while [[ $# -gt 0 ]]; do
    key="$1"
    case "$key" in
        -f|--family)
        shift
        DEVICE=$1
        ;;
        -p|--port)
        shift
        GDB_PORT="$1"
        ;;
        -c|--clockspeed)
        shift
        SPEED="$1"
        ;;
        -s|--snr)
        shift
        EMUSERIAL=$1
        ;;
        -e|--erase-all)
        CMD="erase-all"
        ;;
        -i|--ids)
        CMD="showserials"
        ;;
        -r|--reset)
        CMD="reset"
        ;;
        -R|--pinreset---pin-reset)
        CMD="pinreset"
        ;;
        -f|--flash|--program)
        shift
        CMD="flash"
        HEX="$1"
        ;;
        --savebin)
        shift
        CMD="savebin"
        BIN="$1"
        ;;
        --w)
        shift
        WIDTH="$1"
        ;;
        -F|--flash-softdevice)
        shift
        CMD="flash-softdevice"
        HEX="$1"
        ;;
        -t|--rtt)
        CMD="rtt"
        ;;
        -g|--gdbserver)
        CMD="gdbserver"
        ;;
        -p|--port)
        shift
        GDB_PORT="$1"
        ;;
        --memwr)
        shift
        CMD="memwr"
        ADDR="$1"
        ;;
        --val)
        shift
        VAL="$1"
        ;;
        --memrd)
        shift
        CMD="memrd"
        ADDR="$1"
        ;;
        --w)
        shift
        WIDTH="$1"
        ;;
        # This is an arg=value type option. Will catch -o=value or --output-file=value
        -o=*|--output-file=*)
        # No need to shift here since the value is part of the same string
        OUTPUTFILE="${key#*=}"
        ;;
        *)
        # Do whatever you want with extra options
        echo "Unknown option '$key'"
        ;;
    esac
    # Shift after checking all the cases to get the next option
    shift
done


echo CMD=$CMD
echo DEVICE=$DEVICE
echo EMUSERIAL=$EMUSERIAL
echo HEX=$HEX

echo ADDR=$ADDR
echo VAL=$VAL
# the script commands come from Makefile.posix, distributed with
# nrf51-pure-gcc. I've made some changes to use hexfiles instead of binfiles

TMPSCRIPT=/tmp/tmp_$$.jlink

touch $TMPSCRIPT

if [ "$EMUSERIAL" ]; then
    echo "SelectEmuBySN $EMUSERIAL" >> $TMPSCRIPT
fi

# exit on error
echo "exitonerror $EXITONERROR" >> $TMPSCRIPT
echo "device $DEVICE" >> $TMPSCRIPT
echo "if $IF" >> $TMPSCRIPT
echo "speed $SPEED" >> $TMPSCRIPT

function runscript {
    $JLINK < $TMPSCRIPT
    code=$?
    rm $TMPSCRIPT
    if [ $code = 1 ]; then
        exit $code
    fi
}

if [ "$CMD" = "info" ]; then
    echo "connect" >> $TMPSCRIPT
    echo "exit" >> $TMPSCRIPT
    runscript
elif [ "$CMD" = "showserials" ]; then
    echo "showemulist usb" >> $TMPSCRIPT
    echo "exit" >> $TMPSCRIPT
    runscript
elif [ "$CMD" = "reset" ]; then
    echo resetting...
    echo "r" >> $TMPSCRIPT
    echo "g" >> $TMPSCRIPT
    echo "exit" >> $TMPSCRIPT
    runscript
elif [ "$CMD" = "pinreset" ]; then
    echo resetting with pin...
    echo "w4 40000544 1" >> $TMPSCRIPT
    echo "r" >> $TMPSCRIPT
    echo "exit" >> $TMPSCRIPT
    runscript
elif [ "$CMD" = "erase-all" ]; then
    echo ""
    msg perfoming full erase...
    echo ""
    echo "h" >> $TMPSCRIPT
    echo "w4 4001e504 2" >> $TMPSCRIPT
    echo "w4 4001e50c 1" >> $TMPSCRIPT
    echo "sleep 100" >> $TMPSCRIPT
    echo "r" >> $TMPSCRIPT
    echo "exit" >> $TMPSCRIPT
    runscript
elif [ "$CMD" = "flash" ]; then
    msg flashing ${HEX}...
    echo "r" >> $TMPSCRIPT
    echo "h" >> $TMPSCRIPT
    echo "loadfile $HEX" >> $TMPSCRIPT
    echo "r" >> $TMPSCRIPT
    echo "g" >> $TMPSCRIPT
    echo "exit" >> $TMPSCRIPT
    runscript
elif [ "$CMD" = "savebin" ]; then
    msg save mem to ${BIN}...
    echo "r" >> $TMPSCRIPT
    echo "h" >> $TMPSCRIPT
    echo "savebin $BIN 0x00 $WIDTH" >> $TMPSCRIPT
    echo "r" >> $TMPSCRIPT
    echo "g" >> $TMPSCRIPT
    echo "exit" >> $TMPSCRIPT
    runscript
elif [ "$CMD" = "flash-softdevice" ]; then
    echo flashing softdevice ${HEX}...
    # Halt, write to NVMC to enable erase, do erase all, wait for completion. reset
    echo "h"  >> $TMPSCRIPT
    echo "w4 4001e504 2" >> $TMPSCRIPT
    echo "w4 4001e50c 1" >> $TMPSCRIPT
    echo "sleep 100" >> $TMPSCRIPT
    echo "r" >> $TMPSCRIPT
    # Halt, write to NVMC to enable write. Write mainpart, write UICR. Assumes device is erased.
    echo "h" >> $TMPSCRIPT
    echo "w4 4001e504 1" >> $TMPSCRIPT
    echo "loadfile $HEX" >> $TMPSCRIPT
    echo "r" >> $TMPSCRIPT
    echo "g" >> $TMPSCRIPT
    echo "exit" >> $TMPSCRIPT
    runscript
elif [ "$CMD" = "memwr" ]; then
    # Check val is set
    if [ -z "$VAL" ]; then
        echo "using memwr without specifying a value"
        exit 1
    else
        echo "r" >> $TMPSCRIPT
        echo "h" >> $TMPSCRIPT
        echo "w4 $ADDR, $VAL" >> $TMPSCRIPT
        echo "r" >> $TMPSCRIPT
        echo "g" >> $TMPSCRIPT
        echo "exit" >> $TMPSCRIPT
        runscript
    fi
elif [ "$CMD" = "memrd" ]; then
    echo "mem $ADDR, $WIDTH" >> $TMPSCRIPT
    echo "exit" >> $TMPSCRIPT
    runscript
elif [ "$CMD" = "rtt" ]; then
    # trap the SIGINT signal so we can clean up if the user CTRL-C's out of the
    # RTT client
    trap ctrl_c INT
    function ctrl_c() {
        return
    }
    echo -e "${STATUS_COLOR}Starting RTT Server...${RESET}"
    $JLINKRTTSERVER -device $DEVICE -if $IF -speed $SPEED -autoconnect 1 &
    JLINK_PID=$!
    sleep 1
    echo -e "\n${STATUS_COLOR}Connecting to RTT Server...${RESET}"
    #telnet localhost 19021
    $JLINKRTTCLIENT
    echo -e "\n${STATUS_COLOR}Killing RTT server ($JLINK_PID)...${RESET}"
    kill $JLINK_PID
elif [ "$CMD" = "gdbserver" ]; then
    $JLINKGDBSERVER -port $GDB_PORT  -device $DEVICE -if $IF -speed $SPEED
else
    echo "$USAGE"
fi
