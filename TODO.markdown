JTAGulator To Do
================

This is a rough list of features and/or additions we'd like to eventually build into the JTAGulator. If you're interested in contributing to the project, please do so!


Bug Fixes
---------

* Inconsistent IDCODE Scan and/or BYPASS Scan results on certain targets. Confirmed on HTC One X, Pogoplug, BeagleBone Black, and Arcadyan VGV7519. May be multiple issues or all due to a single root cause. [Issue #3](https://github.com/grandideastudio/jtagulator/issues/3) (in progress)


General
-------

* Logic analyzer: Compatibility w/ [sigrok](http://sigrok.org) (in progress)

* Compatibility w/ [OpenOCD](http://openocd.org) and [UrJTAG](http://urjtag.org): This would enable the JTAGulator to directly manipulate target devices once the interface is found (instead of having to disconnect the JTAGulator and connect other JTAG hardware to do the job like we have to do now). 


Protocols/Discovery
-------------------

* JTAG: EJTAG support

* JTAG: RTCK pin detection (adaptive clocking)

* JTAG: ARM Serial Wire Debug (in progress) [Pull Request #30](https://github.com/grandideastudio/jtagulator/pull/30)

* JTAG: Compact JTAG aka cJTAG (IEEE 1149.7) [Issue #13](https://github.com/grandideastudio/jtagulator/issues/13)

* UART: Automatic baud rate detection for UART Scan

* TI Spy-Bi-Wire/MSP430

* Atmel AVR ISP

* Freescale BDM

* Microchip ICSP

* LPC (Low Pin Count) Bus

* Ethernet PHY

* Flash Memory: External discovery via JTAG Boundary Scan

* Flash Memory: NAND (eMMC), Parallel NOR (CFI), Serial NOR (SPI), compatibility w/ [flashrom](http://flashrom.org) 


Hardware
--------

* Level-shifting module: Plug-in module (to connect to 2x5 headers) for arbitrary target voltage level shifting above the native JTAGulator range (1.2V to 3.3V). Particularly useful for industrial/SCADA equipment running at 5V or greater.


Documentation
-------------

* FAQ/Troubleshooting Guide
