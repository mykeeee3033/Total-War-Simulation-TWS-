/*
 * enhancedProduction.sqf
 * Enhanced Production Queue with Combat Loss Tracking
 * 
 * Features:
 * - Tracks vehicle losses in combat
 * - Adds losses to production queue
 * - Weighted production based on needs
 * - Vehicle spawning at closest factory
 * - Driver spawning with waypoints to main base
 * - Driver despawn on arrival
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_productionQueues"};
    
    diag_log "[TWS] Initializing enhanced production system...";
    systemChat "[TWS] Initializing enhanced production system...";
    
    // Production tracking
    TWS_enhancedProduction = createHashMap;
    TWS_enhancedProduction set ["enabled", true];
    TWS_enhancedProduction set ["productionInterval", 600]; // 10 minutes
    
    // Vehicle loss tracking (since last production cycle)
    TWS_vehicleLosses = createHashMap;
    TWS_vehicleLosses set ["BLUFOR", createHashMap];
    TWS_vehicleLosses set ["OPFOR", createHashMap];
    
    {
        private _faction = _x;
        private _losses = TWS_vehicleLosses get _faction;
        _losses set ["transport", 0];
        _losses set ["apc", 0];
        _losses set ["armor", 0];
        _losses set ["aircraft", 0];
    } forEach ["BLUFOR", "OPFOR"];
    
    // Vehicle class mappings
    TWS_vehicleTypeMapping = createHashMap;
    TWS_vehicleTypeMapping set ["transport", ["Truck", "MRAP"]];
    TWS_vehicleTypeMapping set ["apc", ["APC", "IFV"]];
    TWS_vehicleTypeMapping set ["armor", ["Tank", "MBT"]];
    TWS_vehicleTypeMapping set ["aircraft", ["Helicopter", "Plane", "VTOL"]];
    
    // Function to classify vehicle
    TWS_fnc_classifyVehicle = {
        params ["_vehicle"];
        
        private _type = typeOf _vehicle;
        
        // Check each category
        {
            private _category = _x;
            private _keywords = _y;
            
            {
                if (_type find _x >= 0) exitWith {
                    _category
                };
            } forEach _keywords;
        } forEach TWS_vehicleTypeMapping;
        
        "transport" // Default
    };
    
    // Function to track vehicle loss
    TWS_fnc_trackVehicleLoss = {
        params ["_faction", "_vehicle"];
        
        if (isNull _vehicle) exitWith {};
        
        private _vehicleType = [_vehicle] call TWS_fnc_classifyVehicle;
        
        private _factionLosses = TWS_vehicleLosses getOrDefault [_faction, createHashMap];
        private _current = _factionLosses getOrDefault [_vehicleType, 0];
        _factionLosses set [_vehicleType, _current + 1];
        
        diag_log format ["[TWS] Tracked vehicle loss: %1 %2 (total: %3)", _faction, _vehicleType, _current + 1];
    };
    
    // Function to calculate production needs
    TWS_fnc_calculateProductionNeeds = {
        params ["_faction"];
        
        private _losses = TWS_vehicleLosses getOrDefault [_faction, createHashMap];
        private _needs = [];
        
        // Get losses for each type
        private _transportLost = _losses getOrDefault ["transport", 0];
        private _apcLost = _losses getOrDefault ["apc", 0];
        private _armorLost = _losses getOrDefault ["armor", 0];
        
        // Calculate weighted needs
        // APCs and armor are higher priority
        if (_armorLost > 2) then {
            private _count = ceil (_armorLost / 2);
            _needs pushBack ["armor", _count, 10]; // High priority
        };
        
        if (_apcLost > 3) then {
            private _count = ceil (_apcLost / 3);
            _needs pushBack ["apc", _count, 8]; // Medium-high priority
        };
        
        if (_transportLost > 5) then {
            private _count = ceil (_transportLost / 5);
            _needs pushBack ["transport", _count, 5]; // Medium priority
        };
        
        // Always produce some transports if we have losses
        if (_transportLost + _apcLost + _armorLost > 0 && count _needs == 0) then {
            _needs pushBack ["transport", 2, 3]; // Low priority fallback
        };
        
        _needs
    };
    
    // Function to queue production based on losses
    TWS_fnc_queueProductionFromLosses = {
        params ["_faction"];
        
        private _needs = [_faction] call TWS_fnc_calculateProductionNeeds;
        
        {
            private _vehicleType = _x select 0;
            private _count = _x select 1;
            private _priority = _x select 2;
            
            // Add to production queue
            if (!isNil "TWS_fnc_addToProductionQueue") then {
                [_faction, _vehicleType, _count, _priority] call TWS_fnc_addToProductionQueue;
                
                // Notify
                if (!isNil "TWS_fnc_notify") then {
                    ["production", format ["%1 queued production: %2x %3", _faction, _count, _vehicleType], [0,0,0], false] call TWS_fnc_notify;
                };
            };
        } forEach _needs;
        
        // Reset loss counters
        private _losses = TWS_vehicleLosses get _faction;
        _losses set ["transport", 0];
        _losses set ["apc", 0];
        _losses set ["armor", 0];
        _losses set ["aircraft", 0];
        
        if (count _needs > 0) then {
            diag_log format ["[TWS] Queued production for %1 based on losses: %2 items", _faction, count _needs];
        };
    };
    
    // Function to spawn produced vehicle with driver
    TWS_fnc_spawnProducedVehicle = {
        params ["_faction", "_factory", "_vehicleType"];
        
        private _side = if (_faction == "OPFOR") then {east} else {west};
        private _factoryPos = getPosASL _factory;
        
        // Get vehicle class
        private _vehicleClass = if (!isNil "TWS_fnc_getVehicleClass") then {
            [_faction, _vehicleType] call TWS_fnc_getVehicleClass
        } else {
            if (_faction == "OPFOR") then {"O_Truck_03_transport_F"} else {"B_Truck_01_transport_F"}
        };
        
        // Spawn vehicle with offset to avoid collision
        private _offset = [random 20 - 10, random 20 - 10, 0];
        private _spawnPos = _factoryPos vectorAdd _offset;
        
        private _vehicle = createVehicle [_vehicleClass, _spawnPos, [], 0, "NONE"];
        _vehicle setDir (random 360);
        
        // Create driver
        private _driverClass = if (_faction == "OPFOR") then {"O_Soldier_F"} else {"B_Soldier_F"};
        private _driverGroup = createGroup _side;
        private _driver = _driverGroup createUnit [_driverClass, _spawnPos, [], 0, "NONE"];
        _driver moveInDriver _vehicle;
        
        // Get main base position
        private _mainBase = if (!isNil "TWS_mainBases") then {
            TWS_mainBases getOrDefault [_faction, _factoryPos]
        } else {
            _factoryPos
        };
        
        // Add waypoint to main base
        private _wp1 = _driverGroup addWaypoint [_mainBase, 0];
        _wp1 setWaypointType "MOVE";
        _wp1 setWaypointSpeed "LIMITED";
        _wp1 setWaypointCompletionRadius 50;
        
        // On arrival: get out and despawn driver
        _wp1 setWaypointStatements ["true", "
            (driver (vehicle this)) leaveVehicle (vehicle this);
            sleep 2;
            deleteVehicle (driver (vehicle this));
        "];
        
        // Notify
        if (!isNil "TWS_fnc_notifyProduction") then {
            [_faction, _vehicleType, 1, _factoryPos] call TWS_fnc_notifyProduction;
        };
        
        diag_log format ["[TWS] Spawned produced vehicle: %1 %2 at factory", _faction, _vehicleType];
        
        _vehicle
    };
    
    // Enhanced production loop
    TWS_fnc_enhancedProductionLoop = {
        while {TWS_enhancedProduction get "enabled"} do {
            // Queue production based on losses
            ["OPFOR"] call TWS_fnc_queueProductionFromLosses;
            ["BLUFOR"] call TWS_fnc_queueProductionFromLosses;
            
            // Process production queue (if function exists)
            if (!isNil "TWS_fnc_processProductionQueue") then {
                ["OPFOR"] call TWS_fnc_processProductionQueue;
                ["BLUFOR"] call TWS_fnc_processProductionQueue;
            };
            
            sleep (TWS_enhancedProduction get "productionInterval");
        };
    };
    
    // Start production loop
    [] spawn TWS_fnc_enhancedProductionLoop;
    
    // Function to toggle enhanced production
    TWS_fnc_toggleEnhancedProduction = {
        params ["_enable"];
        
        TWS_enhancedProduction set ["enabled", _enable];
        
        if (_enable) then {
            systemChat "[TWS] Enhanced production system enabled";
            [] spawn TWS_fnc_enhancedProductionLoop;
        } else {
            systemChat "[TWS] Enhanced production system disabled";
        };
    };
    
    // Function to get vehicle losses
    TWS_fnc_getVehicleLosses = {
        params [["_faction", ""]];
        
        if (_faction == "") then {
            TWS_vehicleLosses
        } else {
            TWS_vehicleLosses getOrDefault [_faction, createHashMap]
        };
    };
    
    // Make public
    publicVariable "TWS_enhancedProduction";
    publicVariable "TWS_vehicleLosses";
    publicVariable "TWS_vehicleTypeMapping";
    publicVariable "TWS_fnc_classifyVehicle";
    publicVariable "TWS_fnc_trackVehicleLoss";
    publicVariable "TWS_fnc_calculateProductionNeeds";
    publicVariable "TWS_fnc_queueProductionFromLosses";
    publicVariable "TWS_fnc_spawnProducedVehicle";
    publicVariable "TWS_fnc_toggleEnhancedProduction";
    publicVariable "TWS_fnc_getVehicleLosses";
    
    systemChat "[TWS] Enhanced production system initialized";
    systemChat format ["[TWS] Production cycles every %1 seconds", TWS_enhancedProduction get "productionInterval"];
    diag_log "[TWS] Enhanced production system initialized with vehicle loss tracking";
};
