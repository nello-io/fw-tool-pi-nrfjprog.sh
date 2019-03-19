nrfprog.sh
==========

This is a loose shell port of the nrfjprog.exe program distributed by Nordic.
It relies on JLinkExe (from https://www.segger.com/jlink-software.html) to
interface with the JLink hardware.

The generated scripts were basically lifted from the Makefiles distributed with
the [nrf51-pure-gcc-setup](https://github.com/hlnd/nrf51-pure-gcc-setup)
project, so much thanks to @hlnd.

usage:

```bash
nrfjprog.sh <action> [hexfile]
```

where action is one of:

* `--info`
* `--reset`
* `--pin-reset`
* `--erase-all`
* `--flash`
* `--flash-softdevice`
* `--rtt`
* `--gdbserver`
* `--memwr <addr> --val <val>`
* `--memrd <addr> [--w <width>]`
* `--verify <binfile>`

Some useful Parameters:

* `--family`: specify a device family `nRF52`, `nRF52840_xxAA`, etc
