/*
 * objectRoles.sqf
 * Object Function Assignment System
 * 
 * Purpose: Assign economic and strategic roles to objects that ALiVE does not track.
 * These roles feed into the custom logistics and production systems.
 * 
 * Object Roles:
 * - Munitions Factory: Produces ammunition
 * - Fuel Refinery: Produces fuel
 * - Vehicle Plant: Fabricates vehicles
 * - Aircraft Plant: Produces/repairs aircraft
 * - Power Station: Affects production rates
 * - Radar Site: Air defense and detection
 * - HQ Node: Command and control
 * - Logistics Hub: Supply distribution
 */

if (isServer) then {
    // Wait for world state to be initialized
    waitUntil {!isNil "TWS_worldState"};
    
    // Object role definitions
    TWS_objectRoles = createHashMap;
    
    // Define role types and their production parameters
    TWS_roleDefinitions = createHashMap;
    TWS_roleDefinitions set ["munitionsFactory", createHashMap];
    TWS_roleDefinitions set ["fuelRefinery", createHashMap];
    TWS_roleDefinitions set ["vehiclePlant", createHashMap];
    TWS_roleDefinitions set ["aircraftPlant", createHashMap];
    TWS_roleDefinitions set ["powerStation", createHashMap];
    TWS_roleDefinitions set ["radarSite", createHashMap];
    TWS_roleDefinitions set ["hqNode", createHashMap];
    TWS_roleDefinitions set ["logisticsHub", createHashMap];
    
    // Production rates per hour (base values)
    private _munitionsFactory = TWS_roleDefinitions get "munitionsFactory";
    _munitionsFactory set ["productionRate", 100]; // 100 ammo units per hour
    _munitionsFactory set ["powerRequired", 50];
    _munitionsFactory set ["materialCost", 10];
    
    private _fuelRefinery = TWS_roleDefinitions get "fuelRefinery";
    _fuelRefinery set ["productionRate", 50]; // 50 fuel units per hour
    _fuelRefinery set ["powerRequired", 75];
    _fuelRefinery set ["materialCost", 5];
    
    private _vehiclePlant = TWS_roleDefinitions get "vehiclePlant";
    _vehiclePlant set ["productionRate", 2]; // 2 vehicles per hour
    _vehiclePlant set ["powerRequired", 100];
    _vehiclePlant set ["materialCost", 50];
    _vehiclePlant set ["fuelCost", 20];
    
    private _aircraftPlant = TWS_roleDefinitions get "aircraftPlant";
    _aircraftPlant set ["productionRate", 0.5]; // 0.5 aircraft per hour (1 every 2 hours)
    _aircraftPlant set ["powerRequired", 150];
    _aircraftPlant set ["materialCost", 100];
    _aircraftPlant set ["fuelCost", 50];
    
    private _powerStation = TWS_roleDefinitions get "powerStation";
    _powerStation set ["powerOutput", 500]; // Powers multiple factories
    
    // Function to assign a role to an object
    TWS_fnc_assignObjectRole = {
        params ["_object", "_role", "_faction"];
        
        if (isNull _object) exitWith {
            diag_log format ["[TWS] Cannot assign role to null object"];
        };
        
        private _roleData = createHashMap;
        _roleData set ["role", _role];
        _roleData set ["faction", _faction];
        _roleData set ["object", _object];
        _roleData set ["operational", true];
        _roleData set ["lastUpdate", diag_tickTime];
        
        TWS_objectRoles set [str _object, _roleData];
        
        // Register with appropriate system
        private _roleDef = TWS_roleDefinitions get _role;
        
        switch (_role) do {
            case "munitionsFactory": {
                [_object, _faction, "munitions", _roleDef get "productionRate"] call TWS_fnc_registerFactory;
            };
            case "fuelRefinery": {
                [_object, _faction, "fuel", _roleDef get "productionRate"] call TWS_fnc_registerFactory;
            };
            case "vehiclePlant": {
                [_object, _faction, "vehicles", _roleDef get "productionRate"] call TWS_fnc_registerFactory;
            };
            case "aircraftPlant": {
                [_object, _faction, "aircraft", _roleDef get "productionRate"] call TWS_fnc_registerFactory;
            };
            case "radarSite": {
                [_object, _faction, 10000] call TWS_fnc_registerRadar; // 10km range default
            };
            case "hqNode": {
                [_object, _faction] call TWS_fnc_registerCommandCenter;
            };
        };
        
        // Add damage monitoring
        _object addEventHandler ["Killed", {
            params ["_unit", "_killer", "_instigator", "_useEffects"];
            [_unit, false] call TWS_fnc_setObjectOperational;
        }];
        
        _object addEventHandler ["Dammaged", {
            params ["_unit", "_selection", "_damage", "_hitIndex", "_hitPoint", "_shooter", "_projectile"];
            if (damage _unit > 0.7) then {
                [_unit, false] call TWS_fnc_setObjectOperational;
            };
        }];
        
        diag_log format ["[TWS] Assigned role %1 to object %2 for faction %3", _role, _object, _faction];
    };
    
    // Function to set object operational status
    TWS_fnc_setObjectOperational = {
        params ["_object", "_operational"];
        
        private _roleData = TWS_objectRoles getOrDefault [str _object, createHashMap];
        if (count _roleData == 0) exitWith {
            diag_log format ["[TWS] Object %1 has no assigned role", _object];
        };
        
        _roleData set ["operational", _operational];
        _roleData set ["lastUpdate", diag_tickTime];
        
        // Update factory status if applicable
        private _role = _roleData get "role";
        if (_role in ["munitionsFactory", "fuelRefinery", "vehiclePlant", "aircraftPlant"]) then {
            private _factories = TWS_worldState get "factories";
            private _factoryData = _factories getOrDefault [str _object, createHashMap];
            if (count _factoryData > 0) then {
                _factoryData set ["operational", _operational];
                if (!_operational) then {
                    _factoryData set ["currentProductionRate", 0];
                    systemChat format ["[TWS] %1 has been destroyed!", _role];
                    diag_log format ["[TWS] Factory destroyed: %1", _object];
                };
            };
        };
        
        if (_role == "radarSite") then {
            private _radarSites = TWS_worldState get "radarSites";
            private _radarData = _radarSites getOrDefault [str _object, createHashMap];
            if (count _radarData > 0) then {
                _radarData set ["operational", _operational];
                if (!_operational) then {
                    systemChat format ["[TWS] Radar site destroyed!"];
                    diag_log format ["[TWS] Radar destroyed: %1", _object];
                };
            };
        };
        
        if (_role == "hqNode") then {
            private _commandCenters = TWS_worldState get "commandCenters";
            private _ccData = _commandCenters getOrDefault [str _object, createHashMap];
            if (count _ccData > 0) then {
                _ccData set ["operational", _operational];
                if (!_operational) then {
                    systemChat format ["[TWS] Command center destroyed!"];
                    diag_log format ["[TWS] Command center destroyed: %1", _object];
                };
            };
        };
    };
    
    // Function to get operational objects by role and faction
    TWS_fnc_getOperationalObjects = {
        params ["_role", "_faction"];
        
        private _result = [];
        {
            private _data = _y;
            if ((_data get "role") == _role && 
                (_data get "faction") == _faction && 
                (_data get "operational")) then {
                _result pushBack (_data get "object");
            };
        } forEach TWS_objectRoles;
        
        _result
    };
    
    // Function to auto-detect and assign roles based on object type
    TWS_fnc_autoAssignRoles = {
        // This function can be customized to automatically detect buildings
        // and assign roles based on their class names or positions
        
        // Example: Find all objects near specific markers and assign roles
        private _bluforFactoryMarkers = [];
        private _opforFactoryMarkers = [];
        
        // Scan for markers with specific naming conventions
        {
            private _markerName = _x;
            if (_markerName find "factory_blu" >= 0 || _markerName find "munitions_blu" >= 0) then {
                _bluforFactoryMarkers pushBack _markerName;
            };
            if (_markerName find "factory_opf" >= 0 || _markerName find "munitions_opf" >= 0) then {
                _opforFactoryMarkers pushBack _markerName;
            };
        } forEach allMapMarkers;
        
        // Assign roles to objects near factory markers
        {
            private _markerPos = getMarkerPos _x;
            private _nearObjects = nearestObjects [_markerPos, ["Building"], 100];
            if (count _nearObjects > 0) then {
                private _obj = _nearObjects select 0;
                [_obj, "munitionsFactory", "BLUFOR"] call TWS_fnc_assignObjectRole;
            };
        } forEach _bluforFactoryMarkers;
        
        {
            private _markerPos = getMarkerPos _x;
            private _nearObjects = nearestObjects [_markerPos, ["Building"], 100];
            if (count _nearObjects > 0) then {
                private _obj = _nearObjects select 0;
                [_obj, "munitionsFactory", "OPFOR"] call TWS_fnc_assignObjectRole;
            };
        } forEach _opforFactoryMarkers;
        
        diag_log format ["[TWS] Auto-assigned roles to %1 BLUFOR and %2 OPFOR factories", 
            count _bluforFactoryMarkers, count _opforFactoryMarkers];
    };
    
    publicVariable "TWS_objectRoles";
    publicVariable "TWS_roleDefinitions";
    publicVariable "TWS_fnc_assignObjectRole";
    publicVariable "TWS_fnc_setObjectOperational";
    publicVariable "TWS_fnc_getOperationalObjects";
    publicVariable "TWS_fnc_autoAssignRoles";
    
    diag_log "[TWS] Object Roles system initialized";
};
