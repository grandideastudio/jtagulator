1.1.1:
------
Release date: **August 6, 2013**

* Modifed `UART_Scan` and `UART_Passthrough` to stop the UART cog (`jdcogserial`) at the end of the functions. This prevents the cog from maintaining control of the pins, which would prevent subsequent, non-UART commands from working. 


1.1:
----
Release date: **August 1, 2013**

* Added support for UART discovery and pass through mode (8N1).

* Adjusted `Set_JTAG` to only ask for the three required pins (TDO, TCK, TMS) when getting JTAG Device ID.

* Modified `Set_Target_Voltage` to allow you to turn off the target voltage output (VADJ).

* Re-organized code by subsystem (e.g., UART, JTAG, General).

* Release for [Black Hat USA][2].


1.0.1:
------
Release date: **June 11, 2013**

* Added linefeeds to text output (for terminal programs that require CR+LF instead of just CR to display properly).

* Minor code cleanup.


1.0:
----
Release date: **April 24, 2013**

* Initial release for [DESIGN West][1].

[1]: http://www.ubmdesign.com/sanjose/
[2]: http://www.blackhat.com/us-13/
