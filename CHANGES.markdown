JTAGulator Change Log
=====================

Visit the JTAGulator [GitHub repository](https://github.com/grandideastudio/jtagulator/commits/master) for full commit comments.


<a id="v1_12"></a>ID Tracker
----

Release date: **July 5, 2025**

* General: Added the ability to use jtag idcode to identify the manufacturer



<a id="v1_12"></a>1.12
----
Release date: **June 5, 2023**

* General: Added All (`A`) to run all available scan methods (GPIO, JTAG, SWD, UART) (thanks to samyk).

* General: When the JTAGulator is waiting for the user to begin a scan, ignore the Enter key so the scan isn't inadvertently aborted (thanks to samyk).

* General: For invalid commands, inform the user that `H` shows available commands (thanks to samyk).

* General: Minor text string updates.


<a id="v1_11_1"></a>1.11.1
----
Release date: **April 6, 2023**

* General: Minor text string updates.


<a id="v1_11"></a>1.11
----
Release date: **April 14, 2021**

* JTAG: Added Pin Mapper (EXTEST Scan) (`P`) to associate physical pins of a target chip with their positions in the JTAG Boundary Scan Register. The command uses JTAG's EXTEST instruction to shift known data onto the pins and looks for the result on any of JTAGulator's available channels. This can be useful for chip- or board-level reverse engineering or to provide information needed to access an external device connected to the target chip. Requires a known JTAG pinout and assumes a single device/TAP in the chain.

* JTAG: Revised `Get_Device_IDs` to prevent reading multiple Device IDs from certain targets when only one actual Device ID exists.

* UART: Added option into `UART_Scan` to bring channels low before each permutation. The length of the low pulse and the delay before continuing after the signal returns high are both adjustable.

* General: Optimized behavior of bringing channels low before each permutation (originally implemented in FW [1.6](#v1_6)).

* General: Minor code modifications and cleanup.


<a id="v1_10"></a>1.10
----
Release date: **December 8, 2020**

* UART: Upgraded `UART_Scan_TXD` to continuously monitor for target signals and automatically calculate their baud rates instead of iterating through a fixed set. This significantly decreases scan time, increases the detectable baud rate to > 1.5M, and can identify targets that implement non-standard or fluctuating baud rates, either intentionally or through unintentional timing errors (thanks to kbembedded and BenGardiner).

* UART: Added support during `UART_Scan` to accept known pins, if any. This can reduce search time, especially if `UART_Scan_TXD` was done first to identify TXD.

* UART: Added support during `UART_Scan` for a user-configurable delay between sending the text string and checking for a response from the target.

* UART: Fixed bug that prevented `UART_Scan` from proceeding if a target was continually transmitting data. This fix may result in more responses for a given pin permutation.

* JTAG: Added RTCK Scan (`R`) for [adaptive clocking](https://developer.arm.com/documentation/dui0517/h/rvi-debug-unit-system-design-guidelines/using-adaptive-clocking-to-synchronize-the-jtag-port?lang=en) discovery. RTCK (return test clock) is implemented by synthesizable CPU cores that need to synchronize an external JTAG hardware adapter's test clock (TCK) with their own internal core clock (thanks to Bryan Angelo).

* JTAG: Fixed JTAG Scan (`J`) to check for nTRST even if TDI is connected to channel 0.

* JTAG: Fixed OpenOCD mode (`O`) to ensure the JTAGulator's LED turns back to RED when the OpenOCD software is closed.
 
* General: Minor code modifications and cleanup.

* Release for [Black Hat Europe 2020 Tools Arsenal](https://www.blackhat.com/eu-20/arsenal/schedule/index.html).


<a id="v1_9"></a>1.9
---
Release date: **October 21, 2020**

* JTAG: Added support (`O`) to interface directly with [OpenOCD](http://openocd.org/), a cross-platform, open source software tool that provides on-chip debugging, in-system programming, and boundary-scan testing for embedded target devices. The JTAGulator emulates the binary protocol used by the [Bus Pirate](http://dangerousprototypes.com/docs/Bus_Pirate#JTAG). This mode persists through JTAGulator resets, power cycles, and firmware updates. It can only be exited manually by the user. See operational details on the [Wiki](https://github.com/grandideastudio/jtagulator/wiki/OpenOCD) (thanks to BenGardiner).

* JTAG: Fixed low-level JTAG routines (`PropJTAG`) to sample TDO after TCK rising edge (not before) to properly conform to the IEEE 1149.1 specification.

* JTAG: Removed adjustable clock speed functionality (`C`). JTAG clock operates at 25kHz maximum.

* SWD: Removed adjustable clock speed functionality (`C`). SWD clock defaults to 100kHz. Can be manually adjusted in `SWD_Init` from 1 to 300kHz.

* General: Minor code cleanup and optimizations.


<a id="v1_8"></a>1.8
---
Release date: **October 6, 2020**

* JTAG: Added JTAG Scan (`J`), which combines IDCODE Scan and BYPASS Scan functionality into a single command. If a valid IDCODE is received during enumeration, the remaining channels will be checked for TDI. This can greatly reduce search time and will return all required JTAG pins for the detected target.

* GPIO: Added logic analyzer support (`L`) for use with [sigrok](https://sigrok.org), a cross-platform, open source signal analysis software suite. The JTAGulator emulates an Open Logic Sniffer (OLS) [SUMP-compatible](http://dangerousprototypes.com/docs/The_Logic_Sniffer%27s_extended_SUMP_protocol) device and provides a 1024 x 24-channel sample buffer, 1.2MHz maximum sampling rate, and logic level triggering. This mode persists through JTAGulator resets, power cycles, and firmware updates. It can only be exited manually by the user. See operational details on the [Wiki](https://github.com/grandideastudio/jtagulator/wiki/Logic-Analyzer) (thanks to BenGardiner).

* General: Minor code cleanup and optimizations.


<a id="v1_7"></a>1.7
---
Release date: **June 17, 2020**

* SWD: Added support for detecting [ARM Serial Wire Debug (SWD)](https://developer.arm.com/architectures/cpu-architecture/debug-visibility-and-trace/coresight-architecture/serial-wire-debug) interfaces. The JTAGulator's front-end circuitry is incompatible with many SWD-based targets. Detection results may be affected. See discussion in [Pull Request #30](https://github.com/grandideastudio/jtagulator/pull/30) (thanks to adamgreen). 

* UART: Increased user string input size for `UART_Scan` to 16 bytes for both ASCII and hexadecimal input. [Issue #34](https://github.com/grandideastudio/jtagulator/issues/34)

* UART: If previously entered user string was in hexadecimal, it will now be displayed properly during `UART_Scan`.

* JTAG: Removed `X` command, which could transfer an instruction and data to/from a target. While useful for testing and preliminary fuzzing, it was unreliable and limited in capability compared to software tools like UrJTAG.

* JTAG: Reduced maximum allowable clock speed to 20 kHz. 

* General: Increased minimum allowable target voltage (VADJ) to 1.4V per TXS0108E data sheet table 6.3 (updated from 1.2V in Revision G, April 2020). 

* General: All .spin source files converted from UTF-16 to 7-bit ASCII for ease-of-use and compatibility with external/third-party tools (thanks to adamgreen). 

* General: Minor code optimizations.


<a id="v1_6"></a>1.6
---
Release date: **August 9, 2018**

* JTAG: Overhauled low-level JTAG routines (`PropJTAG`) to provide better readability and compliance with the IEEE 1149.1 specification (thanks to anonymous piece of paper).  

* JTAG: Modified `IDCODE_Scan` to display any Device IDs detected for the current pin configuration (thanks to 0ff). After the scan completes, extended decoding of the Device ID(s) can be achieved with the `Get Device ID` (`D`) command.

* JTAG: Added option to bring channels low between permutations during `IDCODE_Scan` and `BYPASS_Scan`. The length of the low pulse and the delay before continuing after the signal returns high are both adjustable. This may help with detection on certain targets that need their state/system reset. 
  
* JTAG: Added command to set the JTAG clock speed (`C`). Adjustable from 1 to 22 kHz with the default set to maximum (thanks to BenGardiner).

* General: Minor code cleanup and optimizations.

* Release for [Black Hat USA 2018 Tools Arsenal](https://www.blackhat.com/us-18/arsenal.html).


<a id="v1_5"></a>1.5
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


<a id="v1_4"></a>1.4
---
Release date: **November 3, 2016**

* JTAG: Added command to transfer an instruction and data to/from a target (`X`). This is useful for testing and preliminary fuzzing. Requires a known JTAG pinout and assumes a single device/TAP in the chain.

* JTAG: Added Instruction/Data Register (IR/DR) discovery command (`Y`). Inspired by UrJTAG's `discovery` command, this is useful for identifying available (and possibly undocumented) instructions of a target. Requires a known JTAG pinout and assumes a single device/TAP in the chain.

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


<a id="v1_3"></a>1.3
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


<a id="v1_2_2"></a>1.2.2
-----
Release date: **September 20, 2014**

* Modified `Set_Target_IO_Voltage` to print a confirmation of the newly set voltage (thanks to Crypt) and to print a warning that the user should NOT connect VADJ to the target (VADJ is used for level-shifting JTAGulator's I/O to match the target's I/O, NOT to externally power the target).


<a id="v1_2_1"></a>1.2.1
-----
Release date: **September 8, 2014**

* Added prompt to enable/disable local echo during UART passthrough (thanks to dummys). Local echo is turned off by default, since the target device normally controls whether or not to echo characters.

* Minor code cleanup.


<a id="v1_2"></a>1.2
---
Release date: **August 7, 2014**

* Added support for detecting the optional JTAG nTRST pin. This pin is often pulled low on target systems, which will intentionally disable the JTAG interface. If it isn't one of the pins connected to the JTAGulator, the interface might not be discovered.

* Fixed/modified JTAG routines to more closely conform to the IEEE 1149.1 specification (thanks to Bryan Angelo).

* Added extended IDCODE decoding based on IEEE 1149.1 specification for easier/quicker identification of manufacturer, part number, and version (thanks to Bob Heinemann).

* Modified `UART_Scan` to display previously entered string, if any, as default and to accept hex values (when `\x` is used as the string prefix, ignore MSBs if they are NULL). 

* Changed command input to require that commands are terminated with a single CR or LF, instead of executing immediately after the character was entered.

* Added local echo into `Parallax Serial Terminal.spin` (thanks to HexView). This will make using JTAGulator easier across different terminal programs, many of which don't provide local echo by default.

* Added progress indicators (display a character on the screen and blink LED) to show that JTAGulation is active/working (`Display_Progress`).

* Added command to display firmware version information (`J`).

* Added JTAGulator logo and welcome message to start-up text.

* Minor code cleanup, optimizations, fixes to UI/input sanitization.

* Release for [Black Hat USA 2014 Tools Arsenal](https://www.blackhat.com/us-14/arsenal.html).


<a id="v1_1_1"></a>1.1.1
-----
Release date: **August 6, 2013**

* Modifed `UART_Scan` and `UART_Passthrough` to stop the UART cog (`jdcogserial`) at the end of their functions. This prevents the cog from maintaining control of the pins, which would prevent subsequent, non-UART commands from working.


<a id="v1_1"></a>1.1
---
Release date: **August 1, 2013**

* Added support for UART discovery and passthrough mode (8N1).

* Adjusted `Set_JTAG` to only ask for the three required pins (TDO, TCK, TMS) when getting JTAG Device ID.

* Modified `Set_Target_Voltage` to allow you to turn off the target voltage output (VADJ).

* Re-organized code by subsystem (e.g., UART, JTAG, General).

* Release for [Black Hat USA 2013](https://www.blackhat.com/us-13/).


<a id="v1_0_1"></a>1.0.1
-----
Release date: **June 11, 2013**

* Added linefeeds to text output (for terminal programs that require CR+LF instead of just CR to display properly).

* Minor code cleanup.


<a id="v1_0"></a>1.0
---
Release date: **April 24, 2013**

* Initial release for [DESIGN West 2013](http://www.ubmdesign.com/sanjose/).
