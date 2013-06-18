1.1:
----
Release date: **Not yet**

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