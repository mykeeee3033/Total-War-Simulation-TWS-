/*
 * productionQueue.sqf
 * Production Queue and Vehicle Spawning System
 * 
 * Features:
 * - Queue management based on combat analysis
 * - Vehicle spawning at factories
 * - Convoy formation and routing to main base
 * - Vehicle pool integration
 * - Priority-based production
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_intervals"};
    
    diag_log "[TWS] Initializing production queue system...";
    
    // Production queues
    TWS_productionQueues = createHashMap;
    TWS_productionQueues set ["BLUFOR", []];
    TWS_productionQueues set ["OPFOR", []];
    
    // Vehicle pools (available for deployment)
    TWS_vehiclePools = createHashMap;
    TWS_vehiclePools set ["BLUFOR", []];
    TWS_vehiclePools set ["OPFOR", []];
    
    // Combat analysis data
    TWS_combatAnalysis = createHashMap;
    TWS_combatAnalysis set ["BLUFOR", createHashMap];
    TWS_combatAnalysis set ["OPFOR", createHashMap];
    
    {
        private _faction = _x;
        private _analysis = TWS_combatAnalysis get _faction;
        _analysis set ["infantryDeaths", 0];
        _analysis set ["armorDeaths", 0];
        _analysis set ["aircraftLosses", 0];
        _analysis set ["transportLosses", 0];
    } forEach ["BLUFOR", "OPFOR"];
    
    // ============================================================
    // COMBAT ANALYSIS
    // ============================================================
    
    // Function to analyze casualties for production priorities
    TWS_fnc_analyzeCasualties = {
        params ["_faction"];
        
        private _analysis = TWS_combatAnalysis get _faction;
        
        // Get recent casualties (this would integrate with combat_monitor.sqf)
        // For now, using placeholder logic
        
        // Determine what to produce based on losses
        private _productionPriority = "transport"; // Default
        
        private _infantryDeaths = _analysis getOrDefault ["infantryDeaths", 0];
        private _armorDeaths = _analysis getOrDefault ["armorDeaths", 0];
        
        if (_armorDeaths > 5) then {
            _productionPriority = "armor";
        } else {
            if (_infantryDeaths > 20) then {
                _productionPriority = "transport";
            };
        };
        
        _productionPriority
    };
    
    // ============================================================
    // PRODUCTION QUEUE MANAGEMENT
    // ============================================================
    
    // Function to add item to production queue
    TWS_fnc_addToProductionQueue = {
        params ["_faction", "_vehicleType", "_count", "_priority"];
        
        private _queue = TWS_productionQueues get _faction;
        
        private _item = createHashMap;
        _item set ["type", _vehicleType];
        _item set ["count", _count];
        _item set ["priority", _priority];
        _item set ["timestamp", diag_tickTime];
        
        _queue pushBack _item;
        
        // Sort by priority (higher first)
        _queue sort {(_y get "priority") - (_x get "priority")};
        
        diag_log format ["[TWS] %1 added to production queue: %2x %3 (priority: %4)", 
            _faction, _count, _vehicleType, _priority];
    };
    
    // Function to process production queue
    TWS_fnc_processProductionQueue = {
        params ["_faction"];
        
        private _queue = TWS_productionQueues get _faction;
        if (count _queue == 0) exitWith {};
        
        // Get operational vehicle factories
        private _factories = ["vehiclePlant", _faction] call TWS_fnc_getOperationalObjects;
        if (count _factories == 0) exitWith {
            diag_log format ["[TWS] %1 has no operational vehicle factories", _faction];
        };
        
        // Find factory closest to main base
        private _mainBase = TWS_mainBases getOrDefault [_faction, [0,0,0]];
        private _closestFactory = objNull;
        private _closestDist = 999999;
        
        {
            private _dist = (getPosASL _x) distance _mainBase;
            if (_dist < _closestDist) then {
                _closestFactory = _x;
                _closestDist = _dist;
            };
        } forEach _factories;
        
        if (isNull _closestFactory) exitWith {};
        
        // Process highest priority item
        private _item = _queue select 0;
        private _vehicleType = _item get "type";
        private _count = _item get "count";
        
        // Check if we can produce (resources available)
        if ([_faction, _vehicleType] call TWS_fnc_canProduceVehicles) then {
            // Consume resources
            [_faction, _vehicleType, _count] call TWS_fnc_consumeVehicleProduction;
            
            // Spawn vehicles
            [_faction, _closestFactory, _vehicleType, _count] call TWS_fnc_spawnVehicleConvoy;
            
            // Remove from queue
            _queue deleteAt 0;
            
            systemChat format ["[TWS] %1 produced %2x %3", _faction, _count, _vehicleType];
        } else {
            diag_log format ["[TWS] %1 cannot produce %2 - insufficient resources", _faction, _vehicleType];
        };
    };
    
    // ============================================================
    // VEHICLE PRODUCTION
    // ============================================================
    
    // Function to check if vehicle production is possible
    TWS_fnc_canProduceVehicles = {
        params ["_faction", "_vehicleType"];
        
        private _resources = [_faction] call TWS_fnc_getResources;
        
        // Determine resource requirements based on vehicle type
        private _munitionsNeeded = 0;
        private _fabricationsNeeded = 0;
        private _fuelNeeded = 0;
        
        if (_vehicleType in ["armor", "tank"]) then {
            _munitionsNeeded = 50;
            _fabricationsNeeded = 100;
            _fuelNeeded = 30;
        } else {
            if (_vehicleType in ["transport", "apc"]) then {
                _munitionsNeeded = 20;
                _fabricationsNeeded = 50;
                _fuelNeeded = 20;
            };
        };
        
        private _canProduce = true;
        if ((_resources getOrDefault ["munitions", 0]) < _munitionsNeeded) then {_canProduce = false};
        if ((_resources getOrDefault ["fabrications", 0]) < _fabricationsNeeded) then {_canProduce = false};
        if ((_resources getOrDefault ["fuel", 0]) < _fuelNeeded) then {_canProduce = false};
        
        _canProduce
    };
    
    // Function to consume resources for vehicle production
    TWS_fnc_consumeVehicleProduction = {
        params ["_faction", "_vehicleType", "_count"];
        
        private _munitionsNeeded = 0;
        private _fabricationsNeeded = 0;
        private _fuelNeeded = 0;
        
        if (_vehicleType in ["armor", "tank"]) then {
            _munitionsNeeded = 50 * _count;
            _fabricationsNeeded = 100 * _count;
            _fuelNeeded = 30 * _count;
        } else {
            if (_vehicleType in ["transport", "apc"]) then {
                _munitionsNeeded = 20 * _count;
                _fabricationsNeeded = 50 * _count;
                _fuelNeeded = 20 * _count;
            };
        };
        
        [_faction, "munitions", -_munitionsNeeded] call TWS_fnc_modifyResource;
        [_faction, "fabrications", -_fabricationsNeeded] call TWS_fnc_modifyResource;
        [_faction, "fuel", -_fuelNeeded] call TWS_fnc_modifyResource;
        
        diag_log format ["[TWS] %1 consumed resources for %2x %3 production", _faction, _count, _vehicleType];
    };
    
    // ============================================================
    // VEHICLE SPAWNING AND CONVOY
    // ============================================================
    
    // Function to spawn vehicle convoy
    TWS_fnc_spawnVehicleConvoy = {
        params ["_faction", "_factory", "_vehicleType", "_count"];
        
        private _side = if (_faction == "BLUFOR") then {west} else {east};
        private _spawnPos = getPosASL _factory;
        private _mainBase = TWS_mainBases getOrDefault [_faction, _spawnPos];
        
        // Determine vehicle class
        private _vehicleClass = [_faction, _vehicleType] call TWS_fnc_getVehicleClass;
        
        private _vehicles = [];
        private _convoy = createGroup _side;
        
        // Spawn vehicles
        for "_i" from 1 to _count do {
            private _offset = [(_i * 10), 0, 0];
            private _vehPos = _spawnPos vectorAdd _offset;
            
            private _vehicle = createVehicle [_vehicleClass, _vehPos, [], 0, "NONE"];
            _vehicles pushBack _vehicle;
            
            // Create driver
            private _driverClass = if (_faction == "BLUFOR") then {"B_Soldier_F"} else {"O_Soldier_F"};
            private _driver = _convoy createUnit [_driverClass, _vehPos, [], 0, "NONE"];
            _driver moveInDriver _vehicle;
        };
        
        // Set convoy waypoint to main base
        private _wp1 = _convoy addWaypoint [_mainBase, 0];
        _wp1 setWaypointType "MOVE";
        _wp1 setWaypointSpeed "LIMITED";
        _wp1 setWaypointFormation "COLUMN";
        
        // On arrival, add vehicles to pool
        _wp1 setWaypointStatements ["true", format [
            "[%1, %2, %3] call TWS_fnc_addVehiclesToPool;",
            str _faction,
            str _vehicles,
            str _convoy
        ]];
        
        diag_log format ["[TWS] %1 spawned convoy of %2x %3 at %4", _faction, _count, _vehicleType, _factory];
        systemChat format ["[TWS] %1 convoy departing factory (%2 vehicles)", _faction, _count];
    };
    
    // Function to get vehicle class
    TWS_fnc_getVehicleClass = {
        params ["_faction", "_vehicleType"];
        
        private _class = "";
        
        if (_faction == "BLUFOR") then {
            switch (_vehicleType) do {
                case "transport": {_class = "B_Truck_01_transport_F"};
                case "apc": {_class = "B_APC_Wheeled_01_cannon_F"};
                case "armor": {_class = "B_MBT_01_cannon_F"};
                default {_class = "B_Truck_01_transport_F"};
            };
        } else {
            switch (_vehicleType) do {
                case "transport": {_class = "O_Truck_03_transport_F"};
                case "apc": {_class = "O_APC_Wheeled_02_rcws_v2_F"};
                case "armor": {_class = "O_MBT_02_cannon_F"};
                default {_class = "O_Truck_03_transport_F"};
            };
        };
        
        _class
    };
    
    // Function to add vehicles to pool
    TWS_fnc_addVehiclesToPool = {
        params ["_faction", "_vehicles", "_convoy"];
        
        // Delete crew
        {deleteVehicle _x} forEach (units _convoy);
        deleteGroup _convoy;
        
        // Add vehicles to pool
        private _pool = TWS_vehiclePools get _faction;
        {
            _pool pushBack _x;
        } forEach _vehicles;
        
        diag_log format ["[TWS] %1 added %2 vehicles to pool (total: %3)", 
            _faction, count _vehicles, count _pool];
        systemChat format ["[TWS] %1 vehicles delivered to base (%2 total available)", 
            count _vehicles, count _pool];
    };
    
    // ============================================================
    // AUTO-PRODUCTION SYSTEM
    // ============================================================
    
    // Function to auto-queue production based on combat
    TWS_fnc_autoQueueProduction = {
        params ["_faction"];
        
        // Analyze what we need
        private _priority = [_faction] call TWS_fnc_analyzeCasualties;
        
        // Determine count based on priority
        private _count = 2; // Default
        
        private _analysis = TWS_combatAnalysis get _faction;
        private _infantryDeaths = _analysis getOrDefault ["infantryDeaths", 0];
        private _armorDeaths = _analysis getOrDefault ["armorDeaths", 0];
        
        if (_infantryDeaths > 20 || _armorDeaths > 5) then {
            _count = 3; // Urgent
        };
        
        // Add to queue
        [_faction, _priority, _count, 5] call TWS_fnc_addToProductionQueue;
    };
    
    // ============================================================
    // UPDATE LOOPS
    // ============================================================
    
    // Production queue processing loop
    TWS_fnc_productionQueueLoop = {
        while {true} do {
            {
                private _faction = _x;
                
                // Auto-queue if needed
                [_faction] call TWS_fnc_autoQueueProduction;
                
                // Process queue
                [_faction] call TWS_fnc_processProductionQueue;
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep (["ProductionQueueInterval"] call TWS_fnc_getInterval);
        };
    };
    
    // Start production queue loop
    [] spawn TWS_fnc_productionQueueLoop;
    
    // Make public
    publicVariable "TWS_productionQueues";
    publicVariable "TWS_vehiclePools";
    publicVariable "TWS_combatAnalysis";
    publicVariable "TWS_fnc_analyzeCasualties";
    publicVariable "TWS_fnc_addToProductionQueue";
    publicVariable "TWS_fnc_processProductionQueue";
    publicVariable "TWS_fnc_canProduceVehicles";
    publicVariable "TWS_fnc_consumeVehicleProduction";
    publicVariable "TWS_fnc_spawnVehicleConvoy";
    publicVariable "TWS_fnc_getVehicleClass";
    publicVariable "TWS_fnc_addVehiclesToPool";
    publicVariable "TWS_fnc_autoQueueProduction";
    
    systemChat "[TWS] Production Queue system initialized";
    diag_log "[TWS] Production Queue and Vehicle Spawning system initialized";
};
