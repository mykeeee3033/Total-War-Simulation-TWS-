/*
 * dynamicResupply.sqf
 * Dynamic Ground Resupply System
 * 
 * Features:
 * - Truck-based resupply missions to sectors
 * - Priority-based queueing system
 * - Driver spawning and waypoint system
 * - Resource delivery and driver despawn
 * - 5-minute execution cycle (configurable)
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_sectorAreas"};
    
    diag_log "[TWS] Initializing dynamic resupply system...";
    systemChat "[TWS] Initializing dynamic resupply system...";
    
    // Resupply configuration
    TWS_resupply = createHashMap;
    TWS_resupply set ["enabled", true];
    TWS_resupply set ["interval", 300]; // 5 minutes
    TWS_resupply set ["activeConvoys", []];
    TWS_resupply set ["baseMarker", "opfor_spawn"]; // Main base marker for OPFOR
    TWS_resupply set ["vehicleClass", "O_Truck_03_covered_F"]; // OPFOR truck
    TWS_resupply set ["driverClass", "O_Soldier_F"];
    TWS_resupply set ["resourcesPerDelivery", 50];
    
    // Function to spawn resupply truck
    TWS_fnc_spawnResupplyTruck = {
        params ["_faction", "_targetSectorID"];
        
        private _baseMarker = if (_faction == "OPFOR") then {
            TWS_resupply get "baseMarker"
        } else {
            "blufor_spawn" // Fallback for BLUFOR
        };
        
        private _spawnPos = getMarkerPos _baseMarker;
        
        // Get target sector data
        private _areas = TWS_sectorAreas get "areas";
        private _targetData = _areas getOrDefault [_targetSectorID, createHashMap];
        
        if (count _targetData == 0) exitWith {
            diag_log format ["[TWS] Cannot spawn resupply for unknown sector: %1", _targetSectorID];
            objNull
        };
        
        private _targetPos = _targetData get "position";
        
        // Spawn vehicle
        private _vehicleClass = if (_faction == "OPFOR") then {
            "O_Truck_03_covered_F"
        } else {
            "B_Truck_01_covered_F"
        };
        
        private _side = if (_faction == "OPFOR") then {east} else {west};
        private _vehicle = createVehicle [_vehicleClass, _spawnPos, [], 0, "NONE"];
        
        // Create driver group and unit
        private _driverGroup = createGroup _side;
        private _driverClass = if (_faction == "OPFOR") then {
            "O_Soldier_F"
        } else {
            "B_Soldier_F"
        };
        
        private _driver = _driverGroup createUnit [_driverClass, _spawnPos, [], 0, "NONE"];
        _driver moveInDriver _vehicle;
        
        // Set vehicle behavior
        _vehicle setFuel 1;
        _vehicle setVehicleAmmo 1;
        _driverGroup setBehaviour "SAFE";
        _driverGroup setSpeedMode "FULL";
        
        // Add waypoint to target sector
        private _wp1 = _driverGroup addWaypoint [_targetPos, 0];
        _wp1 setWaypointType "MOVE";
        _wp1 setWaypointSpeed "FULL";
        _wp1 setWaypointCompletionRadius 50;
        
        // Waypoint statement: deliver resources
        _wp1 setWaypointStatements ["true", format [
            "[%1, %2] call TWS_fnc_deliverResupply;",
            str _targetSectorID,
            TWS_resupply get "resourcesPerDelivery"
        ]];
        
        // Add waypoint to return to base
        private _wp2 = _driverGroup addWaypoint [_spawnPos, 0];
        _wp2 setWaypointType "MOVE";
        _wp2 setWaypointSpeed "FULL";
        _wp2 setWaypointCompletionRadius 50;
        
        // Waypoint statement: despawn driver
        _wp2 setWaypointStatements ["true", format [
            "deleteVehicle (driver (vehicle this)); systemChat '[TWS] Resupply driver returned to base';"
        ]];
        
        // Track active convoy
        private _convoys = TWS_resupply get "activeConvoys";
        _convoys pushBack [_vehicle, _driver, _targetSectorID, diag_tickTime];
        
        // Notify
        ["OPFOR", _targetPos, "ground convoy", ""] call TWS_fnc_notifyOrderExecution;
        [_targetPos, format ["Resupply convoy to %1", _targetSectorID], "ColorYellow", 300] call TWS_fnc_createEventMarker;
        
        diag_log format ["[TWS] Spawned resupply truck for %1 to sector %2", _faction, _targetSectorID];
        systemChat format ["[TWS] Resupply convoy dispatched to %1", _targetSectorID];
        
        _vehicle
    };
    
    // Function to deliver resupply
    TWS_fnc_deliverResupply = {
        params ["_sectorID", "_amount"];
        
        // Add resources to sector
        [_sectorID, _amount] call TWS_fnc_addSectorResources;
        
        // Spawn ammo crate at sector
        private _areas = TWS_sectorAreas get "areas";
        private _areaData = _areas getOrDefault [_sectorID, createHashMap];
        
        if (count _areaData > 0) then {
            private _position = _areaData get "position";
            private _crate = createVehicle ["Box_East_Ammo_F", _position, [], 5, "NONE"];
            
            // Add ammo to crate
            clearMagazineCargoGlobal _crate;
            clearWeaponCargoGlobal _crate;
            clearItemCargoGlobal _crate;
            
            _crate addMagazineCargoGlobal ["30Rnd_65x39_caseless_green", 50];
            _crate addMagazineCargoGlobal ["100Rnd_65x39_caseless_mag", 20];
            _crate addMagazineCargoGlobal ["RPG32_F", 10];
            _crate addMagazineCargoGlobal ["1Rnd_HE_Grenade_shell", 30];
            
            systemChat format ["[TWS] Resupply delivered to %1 (+%2 resources)", _sectorID, _amount];
        };
    };
    
    // Function to process resupply queue
    TWS_fnc_processResupplyQueue = {
        params ["_faction"];
        
        // Get sectors needing resupply
        private _needingResupply = [_faction] call TWS_fnc_getSectorsNeedingResupply;
        
        if (count _needingResupply == 0) exitWith {
            diag_log format ["[TWS] No sectors need resupply for %1", _faction];
        };
        
        // Take highest priority sector
        private _targetSector = _needingResupply select 0;
        
        // Spawn resupply truck
        [_faction, _targetSector] call TWS_fnc_spawnResupplyTruck;
        
        diag_log format ["[TWS] Processing resupply queue for %1 - target: %2", _faction, _targetSector];
    };
    
    // Function to clean up completed convoys
    TWS_fnc_cleanupConvoys = {
        private _convoys = TWS_resupply get "activeConvoys";
        private _newConvoys = [];
        
        {
            private _vehicle = _x select 0;
            private _driver = _x select 1;
            
            // Keep if vehicle and driver still exist and driver is in vehicle
            if (!isNull _vehicle && !isNull _driver && vehicle _driver == _vehicle) then {
                _newConvoys pushBack _x;
            };
        } forEach _convoys;
        
        TWS_resupply set ["activeConvoys", _newConvoys];
    };
    
    // Resupply loop
    TWS_fnc_resupplyLoop = {
        while {TWS_resupply get "enabled"} do {
            // Clean up completed convoys
            [] call TWS_fnc_cleanupConvoys;
            
            // Process OPFOR resupply
            ["OPFOR"] call TWS_fnc_processResupplyQueue;
            
            // Wait for next cycle
            sleep (TWS_resupply get "interval");
        };
    };
    
    // Function to toggle resupply system
    TWS_fnc_toggleResupply = {
        params ["_enable"];
        
        TWS_resupply set ["enabled", _enable];
        
        if (_enable) then {
            systemChat "[TWS] Dynamic resupply system enabled";
            [] spawn TWS_fnc_resupplyLoop;
        } else {
            systemChat "[TWS] Dynamic resupply system disabled";
        };
    };
    
    // Function to get active convoys
    TWS_fnc_getActiveConvoys = {
        TWS_resupply get "activeConvoys"
    };
    
    // Start resupply loop
    [] spawn TWS_fnc_resupplyLoop;
    
    // Make public
    publicVariable "TWS_resupply";
    publicVariable "TWS_fnc_spawnResupplyTruck";
    publicVariable "TWS_fnc_deliverResupply";
    publicVariable "TWS_fnc_processResupplyQueue";
    publicVariable "TWS_fnc_cleanupConvoys";
    publicVariable "TWS_fnc_toggleResupply";
    publicVariable "TWS_fnc_getActiveConvoys";
    
    systemChat "[TWS] Dynamic resupply system initialized";
    systemChat format ["[TWS] Resupply convoys will dispatch every %1 seconds", TWS_resupply get "interval"];
    diag_log "[TWS] Dynamic resupply system initialized";
};
