--#region Global Variables
TargetValuesJson = {}
KillSummary = {}
MapZonesByTheaterName = {}
CurrentState = {}
AttackSchedule = {}
AttackTime = {}
GroundAttackSchedule = {}
GroundAttackTime = {}
Connections = {}
ZonesAlphabetized = {}
BlueZonesAlphabetized = {}

MANUFACTURE_AMOUNT = 200
RESUPPLY_AMOUNT = 100
ATTRITION_AMOUNT = 50
--#endregion

--#region Drawing Functions
local function DrawTheaterHealth(theater, theaterLoc, health, theaterName)
  theaterLoc:TextToAll(theaterName .. ": " .. math.floor((health / theater.MaxHealth * 100) + .5) .. "%", -1, { 1, 1, 1 },
    1, { 0, 0, 0 },
    .3, 14)
end

local function DrawTheater(theater, health, coalition, coord, radius, theaterName)
  local color
  local colorFactory

  if coalition == "red" then
    color = { 1, 0, 0 }
    colorFactory = { 1, 1, 0 }
  else
    color = { 0, 0, 1 }
    colorFactory = { 0, 1, 1 }
  end

  if theater.ManufacturingSource then
    coord:CircleToAll(radius, -1, colorFactory, 1, colorFactory, .25, 0)
  end
  coord:CircleToAll(radius, -1, color, 1, color, .25, 0)
  DrawTheaterHealth(theater, coord:Translate(radius * .75, 150), health, theaterName)
end

local function DrawConnection(sourceMCoord, destMCoord, coalition, midCoord)
  local color

  if coalition == "red" then
    color = { 1, 0, 0 }
  elseif coalition == "blue" then
    color = { 0, 0, 1 }
  else
    color = { 0, 0, 0 } --TODO Change the type of this arrow as well.
  end
  if (midCoord) then
    sourceMCoord:ArrowToAll(midCoord, -1, color, 1, color, .5, 0)
    midCoord:ArrowToAll(destMCoord, -1, color, 1, color, .5, 0)
  else
    sourceMCoord:ArrowToAll(destMCoord, -1, color, 1, color, .5, 0)
  end
end

local function DrawConnectionHelper(sourceTheater, destinationTheater, coalition, connectionName, connectionType)
  local sourceZone = ZONE:New(sourceTheater)
  local destinationZone = ZONE:New(destinationTheater)
  if (sourceZone ~= nil and destinationZone ~= nil) then
    -- Load Zone for Theater and add to Zone list.
    -- Get zone coords
    local theaterCoord = sourceZone:GetVec2()
    local sourceCoord = COORDINATE:NewFromVec2(theaterCoord)
    theaterCoord = destinationZone:GetVec2()
    local destCoord = COORDINATE:NewFromVec2(theaterCoord)
    local midCoord = nil

    if (connectionType == "SHIP") then
      local midpointZone = ZONE:New(sourceTheater .. "-shipConvoy-turn")
      local midpoint = midpointZone:GetVec2()
      midCoord = COORDINATE:NewFromVec2(midpoint)
    end

    env.info("Drawing connection: " .. connectionName)
    DrawConnection(sourceCoord, destCoord, coalition, midCoord) --TODO Fault in health if nil
  end
end
--#endregion

--#region File Management
local debugMode = 0

local releaseFlag = trigger.misc.getUserFlag("1")
local releaseVersion = releaseFlag -- 0 by default. 1 for release version (_rc file)

local JSON = (loadfile('Scripts/JSON.lua'))()
BASE:TraceAll(true)
env.info("Initializing Burning Mirage")
--RED A2A Disaptcher

-- Specify the path to your JSON file
if (releaseVersion == 1) then
  StateFilePath = lfs.writedir() .. "Missions/Saves/BurningMirage_State.json"
else
  StateFilePath = "C:/Users/robg/Documents/GitHub/DCS-OperationBurningMirage/BurningMirage_State.json"
end
env.info("State Path: " .. StateFilePath)

if (releaseVersion == 1) then
  TargetValuesFilePath = lfs.writedir() .. "Missions/Saves/BurningMirage_TargetValues.json"
else
  TargetValuesFilePath = "C:/Users/robg/Documents/GitHub/DCS-OperationBurningMirage/BurningMirage_TargetValues.json"
end
env.info("State Path: " .. TargetValuesFilePath)
--#endregion

--#region Utility Functions
local function read_file(file_path)
  local file = io.open(file_path, "r")
  if file then
    local content = file:read("*a")
    file:close()
    return content
  else
    return nil
  end
end

local function write_file(file_path, contents)
  local file = io.open(file_path, "w")
  file:write(contents)
  file:close()
end

local function shuffle(arr)
  for i = 1, #arr - 1 do
    local j = math.random(i, #arr)
    arr[i], arr[j] = arr[j], arr[i]
  end
end

local function Lround(x)
  return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

-- Helper because I can never remember how to prefix compare strings in Lua.
local function starts_with(str, start)
  return str:sub(1, #start) == start
end

local function ends_with(str, suffix)
  return str:sub(- #suffix) == suffix
end

local function contains(str, substr)
  return string.find(str, substr, 1, true) ~= nil
end

local function removeSuffix(str, suffix)
  return str:gsub(suffix .. "$", "")
end

local function tableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

local function parseZoneFromUnitName(str)
  local i = string.find(str, "-", 0)
  local firstPart = str:sub(1, i - 1)
  return firstPart
end

-- Function to sort a table by its values and return a list of key-value pairs
local function sortTableByValue(t)
  local sortedKeys = {}

  -- Insert all keys into a list
  for key in pairs(t) do
    table.insert(sortedKeys, key)
  end

  -- Sort the list of keys based on the corresponding values in the table
  table.sort(sortedKeys, function(a, b) return t[a] < t[b] end)

  -- Create a new list of sorted key-value pairs
  local sortedList = {}
  for _, key in ipairs(sortedKeys) do
    table.insert(sortedList, { key = key, value = t[key] })
  end

  return sortedList
end

-- Function to alphabetize and break into arrays of 10 items
local function alphabetizePaged(tableToSort)
  local t = {}
  for n, _ in pairs(tableToSort) do table.insert(t, n) end

  -- Alphabetize the table names
  table.sort(t)

  -- Initialize the new table to hold the chunks
  local result = {}
  local chunk = {}

  -- Iterate through the alphabetized list
  for _, name in ipairs(t) do
    -- Insert the name into the current chunk
    table.insert(chunk, name)
    -- env.info("Inserted " .. name)
    -- If the chunk has 10 items, insert it into the result and start a new chunk
    if #chunk == 10 then
      table.insert(result, chunk)
      chunk = {}
    end
  end

  -- Insert the last chunk if it has any remaining items
  if #chunk > 0 then
    table.insert(result, chunk)
  end

  return result
end

-- Function to return the first and last item from an array
local function firstAndLast(arr)
  if #arr == 0 then
    return nil, nil
  elseif #arr == 1 then
    return arr[1], arr[1]
  else
    return arr[1], arr[#arr]
  end
end

local function getKeysSortedByValue(t)
  -- Create a list of keys from the table
  local keys = {}
  for k in pairs(t) do
    table.insert(keys, k)
  end

  -- Sort the keys based on the table values
  table.sort(keys, function(a, b)
    return t[a] < t[b]
  end)

  return keys
end
--#endregion

--#region Spawn Methods
local function ActivateGroup(GroupName)
  if GroupName ~= '' and GroupName ~= nil then
    local group = GROUP:FindByName(GroupName)
    if (group) then
      group:Activate()
      env.info("Activated Group: " .. GroupName)
    else
      env.error("Attempted to activate a non-existant group: " .. GroupName)
    end
  end
end

local function SpawnPlaneConvoy(arguments)
  local coalition = arguments.coalition
  local sourceTheater = arguments.sourceTheater
  local destinationTheater = arguments.destinationTheater
  local sourceAirport = arguments.sourceAirport --TODO - Off Map?
  local destinationAirport = arguments.destinationAirport

  local groupName = "conv-" .. sourceTheater .. "-" .. destinationTheater

  VehicleCargoSet = SET_CARGO:New():FilterTypes("Infantry"):FilterStart()

  local WorkerGroup = GROUP:FindByName("testCargo-1")                                    --TODO - Spawn these at source airbase
  local WorkersCargo = CARGO_GROUP:New(WorkerGroup, "Infantry", "testCargo-1", 5000, 35) --TODO - Naming?
  WorkersCargo:SetWeight(500)


  local spawnTheater = sourceTheater .. "-convoy"
  local landingZone = destinationTheater .. "-convoy"
  local templateName = "template-" .. coalition .. "-planeConvoy"
  local spawnZone = ZONE:New(spawnTheater)
  if spawnZone == nil then
    -- env.warning("Unable to find spawn zone for convoy " .. groupName)
    return
  end
  local vec = spawnZone:GetPointVec3()
  local spawn_coordinate = COORDINATE:NewFromVec3(vec)
  spawnedGroup = SPAWN:NewWithAlias(templateName, groupName)
      :InitPositionCoordinate(spawn_coordinate)
      :InitRandomizeUnits(true, 500, 50)
      :InitRepeatOnEngineShutDown()
      :OnSpawnGroup(
        function(Airplane)
          CargoAirplane = AI_CARGO_AIRPLANE:New(Airplane, VehicleCargoSet)
          PickupAirbase = AIRBASE:FindByName(sourceAirport)
          DeployAirbases = { AIRBASE:FindByName(destinationAirport) }
          CargoAirplane:Pickup(PickupAirbase:GetCoordinate())

          function CargoAirplane:OnAfterLoaded(Airplane, From, Event, To, Cargo)
            CargoAirplane:__Deploy(0.2, DeployAirbases[math.random(#DeployAirbases)]:GetCoordinate(),
              math.random(500, 750))
          end

          --function CargoAirplane:OnAfterUnloaded( Airplane, From, Event, To, Cargo )
          function CargoAirplane:OnAfterDeployed(Airplane, From, Event, To, DeployZone)
            CargoAirplane:__Pickup(0.2, PickupAirbase:GetCoordinate(), math.random(500, 750))
          end
        end
      )
      :Spawn() -- TODO why won't spawn scheduled work here?
end

local function SpawnHeloConvoy(arguments)
  local sourceTheater = arguments.sourceTheater
  local destinationTheater = arguments.destinationTheater
  local coalition = arguments.coalition

  local groupName = "conv-" .. sourceTheater .. "-" .. destinationTheater
  local landingZone1 = sourceTheater .. "-convoy"
  local landingZone2 = destinationTheater .. "-convoy" -- TODO - Make resilient via warning if zone not found.
  local templateName = "template-" .. coalition .. "-heloConvoy"

  local spawnZone = ZONE:New(landingZone1)
  if spawnZone == nil then
    -- env.warning("Unable to find spawn zone for convoy " .. groupName)
    --There was no explicit landing zone defined. Use the zone itself.
    spawnZone = ZONE:New(sourceTheater)
    if spawnZone == nil then
      --If we don't find the primary zone either this probably isn't on the right map.
      return
    end
  end
  local vec = spawnZone:GetPointVec3()
  local spawn_coordinate = COORDINATE:NewFromVec3(vec)

  spawnedGroup = SPAWN:NewWithAlias(templateName, groupName)
      :InitPositionCoordinate(spawn_coordinate)
      :InitRandomizeUnits(true, 500, 50)
      :InitRepeatOnEngineShutDown()
      :OnSpawnGroup(
        function(SpawnGroup)
          local zone1 = ZONE:New(landingZone1)
          if zone1 == nil then
            -- env.warning("Unable to find spawn zone for convoy " .. groupName)
            --There was no explicit landing zone defined. Use the zone itself.
            zone1 = ZONE:New(sourceTheater)
            if zone1 == nil then
              --If we don't find the primary zone either this probably isn't on the right map.
              return
            end
          end
          local zoneVec1 = zone1:GetPointVec3()
          local coordinate1 = COORDINATE:NewFromVec3(zoneVec1)

          local zone2 = ZONE:New(landingZone2)
          if zone2 == nil then
            -- env.warning("Unable to find spawn zone for convoy " .. groupName)
            --There was no explicit landing zone defined. Use the zone itself.
            zone2 = ZONE:New(destinationTheater)
            if zone2 == nil then
              --If we don't find the primary zone either this probably isn't on the right map.
              return
            end
          end
          local zoneVec2 = zone2:GetPointVec3()
          local coordinate2 = COORDINATE:NewFromVec3(zoneVec2)

          Fg = FLIGHTGROUP:New(SpawnGroup)
          Mission = AUFTRAG:NewLANDATCOORDINATE(coordinate2:GetCoordinate())
          Mission2 = AUFTRAG:NewLANDATCOORDINATE(coordinate1:GetCoordinate()) -- TODO loop additional times?
          Fg:AddMission(Mission)
          Fg:AddMission(Mission2)
        end
      )
      :Spawn()
end

local function SpawnTruckConvoy(arguments)
  local sourceTheater = arguments.sourceTheater
  local destinationTheater = arguments.destinationTheater
  local coalition = arguments.coalition

  local groupName = "conv-" .. sourceTheater .. "-" .. destinationTheater
  local landingZone1 = sourceTheater .. "-convoy"
  local landingZone2 = destinationTheater .. "-convoy" -- TODO - Make resilient via warning if zone not found.

  local templateName = "template-" .. coalition .. "-truckConvoy"

  local zone1 = ZONE:New(landingZone1)
  if zone1 == nil then
    -- env.warning("Unable to find spawn zone for convoy " .. groupName)
    --There was no explicit landing zone defined. Use the zone itself.
    zone1 = ZONE:New(sourceTheater)
    if zone1 == nil then
      --If we don't find the primary zone either this probably isn't on the right map.
      return
    end
  end
  local zoneVec1 = zone1:GetPointVec3()
  local coordinate1 = COORDINATE:NewFromVec3(zoneVec1)

  spawnedGroup = SPAWN:NewWithAlias(templateName, groupName)
      :InitPositionCoordinate(coordinate1)
      :InitRandomizeUnits(true, 200, 50)
      :InitRepeatOnEngineShutDown()
      :OnSpawnGroup(
        function(SpawnGroup)
          local zone2 = ZONE:New(landingZone2)
          if zone2 == nil then
            -- env.warning("Unable to find destination zone for convoy " .. groupName)
            --There was no explicit landing zone defined. Use the zone itself.
            zone2 = ZONE:New(destinationTheater)
          end
          local zoneVec2 = zone2:GetPointVec3()
          local coordinate2 = COORDINATE:NewFromVec3(zoneVec2)

          SpawnGroup:RouteGroundOnRoad(coordinate2, 46) --TODO - Delay start time? Randomize more?
        end
      )
      :Spawn()
end
--TODO -Add randomization based on available templates so not all flights are the same type of aircraft.
--TODO -Add CAS missions
local function SpawnShipConvoy(coalition, sourceTheater, destinationTheater)
  local groupName = "conv-" .. sourceTheater .. "-" .. destinationTheater
  local landingZone1 = sourceTheater .. "-shipConvoy"
  local landingZone2 = destinationTheater .. "-shipConvoy"
  local midPoint = sourceTheater .. "-shipConvoy-turn"           --TODO - if nil simplify path.
  local templateName = "template-" .. coalition .. "-shipConvoy" -- TODO - Make resilient via warning if zone not found.

  local zone1 = ZONE:New(landingZone1)
  if zone1 == nil then
    --If we don't find the ship zone this probably isn't the right map. Skip it.
    return
  end
  local zoneVec1 = zone1:GetPointVec3()
  local coordinate1 = COORDINATE:NewFromVec3(zoneVec1)
  local wp1 = coordinate1:WaypointNaval(26)

  local zone2 = ZONE:New(landingZone2)
  local zoneVec2 = zone2:GetPointVec3()
  local coordinate2 = COORDINATE:NewFromVec3(zoneVec2)
  local wp2 = coordinate2:WaypointNaval(26)

  local zone3 = ZONE:New(midPoint)
  local zoneVec3 = zone3:GetPointVec3()
  local coordinate3 = COORDINATE:NewFromVec3(zoneVec3)
  local wp3 = coordinate3:WaypointNaval(26)

  SPAWN:NewWithAlias(templateName, groupName)
      :InitPositionCoordinate(coordinate1)
      :InitRandomizeUnits(true, 500, 50)
      :InitRepeatOnEngineShutDown()
      :OnSpawnGroup(
        function(SpawnGroup)
          local shipWaypoints = { wp1, wp2, wp3, wp2, wp1 }
          local shipTask = SpawnGroup:TaskRoute(shipWaypoints)
          SpawnGroup:PushTask(shipTask, 0)
        end
      )
      :InitLimit(2, 1)
      :Spawn()
end

local function spawnSeadMission(arguments)
  local sourceTheater = arguments.sourceTheater
  local destinationTheater = arguments.destinationTheater

  env.info("Scheduling sead package from " .. sourceTheater .. ".")

  local zone1 = ZONE:New(sourceTheater)
  local zoneVec1 = zone1:GetPointVec3()
  local coordinate1 = COORDINATE:NewFromVec3(zoneVec1)

  local groupName = "sead-" .. sourceTheater .. "-" .. destinationTheater
  local templateName = "template-red-sead"
  local seadTarget = "sam-blue-" .. destinationTheater

  local targetGroupName = nil
  for i, gp in pairs(coalition.getGroups(2)) do
    local groupNameSearch = Group.getName(gp)
    if (starts_with(groupNameSearch, seadTarget)) then
      targetGroupName = groupNameSearch
      break
    end
  end
  env.info("Targetting " .. targetGroupName .. " with SEAD mission.")

  local targetGroup = GROUP:FindByName(targetGroupName)

  SPAWN:NewWithAlias(templateName, groupName)
      :InitPositionCoordinate(coordinate1)
      :OnSpawnGroup(
        function(spawnGroup)
          spawnGroup:OptionRTBAmmo(3221225470)
          local strikeAuftrag = AUFTRAG:NewSEAD(targetGroup, 10000)
          strikeAuftrag:SetWeaponExpend("Half")
          local strikeGrp = FLIGHTGROUP:New(spawnGroup)
          strikeGrp:AddMission(strikeAuftrag)
        end
      )
      :InitLimit(2, 1)
      :Spawn()
end

--TODO - Warn everyone of strikes?
--TODO - Target HVTs and convoys?

local function spawnStrikeMission(arguments)
  local sourceTheater = arguments.sourceTheater
  local destinationTheater = arguments.destinationTheater

  env.info("Scheduling strike package from " .. sourceTheater .. ".")
  MESSAGE:New(sourceTheater .. " is attacking " .. destinationTheater .. " via airstrike.", 20):ToAll()
  local groupName = "strike-" .. sourceTheater .. "-" .. destinationTheater
  local templateName = "template-red-strike"
  local strikeZoneName = destinationTheater .. "-strike"

  local zone1 = ZONE:New(sourceTheater)
  local zoneVec1 = zone1:GetPointVec3()
  local coordinate1 = COORDINATE:NewFromVec3(zoneVec1)
  --TODO - Cancel strike if sead isn't complete yet?
  SPAWN:NewWithAlias(templateName, groupName)
      :InitPositionCoordinate(coordinate1)
      :OnSpawnGroup(
        function(spawnGroup)
          spawnGroup:OptionRTBAmmo(2147485694)

          local strikeZone = ZONE:New(strikeZoneName)
          if strikeZone == nil then
            env.warning("Unable to find strike zone for attack for " .. groupName)
            --There was no explicit landing zone defined. Use the zone itself.
            strikeZone = ZONE:New(destinationTheater)
            if strikeZone == nil then
              env.error("Unable to find zone for attack for " .. groupName)
              --If we don't find the primary zone either this probably isn't on the right map.
              return
            end
          end

          local strikeCoordinate = strikeZone:GetRandomCoordinate()
          local strikeAuftrag = AUFTRAG:NewBOMBING(strikeCoordinate, 10000)
          local strikeGrp = FLIGHTGROUP:New(spawnGroup)
          strikeGrp:AddMission(strikeAuftrag)
        end
      )
      :InitLimit(2, 1)
      :Spawn()
end

local function spawnArmorMission(arguments)
  local sourceTheater = arguments.sourceTheater
  local destinationTheater = arguments.destinationTheater
  env.info("Scheduling armor package from " .. sourceTheater)
  MESSAGE:New(sourceTheater .. " is attacking " .. destinationTheater .. " via armor.", 20):ToAll()

  local groupName = "armor-" .. sourceTheater .. "-" .. destinationTheater
  local sourceZone = sourceTheater .. "-convoy"
  local destinationZone = destinationTheater .. "-strike" -- TODO - Make resilient via warning if zone not found.

  local templateNum = math.random(0, 2)
  local templateName = "template-red-armor"
  if templateNum > 0 then
    templateName = templateName .. "-" .. templateNum
  end

  local zone1 = ZONE:New(sourceZone)
  if zone1 == nil then
    -- env.warning("Unable to find spawn zone for convoy " .. groupName)
    --There was no explicit landing zone defined. Use the zone itself.
    zone1 = ZONE:New(sourceTheater)
    if zone1 == nil then
      --If we don't find the primary zone either this probably isn't on the right map.
      return
    end
  end
  local zoneVec1 = zone1:GetPointVec3()
  local coordinate1 = COORDINATE:NewFromVec3(zoneVec1)

  spawnedGroup = SPAWN:NewWithAlias(templateName, groupName)
      :InitPositionCoordinate(coordinate1)
      :InitRandomizeUnits(true, 200, 50)
      :InitRepeatOnEngineShutDown()
      :OnSpawnGroup(
        function(SpawnGroup)
          local zone2 = ZONE:New(destinationZone)
          if zone2 == nil then
            --There was no explicit landing zone defined. Use the zone itself.
            zone2 = ZONE:New(destinationTheater)
          end
          local zoneVec2 = zone2:GetPointVec3()
          local coordinate2 = COORDINATE:NewFromVec3(zoneVec2)

          SpawnGroup:RouteGroundOnRoad(coordinate2, 46)
        end
      )
      :Spawn()
end

local function activateGroupByHealth(groupSetName, groupList, groupListSize, healthPercent, desiredSize, alwaysOne)
  local activateCount = 0

  if (healthPercent == 0) then
    --If the health is *exactly* 0, don't spawn this group.
    env.info("Not activating groups for " .. groupSetName .. " because it is at 0 health.")
  else
    if (healthPercent > .3) then
      alwaysOne = true -- Don't let it drop completely off unless health is very low. This is to complensate for zones with a small number of air defenses which otherwise tend not to spawn much below 70% health. Probably a better way to do this.
    end
    -- If it is even slightly above zero, do.
    activateCount = Lround(healthPercent * desiredSize)
    -- Activate no less than one groups
    if activateCount < 1 and alwaysOne then
      activateCount = 1
    end
  end

  if (groupListSize > 0 and activateCount > 0) then
    -- Shuffle the list so we randomly select but don't repeat any
    shuffle(groupList)
    if (activateCount > groupListSize) then
      env.warning("Group set size exceeds available number of groups.")
      activateCount = groupListSize
    end
    env.info("Selecting " .. activateCount .. " out of " .. groupListSize .. " groups for " .. groupSetName .. ".")
    -- Select up to "size" groups randomly from shuffled list
    for i = 1, activateCount do
      ActivateGroup(groupList[i])
    end
  else
    -- env.warning("Not activating group " ..
    -- groupSetName .. ". groupListSize: " .. groupListSize .. " activateCount: " .. activateCount)
  end
end

local function activateGroupsByCoalitionAndPrefix(coalitionId, prefix, theaterName, healthPercent)
  local coalitionName = "blue"
  if (coalitionId == 1) then
    coalitionName = "red"
  end

  --Activate SAM groups
  local numGroups = 0
  local groupList = {}
  local fullPrefix = prefix .. "-" .. coalitionName .. "-" .. theaterName

  --Find any groups whose name matches our SAM template and this theaterName
  for i, gp in pairs(coalition.getGroups(coalitionId)) do
    local groupName = Group.getName(gp)
    if (starts_with(groupName, fullPrefix)) then
      -- Lua is 1 indexed.
      numGroups = numGroups + 1
      groupList[numGroups] = groupName
    end
  end

  activateGroupByHealth(fullPrefix, groupList, numGroups, healthPercent, numGroups, false) --TODO - For now we always activate the maximum number of sam sites. Consider randomness later
end

local function activateCap(group, airport, zone, healthPercent, theaterName)
  local squadronName = group .. "-" .. theaterName
  local supply = math.floor(6 * healthPercent)
  local capZone = ZONE:New(zone)

  A2ADispatcher:SetSquadron(squadronName, airport, { group }, supply)
  A2ADispatcher:SetSquadronCap(squadronName, capZone, 8000, 10000, 500, 600, 800, 900)
  A2ADispatcher:SetSquadronCapRacetrack(squadronName, 10000, 20000, 90, 180, 10 * 60, 20 * 60)
  A2ADispatcher:SetSquadronCapInterval(squadronName, 2, 30, 60, 1)
  A2ADispatcher:SetSquadronTakeoffInAir(squadronName)
  A2ADispatcher:SetSquadronFuelThreshold(squadronName, 0.4)

  env.info("Activated CAP: " .. squadronName .. ": " .. supply .. " : " .. healthPercent)
end
--#endregion

--#region Load Target Values
local targetValuesFileContents = read_file(TargetValuesFilePath)
if targetValuesFileContents then
  TargetValuesJson, _, err = JSON:decode(targetValuesFileContents)
end
--#endregion

--#region Initialize Simulation

--Oh lua...
local function removeFirst(list)
  local returnList = {}
  for i, item in ipairs(list) do
    if i > 1 then
      table.insert(returnList, item)
    end
  end
  return returnList
end

local function removeEdge(list, edgeToRemove)
  -- env.info("Attempting to remove edge " .. dump(edgeToRemove))
  local returnList = {}
  for _, edge in ipairs(list) do
    if edge.source ~= edgeToRemove.source or edge.destination ~= edgeToRemove.destination then
      table.insert(returnList, edge)
    else
      -- env.info("Removing edge: " .. edge.source .. " " .. edge.destination)
    end
  end
  return returnList
end

--Topological Sorting (Kahn's algorithm) https://gist.github.com/Sup3rc4l1fr4g1l1571c3xp14l1d0c10u5/3341dba6a53d7171fe3397d13d00ee3f
--This is my Lua reimplementation of this method.
--https://en.wikipedia.org/wiki/Topological_sorting
local function TopologicalSort(nodes, edges)
  --Empty list that will contain the sorted elements
  local L = {}
  --Set of all nodes with no incoming edges
  local S = {}
  for _, node in ipairs(nodes) do
    local found = false
    for _, edge in ipairs(edges) do
      if (edge.destination == node) then
        found = true
      end
    end
    if (found == false) then
      table.insert(S, node)
    end
  end

  -- env.info("Starting toposort on S with " .. tableLength(S) .. " items.")
  --Add a max iteration because infinite loops in embedded lua are :(
  local count = 0
  --While S is non-empty
  while (tableLength(S) > 0 and count < 10000) do
    count = count + 1
    --Remove a node n from S
    -- env.info("S: " .. dump(S))
    local n = S[1]
    S = removeFirst(S)
    -- env.info("S removed: " .. dump(S))

    --Add n to the tail of L
    table.insert(L, n)

    --For each node m with an edge e from n to m do
    for _, e in ipairs(edges) do
      if (e.source == n) then
        local m = e.destination

        --Remove edge e from the graph
        edges = removeEdge(edges, e)

        --If m has no other incoming edges then
        local found = false
        for _, me in ipairs(edges) do
          if me.destination == m then
            found = true
          end
        end
        -- insert m into S
        if found == false then
          table.insert(S, m)
        end
      end
    end
  end

  --If graph has edges then
  if tableLength(edges) > 0 then
    env.info("Toposort Failed: " .. dump(edges))
    --Return error (graph has at least one cycle)
    return nil
  else
    --Return L (a topologically sorted order)
    return L
  end
end

---Step 0: Flip zones that are captured (0 health) and then start producing manufactured goods.
local function StepO()
  --New - Before doing anything else damage all blue zones by ATTRITION_AMOUNT. If a blue zone is unsupported it should eventually flip back.
  for zoneName, zone in pairs(CurrentState.TheaterHealth) do
    if zone.Coalition == "blue" then
      zone.Health = zone.Health - ATTRITION_AMOUNT
      if zone.Health < 0 then
        zone.Health = 0
      end
    end
  end

  for zoneName, zone in pairs(CurrentState.TheaterHealth) do
    if zone.Health == 0 then
      if zone.Coalition == "red" then
        zone.Coalition = "blue"
        zone.Health = MANUFACTURE_AMOUNT -- Prevent a zone from flipping back and forth each day in the absence of other activity. Gives about a 4 day buffer.
        env.info("Zone " .. zoneName .. " captured by blue.")
      else
        zone.Coalition = "red"
        zone.Health = MANUFACTURE_AMOUNT
        env.info("Zone " .. zoneName .. " captured by red.")
      end
    end

    --We temporarily allow zones to have a surplus of goods. These will spillover if not used by the end of the day's simulation.
    if zone.ManufacturingSource then
      zone.Health = zone.Health + MANUFACTURE_AMOUNT
      env.info("Zone " .. zoneName .. " manufactured " .. MANUFACTURE_AMOUNT .. " goods.")
    end
  end
end

---Step 1: Traverse both graphs in topological order and pull supplies along connections. This approach prioritizes moving resources upstream so that we maximize
---the usage of supplies which would spillover if left in full warehouses at their source.
local function Step1(topologicalSort)
  for _, zoneName in ipairs(topologicalSort) do
    local zone = CurrentState.TheaterHealth[zoneName]

    --Does this zone still need further healing?
    if zone.Health < zone.MaxHealth then
      --Find an upstream zone that has sufficient supplies to ship to us.
      for _, connection in ipairs(Connections) do
        local upstreamZone = nil
        local upstreamZoneName = nil
        if connection.DestinationTheater == zoneName and CurrentState.TheaterHealth[connection.SourceTheater].Coalition == zone.Coalition then
          upstreamZone = CurrentState.TheaterHealth
              [connection.SourceTheater] --TODO Clean up now that reversing isn't a thing.
          upstreamZoneName = connection.SourceTheater
        end

        if upstreamZone then
          if zone.Health < zone.MaxHealth and upstreamZone.Health > RESUPPLY_AMOUNT then --Recheck since we are doing this in a loop, and verify source has enough to give.
            --Reduce supplied amount by the amount that can be sent across connection
            local suppliedAmount = RESUPPLY_AMOUNT
            if upstreamZone.Health - suppliedAmount > 0 then
              --If providing these supplies would wipe this zone, don't do it.
              zone.Health = zone.Health + suppliedAmount
              upstreamZone.Health = upstreamZone.Health - suppliedAmount
              env.info(zoneName .. " resupplied by " .. upstreamZoneName .. " by " .. suppliedAmount .. ".")
            end
          end
        end
      end
    end
  end
end

--This method computs the current health of all zones across all maps. This needs to be done across all maps because the map which starts today
--may not be the last one to run on the server. It's also difficult to delineate map boundaries when doing graph traversals.
local function RunDailySimulation()
  --Check to see when the last time the simulation ran was.
  --If it was more than 22 hours ago (2 hours grace period for server start times being different each day), run in 24 hour increments to catch up.
  local lastRun = CurrentState.LastModified
  local currentTime = os.time(os.date("!*t"))
  if currentTime - lastRun < (22 * 60 * 60) then
    env.info("Mission starting but simulation does not need to run. Last run time was " ..
      (currentTime - lastRun) / 60 / 60 .. " hours ago.")
    return
  end
  --TODO - In v1 I ran the simulation multiple times if the server was behind by multiple days. In practice this never really happened and I don't want to do the math right now, but could come back to this.

  env.info("Running economic simulation.")
  --Run a topological sort of the zone graph
  local redNodes = {}
  local redEdges = {}
  local blueNodes = {}
  local blueEdges = {}
  for zoneName, zone in pairs(CurrentState.TheaterHealth) do
    if (zone.Coalition == "red") then
      table.insert(redNodes, zoneName)
    else
      table.insert(blueNodes, zoneName)
    end
  end

  for _, connection in ipairs(Connections) do
    local edge = {}

    if CurrentState.TheaterHealth[connection.SourceTheater] == "red" and CurrentState.TheaterHealth[connection.DestinationTheater] == "red" then
      --If it is a red edge
      edge.source = connection.DestinationTheater
      edge.destination = connection.SourceTheater
      table.insert(redEdges, edge)
    elseif CurrentState.TheaterHealth[connection.SourceTheater] == "blue" and CurrentState.TheaterHealth[connection.DestinationTheater] == "blue" then
      --If it is a blue edge
      edge.source = connection.DestinationTheater
      edge.destination = connection.SourceTheater
      table.insert(blueEdges, edge)
    end
  end
  local redTopologicalOrder = TopologicalSort(redNodes, redEdges)
  env.info(dump(redTopologicalOrder))

  local blueTopologicalOrder = TopologicalSort(blueNodes, blueEdges)
  env.info(dump(blueTopologicalOrder))

  StepO()

  if (blueTopologicalOrder ~= nil) then
    Step1(blueTopologicalOrder)
  end

  if (redTopologicalOrder ~= nil) then
    Step1(redTopologicalOrder)
  end

  --Step 2: Make sure no zones are oversupplied.
  for zoneName, zone in pairs(CurrentState.TheaterHealth) do
    if zone.Health > zone.MaxHealth then
      zone.Health = zone.MaxHealth
    end
  end

  local currentTIme = os.time(os.date("!*t"))
  CurrentState.LastModified = currentTIme

  env.info("Final state: ")
  env.info(JSON:encode(CurrentState))
end
--#endregion

--#region Process Config Files
local function ProcessConnections(connections)
  env.info("Processing Connections")
  local zonesToAttack = {}

  for _, connection in ipairs(connections) do
    local connectionName = connection.SourceTheater .. "-" .. connection.DestinationTheater
    local sourceTheater = connection.SourceTheater
    local destinationTheater = connection.DestinationTheater

    local coalition = CurrentState.TheaterHealth[sourceTheater].Coalition

    if CurrentState.TheaterHealth[sourceTheater].Coalition ~= CurrentState.TheaterHealth[destinationTheater].Coalition then
      --This connection is between a red and a blue coalition. This means combat!
      if CurrentState.TheaterHealth[sourceTheater].Coalition == "blue" then
        table.insert(zonesToAttack, sourceTheater)
      elseif CurrentState.TheaterHealth[destinationTheater].Coalition == "blue" then
        table.insert(zonesToAttack, destinationTheater)
      end
    else
      --TODO Fixed wing cargo for cross-map usage
      local delay = math.random(1, 240) * 60
      if connection.Type == "HELO" then
        timer.scheduleFunction(SpawnHeloConvoy,
          {
            coalition = coalition,
            sourceTheater = sourceTheater,
            destinationTheater = destinationTheater
          },
          timer.getTime() + delay)
      end

      if connection.Type == "TRUCK" then
        timer.scheduleFunction(SpawnTruckConvoy,
          {
            coalition = coalition,
            sourceTheater = sourceTheater,
            destinationTheater = destinationTheater
          },
          timer.getTime() + delay)
      end

      if connection.Type == "SHIP" then
        SpawnShipConvoy(coalition, sourceTheater, destinationTheater)
      end

      if connection.Type == "PLANE" then
        timer.scheduleFunction(SpawnPlaneConvoy,
          {
            coalition = coalition,
            sourceTheater = sourceTheater,
            destinationTheater = destinationTheater,
            sourceAirport =
                CurrentState.TheaterHealth[sourceTheater].Airport,
            destinationAirport = CurrentState.TheaterHealth
                [destinationTheater].Airport
          },
          timer.getTime() + delay)
      end
    end
    --Add connection to the map
    local drawCoalition = "grey"
    if CurrentState.TheaterHealth[sourceTheater].Coalition == CurrentState.TheaterHealth[destinationTheater].Coalition then
      drawCoalition = CurrentState.TheaterHealth[sourceTheater].Coalition
    end
    DrawConnectionHelper(sourceTheater, destinationTheater, drawCoalition, connectionName, connection.Type)
  end
  return zonesToAttack
end

-- Read JSON content from file
local jsonStateContent = read_file(StateFilePath)

if jsonStateContent then
  CurrentState, _, err = JSON:decode(jsonStateContent)

  --To simplify the transition between datastructures, building a list of all connections here from the new state file format. This used to be broken out into a list of edges separate from the zone definition.
  for theaterName, theater in pairs(CurrentState.TheaterHealth) do
    if theater.HeloConnections then
      for _, connectionDestination in ipairs(theater.HeloConnections) do
        local connection = {}
        connection.DestinationTheater = connectionDestination
        connection.SourceTheater = theaterName
        connection.Type = "HELO"
        table.insert(Connections, connection)
      end
    end
    if theater.ShipConnections then
      for _, connectionDestination in ipairs(theater.ShipConnections) do
        local connection = {}
        connection.DestinationTheater = connectionDestination
        connection.SourceTheater = theaterName
        connection.Type = "SHIP"
        table.insert(Connections, connection)
      end
    end
    if theater.PlaneConnections then
      for _, connectionDestination in ipairs(theater.PlaneConnections) do
        local connection = {}
        connection.DestinationTheater = connectionDestination
        connection.SourceTheater = theaterName
        connection.Type = "PLANE"
        table.insert(Connections, connection)
      end
    end
    if theater.TruckConnections then
      for _, connectionDestination in ipairs(theater.TruckConnections) do
        local connection = {}
        connection.DestinationTheater = connectionDestination
        connection.SourceTheater = theaterName
        connection.Type = "TRUCK"
        table.insert(Connections, connection)
      end
    end
  end

  RunDailySimulation()
  local theaterCount = 0
  -- Iterate through TheaterList
  for theaterName, theater in pairs(CurrentState.TheaterHealth) do
    local theaterZone = ZONE:New(theaterName)
    if (theaterZone ~= nil) then
      -- Load Zone for Theater and add to Zone list.
      MapZonesByTheaterName[theaterName] = theaterZone
      -- Get zone coords
      local theaterCoord = theaterZone:GetVec2()
      local theaterCoord3 = COORDINATE:NewFromVec2(theaterCoord)
      local radius = theaterZone:GetRadius()
      -- Check if Connections is not nil before iterating
      -- Draw Theaters

      local theaterHealth = theater.Health
      local theaterCoalition = theater.Coalition
      DrawTheater(theater, theaterHealth, theaterCoalition, theaterCoord3, radius, theaterName)

      theaterCount = theaterCount + 1

      --Activate all late-activated units. These are mission-creator placed assets vs the randomly spawned units like convoys and strike packages.
      if theater.Coalition == "red" then
        activateGroupsByCoalitionAndPrefix(1, "ewr", theaterName, theaterHealth / theater.MaxHealth)
        activateGroupsByCoalitionAndPrefix(1, "sam", theaterName, theaterHealth / theater.MaxHealth)
        activateGroupsByCoalitionAndPrefix(1, "hvt", theaterName, theaterHealth / theater.MaxHealth)
      else
        activateGroupsByCoalitionAndPrefix(2, "ewr", theaterName, theaterHealth / theater.MaxHealth)
        activateGroupsByCoalitionAndPrefix(2, "sam", theaterName, theaterHealth / theater.MaxHealth)
        activateGroupsByCoalitionAndPrefix(2, "hvt", theaterName, theaterHealth / theater.MaxHealth)
      end
    end
  end

  -- Iterate through Connections
  local theatersToAttack = ProcessConnections(Connections)

  --TODO - Revamp attack schedule:
  -- Identify source zones for air attack
  -- Sort potential targets by distance
  -- Schedule
  -- For ground attacks, select zones with broken connections, sort by distance, attack.


  --Schedule Air Attacks
  local totalAttacks = 8

  local redAirportZones = {}
  env.info("=== Planning Air Attacks ===")
  for name, _ in pairs(MapZonesByTheaterName) do
    if CurrentState.TheaterHealth[name].Coalition == "red" and CurrentState.TheaterHealth[name].Airport and CurrentState.TheaterHealth[name].Health / CurrentState.TheaterHealth[name].MaxHealth > .25 then
      table.insert(redAirportZones, name)
      table.insert(redAirportZones, name)
      table.insert(redAirportZones, name)
      --Kind of silly but we'll allow up to 3 attacks from each zone this way.
      env.info("Adding " .. name .. " as a potential air attack source.")
    end
  end
  --Randomize which strike launches from which airport.
  shuffle(redAirportZones)
  local blueTargetZonesHealthPercent = {}

  for name, _ in pairs(MapZonesByTheaterName) do
    if CurrentState.TheaterHealth[name].Coalition == "blue" then
      blueTargetZonesHealthPercent[name] = CurrentState.TheaterHealth[name].Health /
          CurrentState.TheaterHealth[name].MaxHealth
    end
  end

  --Create a list of the zones sorted by health from lowest to highest.
  local blueTargetZones = getKeysSortedByValue(blueTargetZonesHealthPercent)
  BlueZonesAlphabetized = getKeysSortedByValue(blueTargetZonesHealthPercent)
  local blueAttackZones = {}

  --Take first totalAttacks items from target zones.
  for i = 1, totalAttacks do
    table.insert(blueAttackZones, blueTargetZones[i])
  end

  shuffle(blueAttackZones)

  local attackTime = 0
  --Until we run out of zones to attack from, schedule an attack on each of the zones focusing on lowest health first.
  for i, attackingTheater in ipairs(redAirportZones) do
    if i > totalAttacks or i > #blueAttackZones then
      break
    end
    local theaterToAttack = blueAttackZones[i]
    attackTime = math.random((i * 60 * 60 + 10 * 60), (i * 60 * 60 + 60 * 60))
    timer.scheduleFunction(spawnSeadMission,
      { sourceTheater = attackingTheater, destinationTheater = theaterToAttack }, timer.getTime() + attackTime)
    timer.scheduleFunction(spawnStrikeMission,
      { sourceTheater = attackingTheater, destinationTheater = theaterToAttack },
      timer.getTime() + attackTime + 120)
    env.info("New air attack planned. " .. attackingTheater .. ":" .. theaterToAttack .. " : " .. attackTime)
    AttackSchedule[attackingTheater .. i] = theaterToAttack
    AttackTime[attackingTheater .. i] = attackTime
  end

  env.info("=== Planning Ground Attacks ===")
  --Schedule Ground Attacks
  for _, theaterToAttack in ipairs(theatersToAttack) do
    local zone1 = ZONE:New(theaterToAttack .. "-strike")
    if (zone1 ~= nil) then
      env.info("Planning attack on " .. theaterToAttack)
      -- Find a suitable zone to attack this one.
      for attackingTheater, _ in pairs(MapZonesByTheaterName) do
        -- Not a very efficient approach but there aren't a lot of ways to deal with dynamic lists.
        local theaterAlreadyAttacking = false
        for alreadyAttacking, alreadyBeingAttacked in pairs(GroundAttackSchedule) do --lawd the naming
          if attackingTheater == alreadyAttacking then
            theaterAlreadyAttacking = true
            env.info(attackingTheater .. " is already attacking " .. alreadyBeingAttacked)
            break --Once we find it in the list of attacking theaters we don't have to keep looking.
          end
        end
        --This theater is already attacking a different theater. For now lets limit to one mission per.
        if not theaterAlreadyAttacking then
          -- env.info(attackingTheater .. " is a candidate.")
          if CurrentState.TheaterHealth[attackingTheater].Coalition == "red" and CurrentState.TheaterHealth[attackingTheater].Health / CurrentState.TheaterHealth[attackingTheater].MaxHealth > .25 then
            --This zone should attack if it can.
            --Make sure the distance is not too far.
            --TODO - Sort by nearest?
            local delay = math.random(5, 240) * 60
            timer.scheduleFunction(spawnArmorMission,
              { sourceTheater = attackingTheater, destinationTheater = theaterToAttack }, timer.getTime() + delay)
            env.info("New ground attack planned. " .. attackingTheater .. ":" .. theaterToAttack)
            GroundAttackSchedule[attackingTheater] = theaterToAttack
            GroundAttackTime[attackingTheater] = delay
            break --Once we schedule an attack for this theater we don't need to schedule more.
          end
        end
      end
    end
  end

  --Alphabetize zones and break them into pages.
  ZonesAlphabetized = alphabetizePaged(MapZonesByTheaterName)
  -- env.info("Alphabetized Pages: " .. dump(AlphaZones))
else
  env.info("Failed to read JSON file.")
end
--#endregion

--#region Cargo Methods
CargoStatus = {}
LandedStatus = {}

local function cargoHandlingAllowed(inUseType)
  local allowedCargoTypes = { "UH-1H" } -- TODO - Add Chinook
  local unitType = inUseType
  for _, typeName in ipairs(allowedCargoTypes) do
    if typeName == unitType then
      return true
    end
  end
  return false
end
function LoadCargo(groupName)
  local cargoHealth = 300
  local group = Group.getByName(groupName)
  local unit = group:getUnit(1)
  local mGroup = GROUP:FindByName(groupName) --Redundant but that's mixing mist and moose for you. Probably a better way.

  if CargoStatus[groupName] > 0 then
    MESSAGE:New(groupName .. " cannot load cargo. Already carrying too much.", 20):ToGroup(mGroup)
    return
  end

  if not LandedStatus[groupName] then
    MESSAGE:New(groupName .. " cannot load cargo. Not yet landed.", 20):ToGroup(mGroup)
    return
  end

  if CurrentState.TheaterHealth[LandedStatus[groupName]].Health < cargoHealth then
    MESSAGE:New(groupName .. " cannot load cargo. Zone has insufficient supplies.", 20):ToGroup(mGroup)
  end

  MESSAGE:New(groupName .. " loaded cargo at " .. LandedStatus[groupName] .. ".", 20):ToAll()
  CargoStatus[groupName] = cargoHealth
  trigger.action.setUnitInternalCargo(unit:getName(), 1000)
end

function UnloadCargo(groupName)
  local group = Group.getByName(groupName)
  local unit = group:getUnit(1)
  local mGroup = GROUP:FindByName(groupName) --Redundant but that's mixing mist and moose for you. Probably a better way.

  if not CargoStatus[groupName] then
    MESSAGE:New(groupName .. " cannot unload cargo. Not carrying any.", 20):ToGroup(mGroup)
    return
  end

  if CargoStatus[groupName] == 0 then
    MESSAGE:New(groupName .. " cannot unload cargo. Not carrying any.", 20):ToGroup(mGroup)
    return
  end

  if not LandedStatus[groupName] then
    MESSAGE:New(groupName .. " cannot unload cargo. Not yet landed.", 20):ToGroup(mGroup)
    return
  end

  CurrentState.TheaterHealth[LandedStatus[groupName]].Health = CurrentState.TheaterHealth[LandedStatus[groupName]]
      .Health +
      CargoStatus
      [groupName] --TODO: Different capacities by aircraft type.
  if CurrentState.TheaterHealth[LandedStatus[groupName]].Health > CurrentState.TheaterHealth[LandedStatus[groupName]].MaxHealth then
    CurrentState.TheaterHealth[LandedStatus[groupName]].Health = CurrentState.TheaterHealth[LandedStatus[groupName]]
        .MaxHealth
  end

  CargoStatus[groupName] = 0

  MESSAGE:New(groupName .. " unloaded cargo at " .. LandedStatus[groupName] .. ".", 20):ToAll()
  trigger.action.setUnitInternalCargo(unit:getName(), 0)
end

local function activateCargoHandling(playerUnit, groupName)
  local group = GROUP:FindByName(groupName)

  env.info("Activating cargo handling for: " .. groupName)
  local managementMenu = MENU_GROUP:New(group, "Cargo Management")
  MENU_GROUP_COMMAND:New(group, "Load Cargo (1,800lbs)", managementMenu, LoadCargo, groupName)
  MENU_GROUP_COMMAND:New(group, "Unload Cargo", managementMenu, UnloadCargo, groupName)
  --Initialize cargo status for this unit.
  if CargoStatus[groupName] == nil then
    CargoStatus[groupName] = 0
  end
  -- TODO Tracking landed status of a unit could get precarious. But using the menu system alone it is hard to determine which unit has hit the button. This is done at the group level largely.
  --
end
--#endRegion

--#region Event Handlers
local function handleLandedEvent(event)
  env.info("Handling landed event.")
  local groupName = event.initiator:getGroup():getName()
  env.info("Group: " .. groupName)
  local group = GROUP:FindByName(groupName)
  local playerUnit = group:GetFirstUnit()

  local theaterName = nil
  for key, theaterZone in pairs(MapZonesByTheaterName) do
    if theaterZone:IsCoordinateInZone(playerUnit:GetCoordinate()) then
      -- env.info("Kill was in zone: " .. key)
      theaterName = key
    end
  end

  -- MESSAGE:New(groupName .. " landed at " .. theaterName .. ".", 20):ToAll()
  LandedStatus[groupName] = theaterName

  local unitType = event.initiator:getDesc()['typeName']
  if cargoHandlingAllowed(unitType) then
    activateCargoHandling(playerUnit, groupName)
  end
end

local function handleTakeoffEvent(event)
  env.info("Handling takeoff event.")
  local groupName = event.initiator:getGroup():getName()
  env.info("Group: " .. groupName)
  LandedStatus[groupName] = nil
end

local function handlePlayerOccupySlot(event)
  if event.initiator and event.initiator:getCategory() == Object.Category.UNIT then
    local playerName = event.initiator:getPlayerName()
    local playerUnitName = event.initiator:getName()
    local groupName = event.initiator:getGroup():getName()

    env.info("Player unit name: " .. playerUnitName)
    if playerName then
      env.info("Player: " .. playerName .. " spawned into " .. event.initiator:getName()
        .. " from group " .. groupName .. ".") --Interesting that group data is available here?
      --todo find what zone this spawn is associated with
      local theaterName = parseZoneFromUnitName(event.initiator:getName())
      env.info("Player spawning in theater " .. theaterName)
      if CurrentState.TheaterHealth[theaterName].Coalition ~= "blue" then
        --if not controlled by blue, destroy
        trigger.action.outTextForGroup(event.initiator:getGroup():getID(),
          "Cannot spawn in zone that is not controlled by blue.", 10)
        event.initiator:destroy()
        env.info("Player " ..
          playerName .. " tried to spawn at " .. theaterName .. " which is not currently controlled by blue coalition.")
      end
      -- local unitType = event.initiator:getDesc()['typeName']
      -- if cargoHandlingAllowed(unitType) then
      --   LandedStatus[groupName] = theaterName
      --   activateCargoHandling(playerUnitName, groupName)
      -- end
    end
  end
end

local function handleKillEvent(event)
  env.info("Kill Event Handled. Type: " .. Object.getCategory(event.target))
  if (Object.getCategory(event.target) == Object.Category.SCENERY or Object.getCategory(event.target) == Object.Category.STATIC) then -- Wow is this stuff woefully underdocumented in the "official" docs.
    local scenery = event.target
    local sceneryTypeName = scenery:getTypeName()
    local sceneryName = scenery:getName()
    if (sceneryName == nil) then
      sceneryName = ""
    end
    if (sceneryTypeName == nil) then
      sceneryTypeName = ""
      env.info("Received a scenery kill event with no type at mission time: " .. timer.getTime())
      return
    end

    env.info("Scenery Kill Event Handled: " .. sceneryTypeName .. " : " .. sceneryName)

    local type = string.lower(sceneryTypeName)
    local theaterName = nil
    env.info("Kill Type: " .. type)
    for key, theaterZone in pairs(MapZonesByTheaterName) do
      if (theaterZone:IsCoordinateInZone(COORDINATE:NewFromVec3(scenery:getPoint()))) then
        env.info("Kill was in zone: " .. key)
        theaterName = key
      end
    end
    local sceneryType = removeSuffix(type, "_crash")
    local score = TargetValuesJson[sceneryType]
    if (score ~= nil and theaterName ~= nil) then
      --Target was valid and within a zone
      -- Deduct score from zone.
      CurrentState.TheaterHealth[theaterName].Health = CurrentState.TheaterHealth[theaterName].Health - score
      if CurrentState.TheaterHealth[theaterName].Health < 0 then
        CurrentState.TheaterHealth[theaterName].Health = 0
      end

      --Summarize kill
      local summaryKey = theaterName .. ": " .. sceneryType
      if (KillSummary[summaryKey] == nil) then
        KillSummary[summaryKey] = math.floor(((score / CurrentState.TheaterHealth[theaterName].MaxHealth) * 100) + .5)
      else
        KillSummary[summaryKey] = KillSummary[summaryKey] +
            math.floor(((score / CurrentState.TheaterHealth[theaterName].MaxHealth) * 100) + .5)
      end
    end
  elseif (Object.getCategory(event.target) == Object.Category.UNIT) then
    -- -- env.info("Unit Kill Event Handled")
    -- -- Not getting kill events for units?
  end
end

local function handleUnitLostEvent(event)
  -- env.info("Unit Lost Event Handled: ")
  if (event.initiator == nil) then
    return
  end
  if (Object.getCategory(event.initiator) == Object.Category.SCENERY) then
    local scenery = event.initiator
    -- env.info("Scenery Lost Event Handled")
  elseif (Object.getCategory(event.initiator) == Object.Category.UNIT) then
    local unit = event.initiator
    local name = unit:getName()
    local coalition = unit:getCoalition() --TODO - Validate that this is correct? Should always be but is it worth a check?
    local type = string.lower(unit:getTypeName())
    env.info("Unit Lost: " .. name .. " Type: " .. type)
    --Parse group name from unit name
    local unitName = string.lower(name)
    --TODO - Make this work for convoys as well.
    local score = TargetValuesJson[type]
    if not score then
      env.info("Score not found for: " .. type)
      --For units we will implementa default score value.
      score = 25
    end
    for zoneName, zone in pairs(MapZonesByTheaterName) do
      if starts_with(unitName, string.lower(zoneName)) or starts_with(unitName, string.lower("sam-blue-" .. zoneName)) or starts_with(unitName, string.lower("sam-red-" .. zoneName)) or starts_with(unitName, string.lower("hvt-blue-" .. zoneName)) or starts_with(unitName, string.lower("hvt-red-" .. zoneName)) or starts_with(unitName, string.lower("conv-" .. zoneName)) then
        if (starts_with(unitName, string.lower("conv-" .. zoneName))) then
          env.info("Unit hit on convoy from: " .. zoneName)
        else
          env.info("Unit hit in zone: " .. zoneName)
        end

        --This unit is associated with the selected zone.
        CurrentState.TheaterHealth[zoneName].Health = CurrentState.TheaterHealth[zoneName].Health - score
        if CurrentState.TheaterHealth[zoneName].Health < 0 then
          CurrentState.TheaterHealth[zoneName].Health = 0
          MESSAGE:New(zoneName .. " has reached 0% health.", 20):ToAll()
        end
        --Summarize kill
        local summaryKey = zoneName .. ": " .. type
        if (KillSummary[summaryKey] == nil) then
          KillSummary[summaryKey] = math.floor(((score / CurrentState.TheaterHealth[zoneName].MaxHealth) * 100) + .5)
        else
          KillSummary[summaryKey] = KillSummary[summaryKey] +
              math.floor(((score / CurrentState.TheaterHealth[zoneName].MaxHealth) * 100) + .5)
        end
        break
      end
    end
  end
end

local function HandleWorldEvents(event)
  env.info("Event Type: " .. event.id)
  --Player landed somewhere
  if event.id == world.event.S_EVENT_LAND then
    handleLandedEvent(event)
  end

  if event.id == world.event.S_EVENT_TAKEOFF then
    handleTakeoffEvent(event)
  end

  --Slot blocking and cargo handling from initial theater
  if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then --TODO Will multi-crew screw this up? Maybe key the cargo stuff by unit name first, and then player and only wipe the entry if no players are left.
    handlePlayerOccupySlot(event)
  end

  if event.id == world.event.S_EVENT_KILL then
    handleKillEvent(event)
  end

  if event.id == world.event.S_EVENT_UNIT_LOST then
    handleUnitLostEvent(event)
  end
end

mist.addEventHandler(HandleWorldEvents)

function DoBackgroundWork(ourArgument, time)
  --TODO drop the argument if we don't wind up using it.
  env.info("Background loop executed.")

  --Save state
  -- env.info(JSON:encode(CurrentState))
  write_file(StateFilePath, JSON:encode(CurrentState))
  --Display summary
  local stringOutput = "Damage Summary: \n" --TODO - Add mission timestamp
  local hasValue = false
  for key, score in pairs(KillSummary) do
    hasValue = true
    stringOutput = stringOutput .. "  " .. key .. ": " .. score .. "%\n"
  end
  if (hasValue) then
    MESSAGE:New(stringOutput, 20):ToAll()
    env.info(stringOutput)
  end

  KillSummary = {}
  return time + 30
end

timer.scheduleFunction(DoBackgroundWork, "", timer.getTime() + 30)

--#endregion

--#region Coalition Menus

local function showPageHealths(zonePage)
  local messageString = "Current Health:\n"

  for _, name in ipairs(zonePage) do
    messageString = messageString ..
        name ..
        ": " ..
        math.floor((CurrentState.TheaterHealth[name].Health / CurrentState.TheaterHealth[name].MaxHealth * 100) + .5) ..
        "%\n"
  end

  MESSAGE:New(messageString, 20):ToAll()
end

local function showAirAttackSchedule()
  local messageString = "Currently Planned Air Attacks:\n"
  local sortedPairs = sortTableByValue(AttackTime)
  for _, pair in ipairs(sortedPairs) do
    local theaterSource = pair.key
    local attackTime = pair.value
    local timeDelay = math.floor((attackTime - timer.getTime()) / 60)
    if timeDelay < 180 then --Only show attacks that are happening in the next 3 hours.
      if timeDelay > 0 then
        messageString = messageString ..
            " " ..
            theaterSource:sub(1, #theaterSource - 1) ..
            " is launching an air attack on " ..
            AttackSchedule[theaterSource] .. " in " .. timeDelay .. " minutes.\n"
      else
        messageString = messageString ..
            " " ..
            theaterSource:sub(1, #theaterSource - 1) ..
            " launched an air attack on " ..
            AttackSchedule[theaterSource] .. " " .. 0 - timeDelay .. " minutes ago.\n"
      end
    end
  end
  MESSAGE:New(messageString, 20):ToAll()
end

local function showGroundAttackSchedule()
  local messageString = "Currently Planned Ground Attacks:\n"
  local sortedPairs = sortTableByValue(GroundAttackTime)
  for _, pair in ipairs(sortedPairs) do
    local theaterSource = pair.key
    local attackTime = pair.value
    local timeDelay = math.floor((attackTime - timer.getTime()) / 60)
    if timeDelay > 0 then
      messageString = messageString ..
          " " ..
          theaterSource ..
          " is launching a ground attack on " ..
          GroundAttackSchedule[theaterSource] .. " in " .. timeDelay .. " minutes.\n"
    else
      messageString = messageString ..
          " " ..
          theaterSource ..
          " launched a ground attack on " ..
          GroundAttackSchedule[theaterSource] .. " " .. 0 - timeDelay .. " minutes ago.\n"
    end
  end
  MESSAGE:New(messageString, 20):ToAll()
end


intelMenu = MENU_COALITION:New(coalition.side.BLUE, "Intelligence")
MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Get Air Attacks Planned", intelMenu, showAirAttackSchedule)
MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Get Ground Attacks Planned", intelMenu, showGroundAttackSchedule)

for _, zonePage in ipairs(ZonesAlphabetized) do
  --Add a new menu item which will list each of the zones on a page.
  local firstZone, lastZone = firstAndLast(zonePage)
  MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Get Health for Zones " .. firstZone .. " to " .. lastZone, intelMenu,
    showPageHealths, zonePage)
end

local CapMenu = MENU_COALITION:New(coalition.side.BLUE, "Request CAP")
--Blue A2A Dispatcher
DetectionSetGroup = SET_GROUP:New()
DetectionSetGroup:FilterPrefixes({ "ewr-blue" })
DetectionSetGroup:FilterStart()
BlueDetection = DETECTION_AREAS:New(DetectionSetGroup, 30000)
BlueA2ADispatcher = AI_A2A_DISPATCHER:New(BlueDetection)

BlueA2ADispatcher:SetDefaultTakeoffInAir()
BlueA2ADispatcher:SetDefaultLandingAtRunway()
BlueA2ADispatcher:SetSquadron("cap-blue-1", AIRBASE.Sinai.Cairo_International_Airport, { "cap-blue" })

-- Add menu option to cancel a CAP flight. Uses the ResourceCount setting for the squadron to disable spawning. -999 was chosen because MOOSE uses this internally when airbases are captured.
local cancelCapMenu
local activeCap = 0

local function CancelCap(squadronName)
  local squadron = BlueA2ADispatcher:GetSquadron(squadronName)
  squadron.ResourceCount = -999
  cancelCapMenu:Remove()
  activeCap = activeCap - 1
  MESSAGE:New("Cap " .. squadronName .. " cancelled. No further flights will launch. Current flight will remain on station.", 10):ToBlue()
end

local function blueCap(squadron, zoneName)
  if activeCap > 0 then
    MESSAGE:New("CAP is already active. Cancel the current CAP flight before requesting a new one.", 10):ToBlue()
    return
  end
  local zone = ZONE:New(zoneName)
  BlueA2ADispatcher:SetSquadronCap(squadron, zone, 8000, 10000, 500, 600, 800, 900)
  BlueA2ADispatcher:SetSquadronCapRacetrack(squadron, 10000, 20000, 90, 180, 10 * 60, 20 * 60)
  BlueA2ADispatcher:SetSquadronCapInterval(squadron, 2, 30, 60, 1)
  BlueA2ADispatcher:SetSquadronFuelThreshold(squadron, 0.3)
  cancelCapMenu = MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Cancel CAP", CapMenu, CancelCap,
    squadron)
  activeCap = activeCap + 1
  MESSAGE:New("CAP requested over " .. zoneName .. ".", 10):ToBlue()
end

for _, zoneName in ipairs(BlueZonesAlphabetized) do
  MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Request CAP over " .. zoneName, CapMenu, blueCap, "cap-blue-1",
    zoneName)
end

--endregion

--#region Setup Skynet
DetectionSetGroup = SET_GROUP:New() --TODO - Is this needed anymore?
DetectionSetGroup:FilterPrefixes({ "ewr-red" })
DetectionSetGroup:FilterStart()
Detection = DETECTION_AREAS:New(DetectionSetGroup, 30000)

redIADS = SkynetIADS:create('iads-red')
blueIADS = SkynetIADS:create('iads-blue')

redIADS:addSAMSitesByPrefix('sam-red')
redIADS:addEarlyWarningRadarsByPrefix('ewr-red')
redIADS:activate()

blueIADS:addSAMSitesByPrefix('sam-blue')
blueIADS:addEarlyWarningRadarsByPrefix('ewr-blue')
blueIADS:activate()

if (debugMode == 1) then
  -- Add debug menus
  redIADS:addRadioMenu()
  blueIADS:addRadioMenu()

  local redIadsDebug = redIADS:getDebugSettings()
  redIadsDebug.samSiteStatusEnvOutput = true
  redIadsDebug.earlyWarningRadarStatusEnvOutput = true
  redIadsDebug.commandCenterStatusEnvOutput = true
  MESSAGE:New("Debug mode enabled.", 10):ToAll()
end
--#endregion
