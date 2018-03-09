JTAGulator Change Log
=====================

Visit the JTAGulator [github repository](https://github.com/grandideastudio/jtagulator/commits/master) for full commit comments.


1.5
---
Release date: **March 12, 2018**

* JTAG: Fixed `BYPASS_Scan` permutation calculation error when pins are known.

* JTAG: Fixed `Set_JTAG_Partial` error checking to make sure known pins are within range.

* UART: Optimized `UART_Passthrough` to reduce dropped characters when receiving contiguous blocks of data.

* UART: Allow user to ignore non-printable characters (except CR and LF) during `UART_Scan` and `UART_Scan_TXD`. 

* UART: Allow user to skip a channel during `UART_Scan_TXD` without needing to abort entirely.

* UART: Modified the time per channel calculations in `UART_Scan_TXD`.

* General: Allow whole numbers to be accepted by `Set_Target_IO_Voltage`.

* General: Added .travis.yml script for use with Travis CI, which provides continuous integration/build of the JTAGulator code base using PropellerIDE and openspin (thanks to stephengroat).


1.4
---
Release date: **November 3, 2016**

* JTAG: Added command to transfer an instruction and data to/from a target (`X`). This is useful for testing and preliminary fuzzing. Requires a known JTAG pinout and assumes a single device in the chain.

* JTAG: Added Instruction/Data Register (IR/DR) discovery command (`Y`). Inspired by UrJTAG's `discovery` command, this is useful for identifying available (and possibly undocumented) instructions of a target. Requires a known JTAG pinout and assumes a single device in the chain.

* JTAG: Added `Detect_IR_Length` and `Detect_DR_Length` methods to automatically detect the length of the Instruction Register (IR) and Data Register (DR, given a specified IR), respectively.

* UART: Added UART scanning command (`T`) to detect the target TXD pin only using a number of configurable parameters (baud rate range, timeout duration, number of loops per permutation, pause between permutations) (thanks to alexmaloteaux).

* UART: Allow user to disable TXD or RXD pin during `UART_Passthrough`.

* GPIO: Added command to continuously read/monitor all channels (`C`) (thanks to HexView).

* GPIO: Modified `Write_IO_Pins` to remember the previously entered value.

* General: Wait until the user presses a key on power-up/reset before sending the JTAGulator header and command prompt.

* General: Implemented submenu system to break up the list of commands by interface (thanks to HexView).

* General: Added warning to start-up text that use of this tool may affect target system behavior.

* General: Minor code cleanup and optimizations.

* Release for [Black Hat Europe 2016 Tools Arsenal](https://www.blackhat.com/eu-16/arsenal.html).


1.3
---
Release date: **December 25, 2015**

* JTAG: Added support during `BYPASS_Scan` to accept known pins, if any. This can greatly reduce search time, especially if `IDCODE_Scan` was done first to identify all pins except for TDI.

* JTAG: Better verification of `BYPASS_Scan` results (limit to 32 maximum devices in the chain, calls `BYPASS_Test` again to ensure that the detected pin configuration actually works).

* JTAG: Modified `IDCODE_Known` to work without needing to know the number of devices in the JTAG chain.

* JTAG: Modified `BYPASS_Known` to automatically detect the number of devices in the JTAG chain (instead of asking the user).

* JTAG: Changed TDI to idle HIGH during `Get_Device_IDs` to conform to the IEEE 1149.1 specification.

* General: User can now specify a range of channels to scan instead of always starting at CH0 (`Get_Channels`). This allows multiple ports/targets to be hooked up to the JTAGulator without being forced to scan them all at the same time.

* General: JTAGulator will now remember the most recently detected pinout during a scan (until reset or a completed scan with no results). This allows the user to more easily enter the pin values in subsequent commands.

* General: Display a message if no target device(s) found during a scan.

* General: Added backspace support to user input (thanks to piggybanks).

* General: Minor code cleanup and text updates.


1.2.2
-----
Release date: **September 20, 2014**

* Modified `Set_Target_IO_Voltage` to print a confirmation of the newly set voltage (thanks to Crypt) and to print a warning that the user should NOT connect VADJ to the target (VADJ is used for level-shifting JTAGulator's I/O to match the target's I/O, NOT to externally power the target).


1.2.1
-----
Release date: **September 8, 2014**

* Added prompt to enable/disable local echo during UART passthrough (thanks to dummys). Local echo is turned off by default, since the target device normally controls whether or not to echo characters.

* Minor code cleanup.


1.2
---
Release date: **August 7, 2014**

* Added support for detecting the optional JTAG nTRST pin. This pin is often pulled low on target systems, which will intentionally disable the JTAG interface. If it isn't one of the pins connected to the JTAGulator, the interface might not be discovered.

* Fixed/modified JTAG routines to more closely conform to the IEEE 1149.1 specification (thanks to Bryan Angelo @ Qualcomm).

* Added extended IDCODE decoding based on IEEE 1149.1 specification for easier/quicker identification of manufacturer, part number, and version (thanks to Bob Heinemann).

* Modified `UART_Scan` to display previously entered string, if any, as default and to accept hex values (when `\x` is used as the string prefix, ignore MSBs if they are NULL). 

* Changed command input to require that commands are terminated with a single CR or LF, instead of executing immediately after the character was entered.

* Added local echo into `Parallax Serial Terminal.spin` (thanks to HexView). This will make using JTAGulator easier across different terminal programs, many of which don't provide local echo by default.

* Added progress indicators (display a character on the screen and blink LED) to show that JTAGulation is active/working (`Display_Progress`).

* Added command to display firmware version information (`J`).

* Added JTAGulator logo and welcome message to start-up text.

* Minor code cleanup, optimizations, fixes to UI/input sanitization.

* Release for [Black Hat USA 2014 Tools Arsenal](https://www.blackhat.com/us-14/arsenal.html).


1.1.1
-----
Release date: **August 6, 2013**

* Modifed `UART_Scan` and `UART_Passthrough` to stop the UART cog (`jdcogserial`) at the end of their functions. This prevents the cog from maintaining control of the pins, which would prevent subsequent, non-UART commands from working.


1.1
---
Release date: **August 1, 2013**

* Added support for UART discovery and passthrough mode (8N1).

* Adjusted `Set_JTAG` to only ask for the three required pins (TDO, TCK, TMS) when getting JTAG Device ID.

* Modified `Set_Target_Voltage` to allow you to turn off the target voltage output (VADJ).

* Re-organized code by subsystem (e.g., UART, JTAG, General).

* Release for [Black Hat USA 2013](https://www.blackhat.com/us-13/).


1.0.1
-----
Release date: **June 11, 2013**

* Added linefeeds to text output (for terminal programs that require CR+LF instead of just CR to display properly).

* Minor code cleanup.


1.0
---
Release date: **April 24, 2013**

* Initial release for [DESIGN West 2013](http://www.ubmdesign.com/sanjose/).
