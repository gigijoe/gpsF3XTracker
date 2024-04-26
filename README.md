# Status Version V0.2
Currently only supported for Taranis X9d+ and opentx-2.3!
It looks as if edgeTX is also working but I did not yet change to edgeTX. (But I will do it soon)
based on ideas of Frank Schreibers [F3F Tool](https://github.com/frank-sc/F3F-Tool-V1)
This version is modularized as much as possible. 
- Center is a course library which raises IN/OUT events on two bases. (Three bases may be possible in a future version)
- These events are consumed by a competition module which starts the appropriate actions depending on the actual competition status.
- The GPS sensor is encapsulated in a separate module to enable the same interface for different sensors.
- The setup is a pain on the Taranis. A simple blocked screen has been developed to take care of that.
- The main loop is collecting data from the sensors and updating the cours and competition. (since there are no real events in a single threaded environment) 

## Usage 
- use `S1` to change the course bearing
- use `S2` to change the competition type
- use `rud`left/right to change the base A location (F3F only)
- use scrollbar plus/minus buttons to choose a predefined location.
- user `ENTER` to activate the changes from the setup screen.
- 
## What is working: NOTHING IS TESTED IN REAL LIVE UNTIL NOW!
### Sensors:
 - Logger3 from SM-Modellbau.
 - GPSV2 from FrSky. (Poor performance)

### Competition Types:
- F3F competition/training
- F3B Distance
- F3B Speed

## Installation
Install the complete *.luac tree from the bin folder to your `/SCRIPTS/TELEMETRY` folder on your SD-Card.
Compiling on the transmitter is not possible and you will get an `out of memory`error.
- you need to install the setup.lua in one telemetry screen and the main.lua in the direct following one. (otherwise it may lead to script errors -- may!)
