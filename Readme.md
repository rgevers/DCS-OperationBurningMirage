Naming Conventions
All unit names should be prefixes of their groups. E.g. if a group is called "red-Tabuk-5" the units should be "red-Tabuk-5-1", "red-Tabuk-5-2", etc. This is because of a current issue with DCS and access to a unit's group name via Lua. This is also standard naming convention and good mission hygiene so as long as this is followed the correct associations can be made using unit names.

The following prefixes are needed to identify groups for their various roles. Anything after the prefix can be included for mission-creator's own purposes. At a minimum a group number should follow the final "-".
 - hvt-[Coalition](#Coalition)-[TheaterName](#TheaterName)-
	 - Designates high value targets associated with a given theater. Destroying these counts against the theater's health.
 - sam-[Coalition](#Coalition)-[TheaterName](#TheaterName)-
	 - Designates airdefenses to be associated with a given theater. Destroying these counts against the theater's health. If named correctly they will also be added to skynet. 
	 - The health of the theater will also limit whether or not these are activated when the mission starts.
 - ewr-[Coalition](#Coalition)-[TheaterName](#TheaterName)-
	 - Designates airdefenses to be associated with a given theater. Destroying these counts against the theater's health. If named correctly they will also be added to skynet.
	 - The health of the theater will also limit whether or not these are activated when the mission starts.
 - [TheaterName](#TheaterName)-convoy
	- Used to mark where helicopter and truck convoys should takeoff/land embark/disembark.
 - [TheaterName](#TheaterName)-shipConvoy

Naming Convention Variables
##### Coalition
Lowercase value either "red" or "blue". 

##### TheaterName
Theater names (referred to as zone names within some of the code) are the names used to designate points of control on the map. The name can include spaces or capital letters. Code comparisons are case insensitive so don't try to differentiate two identical theaters with capitalization alone. If spaces are included make sure to include them correctly in all references. Theater names need to be globally unique across all maps so if you use things like "alpha" don't plan to have an "alpha" on both Sinai and Syria, for example.

While spaces are fine in theater names, avoid "-". I just omit them.

##### Zone Names

#### Testing
Testing can be achieved locally by simply running the mission. Note, if you don't launch a multiplayer server and just hit the "fly" button, you will need to slot as a spectator to let the mission initialization happen or else some testing will not work. For example the slot-blocking script cannot function until after the state is loaded into memory and this happens in the first seconds of the mission start. This happens on a multiplayer server before the first player can slot in but there's a race condition when testing from the mission editor, so going spectator first is a more realistic way of testing.


### Steps on a new map

Make sure to not be running the mission while editin the config file. It will get periodically overwritten. Even if the mission is paused it may have a stale version of the config in memory that it will overwrite your changes with.

 - Create zones in all of the appropriate areas of the map. Add them to the theater list in the config file using
```
"": {
	"Coalition": "red",
	"Health": 3000,
	"MaxHealth": 3000
},
```
		- Set manufacturing source if needed.
		- Set airport if needed. Example:
```
"Kibrit": {
	"Airport": "Kibrit Air Base",
	"Coalition": "red",
	"Health": 3000,
	"ManufacturingSource": true,
	"MaxHealth": 3000
},
```
 - Adjust health as desired.
 - Run mission and check spectator view to assess.
 - Add connections to config file using
```
{
	"SourceTheater": "",
	"Health": 3000,
	"MaxHealth": 3000,
	"Reverse": false,
	"DestinationTheater": "",
	"Type": "HELO",
	"Waypoints": []
  },
```
	     - Explain reversal
 - Add player cold starts
 - Setup FARPs
 - Add tankers
 - Add air defenses
 - Add high value targets
 - Check scenery objects that should count as industry against the TargetValues file. See video for help.

 assert(loadfile("C:\\Users\\robg\\Documents\\GitHub\\JTF111DynamicServerClient\\JTF111DynamicServerClient\\JTF111DynamicServerClient\\Lua\\OperationBurningMirage.lua"))()

 assert(loadfile("C:\\Users\\robg\\Documents\\GitHub\\dcs_scripting\\whackamole.lua"))()