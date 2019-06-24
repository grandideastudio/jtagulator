JTAGulator
==========

A tool to assist in identifying on-chip debugging (OCD) and/or 
programming connections from test points, vias, or component pads on a target
piece of hardware.

Refer to the project page for complete details:

[http://www.jtagulator.com][1]


Firmware Update
==========
Download and install PropellerIDE:
https://developer.parallax.com/propelleride/


Clone this repo:
```
git clone https://github.com/grandideastudio/jtagulator
```

Run PropellerIDE (with sudo/root, as it needs access to the device:
```
sudo propelleride
```
In PropellerIDE, File->Open->JTAGulator.spin from your local version of this repo.


Project->Build


Project->Write


If you get errors:
```
Mon Jun 24 13:15:34 2019 [ERROR] Failed to open device: "ttyUSB0" 
Mon Jun 24 13:15:34 2019 [ERROR] Failed to open device: "ttyUSB0" 
Mon Jun 24 13:15:34 2019 [DEBUG] [ttyUSB0] ERROR: Device not open 
```
Make sure you are running PropellerIDE with sudo and/or that the JTAGulator is connected.


Direct link to video demonstrating an alternate (old)firmware update process:

[http://www.youtube.com/watch?v=xlXwy-weG1M][2]

Author
-------
Created by Joe Grand of [Grand Idea Studio][3]. 


License
-------
The JTAGulator design is distributed under a [Creative Commons Attribution 3.0 
United States][4] license. This means that you can share and adapt the work, but 
you must attribute the work to the original author. 

The JTAGulator name and logo are registered trademarks of [Grand Idea Studio][3]. 
No permission is granted to use the marks without our express consent. 


[1]: http://www.jtagulator.com
[2]: http://www.youtube.com/watch?v=xlXwy-weG1M
[3]: http://www.grandideastudio.com
[4]: http://creativecommons.org/licenses/by/3.0/us/
