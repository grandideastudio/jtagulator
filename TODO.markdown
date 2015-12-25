JTAGulator To Do
================

This is a rough list of features and/or additions we'd like to eventually build into the JTAGulator. If you're interested in contributing to the project, please do so!


Bug Fixes
---------

* Inconsistent IDCODE Scan and/or BYPASS Scan results on certain targets. Confirmed on HTC One X, Pogoplug, BeagleBone Black, and Arcadyan VGV7519. May be multiple issues or all due to a single root cause. See [Issue #3][0]  


General
-------

* Logic analyzer: Compatibility w/ [sigrok][3]

* Compatibility w/ [OpenOCD][1] and [UrJTAG][2]: This would enable the JTAGulator to directly manipulate target devices once the interface is found (instead of having to disconnect the JTAGulator and connect other JTAG hardware to do the job like we have to do now). 


Protocols/Discovery
-------------------

* JTAG: Add Send Instruction/Opcode command (for known pinout)

* JTAG: Instruction Register (IR) length detection

* JTAG: EJTAG support

* JTAG: RTCK pin detection (adaptive clocking)

* UART: Automatic baud rate detection for UART Scan (measure minimum pulse width of received signal)

* UART: Support inverted TX/RX (idle high or idle low) during UART Scan/Pass Through

* ARM Serial Wire Debug

* TI Spy-Bi-Wire/MSP430

* Atmel AVR ISP

* Freescale BDM

* Microchip ICSP

* LPC (Low Pin Count) Bus

* Ethernet PHY

* Flash Memory: External discovery via JTAG Boundary Scan

* Flash Memory: NAND (eMMC), Parallel NOR (CFI), Serial NOR (SPI), compatibility w/ [flashrom][4] 


Hardware
--------

* Acrylic case ala [Sick of Beige][5]

* Level-shifting module: Plug-in module (to connect to 2x5 headers) for arbitrary target voltage level shifting above the native JTAGulator range (1.2V to 3.3V). Particularly useful for industrial/SCADA equipment running at 5V or greater.


Documentation
-------------

* FAQ/Troubleshooting Guide


[0]: https://github.com/grandideastudio/jtagulator/issues/3
[1]: http://openocd.sourceforge.net
[2]: http://urjtag.org
[3]: http://sigrok.org
[4]: http://flashrom.org
[5]: http://dangerousprototypes.com/docs/Sick_of_Beige_compatible_cases
