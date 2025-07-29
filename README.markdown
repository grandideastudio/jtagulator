JTAGulator
==========

An open source hardware hacking tool that assists in identifying on-chip debug (OCD) interfaces from test points, vias, component pads, or connectors of an electronic device.


Usage
-----

Main project page: [https://jtagulator.com](https://jtagulator.com)

Documentation: [https://github.com/grandideastudio/jtagulator/wiki](https://github.com/grandideastudio/jtagulator/wiki)

Videos: [YouTube playlist](https://www.youtube.com/playlist?list=PLsyTdiI7kVn8H848lMSKljkUwPnZfke9k)


Firmware
--------

The JTAGulator firmware is built with the [Parallax Propeller Tool version 1.3.2](https://expliot.io/wp-content/uploads/P8X32A-Setup-Propeller-Tool-v1.3.2.zip) for Windows. If you wish to compile code or contribute to the project, we recommend using this software. Alternative [development environments](https://www.parallax.com/download/propeller-1-software/) are untested and unsupported.

Official releases: [https://github.com/grandideastudio/jtagulator/tags](https://github.com/grandideastudio/jtagulator/tags)

Demonstration of the firmware update process: [https://www.youtube.com/watch?v=xlXwy-weG1M](https://www.youtube.com/watch?v=xlXwy-weG1M)

Firmware compilation using [OpenSpin](https://github.com/parallaxinc/OpenSpin): `openspin -o JTAGulator.eeprom -e -v JTAGulator.spin`

Firmware testing using [PropLoader](https://github.com/parallaxinc/PropLoader) (write to RAM): `proploader -p /dev/SERIALPORT -v JTAGulator.eeprom`

Firmware updating (write to EEPROM): `proploader -p /dev/SERIALPORT -v -e JTAGulator.eeprom`

*Note: This is a development repository. Interim commits may be unstable.*


Author
------
Created by [Joe Grand](https://joegrand.com) of [Grand Idea Studio](https://grandideastudio.com). 

As of July 2025, this project is maintained and supported by [EXPLIoT](https://expliot.io/jtagulator/).

Contributions by [@samyk](https://github.com/samyk), [@kbembedded](https://github.com/kbembedded), [@BenGardiner](https://github.com/BenGardiner), Bryan Angelo, [@adamgreen](https://github.com/adamgreen), [@0ff](https://github.com/0ff), [@stephengroat](https://github.com/stephengroat), [@alexmaloteaux](https://github.com/alexmaloteaux), HexView, [@piggybanks](https://github.com/piggybanks), Crypt, [@dummys](https://github.com/dummys), and Bob Heinemann.


License
-------
The JTAGulator design is distributed under a [Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/) license. This means that you can share and adapt the work, but you must attribute the work to the original author and distribute any contributions under this same license. 

The JTAGulator name and logo are registered trademarks of [Grand Idea Studio]((https://grandideastudio.com)). The marks may not be used on derived works without permission. 
