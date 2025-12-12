/*
 * dynamicReinforcements.sqf
 * Dynamic Reinforcement System
 * 
 * Features:
 * - Quick reaction to troops in contact
 * - Spawning from main base and FOBs
 * - Manpower resource checks
 * - Scaling based on threat level
 * - Integration with sector system
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_combat"};
    
    diag_log "[TWS] Initializing dynamic reinforcement system...";
    systemChat "[TWS] Initializing dynamic reinforcement system...";
    
    // Reinforcement configuration
    TWS_reinforcements = createHashMap;
    TWS_reinforcements set ["enabled", true];
    TWS_reinforcements set ["cooldown", 180]; // 3 minute cooldown between reinforcements
    TWS_reinforcements set ["lastReinforcement", 0];
    TWS_reinforcements set ["activeReinforcements", []];
    
    // Manpower costs
    TWS_reinforcements set ["light_cost", 10]; // 1 truck + squad
    TWS_reinforcements set ["medium_cost", 30]; // 2 APCs + squads
    TWS_reinforcements set ["heavy_cost", 80]; // Tanks, APCs, trucks, squads, heli
    
    // Function to check if faction has enough manpower
    TWS_fnc_hasEnoughManpower = {
        params ["_faction", "_cost"];
        
        if (isNil "TWS_fnc_getResources") exitWith {true}; // Bypass if resources not available
        
        private _resources = [_faction] call TWS_fnc_getResources;
        private _manpower = _resources getOrDefault ["manpower", 100];
        
        _manpower >= _cost
    };
    
    // Function to consume manpower
    TWS_fnc_consumeManpower = {
        params ["_faction", "_cost"];
        
        if (isNil "TWS_fnc_modifyResource") exitWith {};
        
        [_faction, "manpower", -_cost] call TWS_fnc_modifyResource;
        
        diag_log format ["[TWS] %1 consumed %2 manpower", _faction, _cost];
    };
    
    // Function to find nearest FOB with manpower
    TWS_fnc_findNearestFOB = {
        params ["_faction", "_targetPos"];
        
        // Get FOB sectors that have manpower
        if (isNil "TWS_sectorAreas") exitWith {[0,0,0]};
        
        private _areas = TWS_sectorAreas get "areas";
        private _nearestFOB = objNull;
        private _nearestDist = 999999;
        private _nearestPos = [0,0,0];
        
        {
            private _sectorData = _y;
            private _owner = _sectorData getOrDefault ["owner", "NONE"];
            private _resourcePoints = _sectorData getOrDefault ["resourcePoints", 0];
            private _pos = _sectorData get "position";
            
            if (_owner == _faction && _resourcePoints > 50) then {
                private _dist = _targetPos distance _pos;
                if (_dist < _nearestDist && _dist > 500) then { // At least 500m away
                    _nearestDist = _dist;
                    _nearestPos = _pos;
                };
            };
        } forEach _areas;
        
        _nearestPos
    };
    
    // Function to spawn light reinforcements
    TWS_fnc_spawnLightReinforcement = {
        params ["_faction", "_spawnPos", "_targetPos"];
        
        private _side = if (_faction == "OPFOR") then {east} else {west};
        
        // Spawn 1 truck with squad
        private _truckClass = if (_faction == "OPFOR") then {"O_Truck_03_covered_F"} else {"B_Truck_01_covered_F"};
        private _squadConfig = if (_faction == "OPFOR") then {
            (configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad")
        } else {
            (configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfSquad")
        };
        
        private _spawnTruck = [_spawnPos, 0, _truckClass, _side] call BIS_fnc_spawnVehicle;
        private _truck = _spawnTruck select 0;
        private _truckGroup = _spawnTruck select 2;
        
        // Spawn infantry
        private _infGroup = [_spawnPos, _side, _squadConfig] call BIS_fnc_spawnGroup;
        
        // Load infantry into truck
        {
            _x assignAsCargo _truck;
            _x moveInCargo _truck;
        } forEach (units _infGroup);
        
        // Add waypoints
        private _wp1 = _truckGroup addWaypoint [_targetPos, 0];
        _wp1 setWaypointType "MOVE";
        _wp1 setWaypointSpeed "FULL";
        
        private _wp2 = _truckGroup addWaypoint [_targetPos, 0];
        _wp2 setWaypointType "TR UNLOAD";
        
        private _wp3 = _infGroup addWaypoint [_targetPos, 0];
        _wp3 setWaypointType "GETOUT";
        
        [_truck, _truckGroup, _infGroup]
    };
    
    // Function to spawn medium reinforcements
    TWS_fnc_spawnMediumReinforcement = {
        params ["_faction", "_spawnPos", "_targetPos"];
        
        private _side = if (_faction == "OPFOR") then {east} else {west};
        
        private _vehicles = [];
        
        // Spawn 2 APCs with squads
        for "_i" from 0 to 1 do {
            private _offset = [(_i * 20), 0, 0];
            private _pos = _spawnPos vectorAdd _offset;
            
            private _apcClass = if (_faction == "OPFOR") then {"O_APC_Wheeled_02_rcws_v2_F"} else {"B_APC_Wheeled_01_cannon_F"};
            private _squadConfig = if (_faction == "OPFOR") then {
                (configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad")
            } else {
                (configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfSquad")
            };
            
            private _spawnAPC = [_pos, 0, _apcClass, _side] call BIS_fnc_spawnVehicle;
            private _apc = _spawnAPC select 0;
            private _apcGroup = _spawnAPC select 2;
            
            // Spawn infantry
            private _infGroup = [_pos, _side, _squadConfig] call BIS_fnc_spawnGroup;
            
            // Load infantry
            {
                _x assignAsCargo _apc;
                _x moveInCargo _apc;
            } forEach (units _infGroup);
            
            // Add waypoints
            private _wp1 = _apcGroup addWaypoint [_targetPos, 0];
            _wp1 setWaypointType "MOVE";
            _wp1 setWaypointSpeed "FULL";
            
            private _wp2 = _apcGroup addWaypoint [_targetPos, 0];
            _wp2 setWaypointType "TR UNLOAD";
            
            private _wp3 = _infGroup addWaypoint [_targetPos, 0];
            _wp3 setWaypointType "GETOUT";
            
            _vehicles pushBack [_apc, _apcGroup, _infGroup];
        };
        
        _vehicles
    };
    
    // Function to spawn heavy reinforcements
    TWS_fnc_spawnHeavyReinforcement = {
        params ["_faction", "_spawnPos", "_targetPos"];
        
        private _side = if (_faction == "OPFOR") then {east} else {west};
        private _vehicles = [];
        
        // Spawn mix of vehicles
        for "_i" from 0 to 1 do {
            private _offset = [(_i * 30), 0, 0];
            private _pos = _spawnPos vectorAdd _offset;
            
            // Truck with squad
            private _truckClass = if (_faction == "OPFOR") then {"O_Truck_03_covered_F"} else {"B_Truck_01_covered_F"};
            private _spawnTruck = [_pos, 0, _truckClass, _side] call BIS_fnc_spawnVehicle;
            private _truck = _spawnTruck select 0;
            private _truckGroup = _spawnTruck select 2;
            
            // Tank
            private _tankClass = if (_faction == "OPFOR") then {"O_MBT_04_cannon_F"} else {"B_MBT_01_cannon_F"};
            private _tankPos = _pos vectorAdd [15, 15, 0];
            private _spawnTank = [_tankPos, 0, _tankClass, _side] call BIS_fnc_spawnVehicle;
            private _tank = _spawnTank select 0;
            private _tankGroup = _spawnTank select 2;
            
            // APC with squad
            private _apcClass = if (_faction == "OPFOR") then {"O_APC_Wheeled_02_rcws_v2_F"} else {"B_APC_Wheeled_01_cannon_F"};
            private _apcPos = _pos vectorAdd [30, 0, 0];
            private _spawnAPC = [_apcPos, 0, _apcClass, _side] call BIS_fnc_spawnVehicle;
            private _apc = _spawnAPC select 0;
            private _apcGroup = _spawnAPC select 2;
            
            // Infantry groups
            private _squadConfig = if (_faction == "OPFOR") then {
                (configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad")
            } else {
                (configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfSquad")
            };
            
            private _infGroup1 = [_pos, _side, _squadConfig] call BIS_fnc_spawnGroup;
            private _infGroup2 = [_apcPos, _side, _squadConfig] call BIS_fnc_spawnGroup;
            
            // Load infantry
            {_x assignAsCargo _truck; _x moveInCargo _truck;} forEach (units _infGroup1);
            {_x assignAsCargo _apc; _x moveInCargo _apc;} forEach (units _infGroup2);
            
            // Add waypoints for all groups
            {
                private _vehGroup = _x;
                private _wp1 = _vehGroup addWaypoint [_targetPos, 0];
                _wp1 setWaypointType "MOVE";
                _wp1 setWaypointSpeed "FULL";
            } forEach [_truckGroup, _tankGroup, _apcGroup];
            
            _vehicles pushBack [_truck, _tank, _apc];
        };
        
        // Helicopter
        if (_faction == "OPFOR") then {
            private _heliPos = _spawnPos vectorAdd [50, 50, 30];
            private _spawnHeli = [_heliPos, 0, "O_Heli_Attack_02_dynamicLoadout_F", _side] call BIS_fnc_spawnVehicle;
            private _heli = _spawnHeli select 0;
            private _heliGroup = _spawnHeli select 2;
            
            private _wp1 = _heliGroup addWaypoint [_targetPos, 0];
            _wp1 setWaypointType "SAD";
            _wp1 setWaypointSpeed "FULL";
            
            _vehicles pushBack [_heli];
        };
        
        _vehicles
    };
    
    // Function to deploy reinforcements
    TWS_fnc_deployReinforcements = {
        params ["_faction", "_targetPos", "_level"];
        
        // Check cooldown
        private _lastTime = TWS_reinforcements get "lastReinforcement";
        private _cooldown = TWS_reinforcements get "cooldown";
        
        if ((diag_tickTime - _lastTime) < _cooldown) exitWith {
            diag_log format ["[TWS] Reinforcements on cooldown for %1", _faction];
        };
        
        // Determine manpower cost
        private _cost = switch (_level) do {
            case "light": {TWS_reinforcements get "light_cost"};
            case "medium": {TWS_reinforcements get "medium_cost"};
            case "heavy": {TWS_reinforcements get "heavy_cost"};
            default {10};
        };
        
        // Check manpower
        if (![_faction, _cost] call TWS_fnc_hasEnoughManpower) exitWith {
            diag_log format ["[TWS] %1 has insufficient manpower for %2 reinforcements", _faction, _level];
            systemChat format ["[TWS] %1 insufficient manpower for reinforcements", _faction];
        };
        
        // Find spawn point (try FOB first, then main base)
        private _spawnPos = [_faction, _targetPos] call TWS_fnc_findNearestFOB;
        
        if (_spawnPos isEqualTo [0,0,0]) then {
            // Use main base
            private _baseMarker = if (_faction == "OPFOR") then {"opfor_spawn"} else {"blufor_spawn"};
            _spawnPos = getMarkerPos _baseMarker;
        };
        
        // Consume manpower
        [_faction, _cost] call TWS_fnc_consumeManpower;
        
        // Spawn reinforcements
        private _units = switch (_level) do {
            case "light": {[_faction, _spawnPos, _targetPos] call TWS_fnc_spawnLightReinforcement};
            case "medium": {[_faction, _spawnPos, _targetPos] call TWS_fnc_spawnMediumReinforcement};
            case "heavy": {[_faction, _spawnPos, _targetPos] call TWS_fnc_spawnHeavyReinforcement};
            default {[]};
        };
        
        // Track reinforcement
        private _active = TWS_reinforcements get "activeReinforcements";
        _active pushBack [_faction, _level, _targetPos, diag_tickTime, _units];
        
        // Update last reinforcement time
        TWS_reinforcements set ["lastReinforcement", diag_tickTime];
        
        // Notify
        if (!isNil "TWS_fnc_notifyReinforcement") then {
            private _unitCount = switch (_level) do {
                case "light": {10};
                case "medium": {20};
                case "heavy": {50};
                default {10};
            };
            [_faction, _targetPos, _unitCount] call TWS_fnc_notifyReinforcement;
        };
        
        systemChat format ["[TWS] %1 %2 reinforcements deployed to combat zone", _faction, _level];
        diag_log format ["[TWS] Deployed %1 %2 reinforcements from %3 to %4", _faction, _level, _spawnPos, _targetPos];
    };
    
    // Make public
    publicVariable "TWS_reinforcements";
    publicVariable "TWS_fnc_hasEnoughManpower";
    publicVariable "TWS_fnc_consumeManpower";
    publicVariable "TWS_fnc_findNearestFOB";
    publicVariable "TWS_fnc_spawnLightReinforcement";
    publicVariable "TWS_fnc_spawnMediumReinforcement";
    publicVariable "TWS_fnc_spawnHeavyReinforcement";
    publicVariable "TWS_fnc_deployReinforcements";
    
    systemChat "[TWS] Dynamic reinforcement system initialized";
    diag_log "[TWS] Dynamic reinforcement system initialized";
};
