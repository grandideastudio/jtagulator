JTAGulator To Do
================

This is a list of features and/or additions we'd like to eventually build into the JTAGulator. It is by no means exhaustive and we are happy to take suggestions and/or pull requests!


Bug Fixes
---------

* Inconsistent IDCODE Scan and/or BYPASS Scan results on certain targets. This is caused by the front end circuitry (input protection, level translators) affecting the target's signals. [Issue #3](https://github.com/grandideastudio/jtagulator/issues/3) (in progress)


Hardware
--------

* Level-shifting module: Plug-in module (to connect to 2x5 headers) for arbitrary target voltage level shifting above the native JTAGulator range (1.4V to 3.3V). Particularly useful for industrial/SCADA equipment running at 5V or greater.


Documentation
-------------

* Update JTAGulator [documentation](https://github.com/grandideastudio/jtagulator/wiki) (in progress)

* New feature review video
