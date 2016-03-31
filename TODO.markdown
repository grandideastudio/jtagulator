JTAGulator To Do
================

This is a rough list of features and/or additions we'd like to eventually build into the JTAGulator. If you're interested in contributing to the project, please do so!


General
-------

* Compatibility w/ [OpenOCD][0]: This would enable the JTAGulator to directly manipulate target devices once the interface is found (instead of having to disconnect the JTAGulator and connect other JTAG hardware to do the job like we have to do now). 

Protocols/Discovery
-------------------

* JTAG: Accept known pins (if discovered by IDCODE Scan) for use during BYPASS Scan in order to reduce search time

* JTAG: Instruction Register (IR) length detection

* JTAG: RTCK pin detection (adaptive clocking)

* ARM Serial Wire Debug

* TI Spy-Bi-Wire/MSP430

* Atmel AVR ISP

* Freescale BDM

* Microchip ICSP

* LPC (Low Pin Count) Bus

* Ethernet PHY

* Flash memory: NAND (eMMC), Parallel NOR (CFI), Serial NOR (SPI), compatibility w/ [flashrom][2] 


Hardware
--------

* Level-shifting module: Plug-in module (to connect to 2x5 headers) for arbitrary target voltage level shifting above the native JTAGulator range (1.2V to 3.3V). Particularly useful for industrial/SCADA equipment running at 5V or greater.


[0]: http://openocd.sourceforge.net
[1]: http://sigrok.org
[2]: http://flashrom.org
