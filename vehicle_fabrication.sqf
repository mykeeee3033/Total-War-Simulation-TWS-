/*
 * Vehicle Fabrication System
 * 
 * Description: Spawns vehicles at OPFOR depot based on battlefield intelligence
 * Usage: [] execVM "vehicle_fabrication.sqf"
 * 
 * Features:
 * - Reads tactical intelligence from battlefield_intelligenceOPF.sqf
 * - Spawns appropriate counter-vehicles at nearest depot
 * - Finds depot closest to OPFOR flag
 * - Scales production based on threat assessment
 * 
 * Dependencies: battlefield_intelligenceOPF.sqf must be running
 */

if (!isServer) exitWith {
    diag_log "[FABRICATION] Vehicle fabrication only runs on server";
};

diag_log "[FABRICATION] Initializing vehicle fabrication system...";

// ============================================================================
// CONFIGURATION
// ============================================================================

// Vehicle classes for each counter-type
FAB_vehicleClasses = createHashMap;
FAB_vehicleClasses set ["tanks", ["O_MBT_04_cannon_F", "O_MBT_04_command_F"]];
FAB_vehicleClasses set ["apcs", ["O_APC_Wheeled_02_rcws_v2_F"]];
FAB_vehicleClasses set ["infantry_at", ["O_Truck_03_transport_F"]]; // Transport for AT teams
FAB_vehicleClasses set ["air_attack", ["O_Heli_Attack_02_dynamicLoadout_F", "O_Plane_CAS_02_dynamicLoadout_F"]];
FAB_vehicleClasses set ["air_aa", ["O_APC_Tracked_02_AA_F"]];
FAB_vehicleClasses set ["naval", ["O_Boat_Armed_01_hmg_F"]];

// Vehicle fabrication costs (fabrication resource points)
FAB_vehicleCosts = createHashMap;
FAB_vehicleCosts set ["O_MBT_04_cannon_F", 50];           // Main Battle Tank
FAB_vehicleCosts set ["O_MBT_04_command_F", 60];          // Command Tank
FAB_vehicleCosts set ["O_APC_Wheeled_02_rcws_v2_F", 35];  // APC
FAB_vehicleCosts set ["O_Truck_03_transport_F", 15];      // Transport Truck
FAB_vehicleCosts set ["O_Heli_Attack_02_dynamicLoadout_F", 80]; // Attack Helicopter
FAB_vehicleCosts set ["O_Plane_CAS_02_dynamicLoadout_F", 100]; // CAS Aircraft
FAB_vehicleCosts set ["O_APC_Tracked_02_AA_F", 45];       // AA APC
FAB_vehicleCosts set ["O_Boat_Armed_01_hmg_F", 25];       // Armed Boat

// Additional support vehicles
FAB_supportVehicles = ["O_MBT_02_arty_F", "O_Heli_Light_02_dynamicLoadout_F", "O_Plane_Fighter_02_F", "O_Plane_Fighter_02_Stealth_F", "O_Mortar_01_F"];

// Fabrication settings
FAB_settings = createHashMap;
FAB_settings set ["fabricationInterval", 1800]; // 30 minutes between production cycles
FAB_settings set ["maxVehiclesPerCycle", 3]; // Maximum vehicles to spawn per cycle
FAB_settings set ["minimumThreatLevel", 2]; // Minimum priority weight to trigger production
FAB_settings set ["depotClass", "Land_RepairDepot_01_tan_F"]; // Depot object class
FAB_settings set ["flagClass", "Flag_CSAT_F"]; // OPFOR flag class

// Fabrication status
FAB_status = createHashMap;
FAB_status set ["enabled", true];
FAB_status set ["lastFabricationTime", 0];
FAB_status set ["totalVehiclesProduced", 0];
FAB_status set ["currentDepot", objNull];

publicVariable "FAB_vehicleClasses";
publicVariable "FAB_vehicleCosts";
publicVariable "FAB_settings";
publicVariable "FAB_status";

// ============================================================================
// DEPOT AND FLAG FINDING FUNCTIONS
// ============================================================================

// Function: Find nearest OPFOR flag
FAB_fnc_findNearestFlag = {
    params [["_searchCenter", [0,0,0]]];
    
    private _flagClass = FAB_settings get "flagClass";
    private _allFlags = allMissionObjects _flagClass;
    
    if (count _allFlags == 0) exitWith {
        systemChat "[FABRICATION] No OPFOR flags found on map!";
        objNull
    };
    
    private _nearestFlag = objNull;
    private _nearestDistance = 999999;
    
    {
        private _distance = _searchCenter distance _x;
        if (_distance < _nearestDistance) then {
            _nearestDistance = _distance;
            _nearestFlag = _x;
        };
    } forEach _allFlags;
    
    systemChat format ["[FABRICATION] Found OPFOR flag at %1 (distance: %2m)", 
        mapGridPosition _nearestFlag, round _nearestDistance];
    
    _nearestFlag
};

// Function: Find depot closest to flag
FAB_fnc_findDepotNearFlag = {
    params ["_flag"];
    
    if (isNull _flag) exitWith {
        systemChat "[FABRICATION] Cannot find depot - no flag provided!";
        objNull
    };
    
    private _flagPosition = getPosATL _flag;
    private _depotClass = FAB_settings get "depotClass";
    private _allDepots = allMissionObjects _depotClass;
    
    if (count _allDepots == 0) exitWith {
        systemChat "[FABRICATION] No repair depots found on map!";
        objNull
    };
    
    private _nearestDepot = objNull;
    private _nearestDistance = 999999;
    
    {
        private _distance = _flagPosition distance _x;
        if (_distance < _nearestDistance) then {
            _nearestDistance = _distance;
            _nearestDepot = _x;
        };
    } forEach _allDepots;
    
    systemChat format ["[FABRICATION] Selected depot at %1 (distance from flag: %2m)", 
        mapGridPosition _nearestDepot, round _nearestDistance];
    
    _nearestDepot
};

// Function: Get safe spawn position near depot
FAB_fnc_getSafeSpawnPosition = {
    params ["_depot"];
    
    if (isNull _depot) exitWith {[0,0,0]};
    
    private _depotPos = getPosATL _depot;
    private _spawnPos = _depotPos;
    
    // Try to find a clear area near the depot
    for "_i" from 1 to 8 do {
        private _angle = _i * 45; // Every 45 degrees around depot
        private _distance = 15 + (_i * 3); // Increasing distance
        private _testPos = _depotPos getPos [_distance, _angle];
        
        // Check if position is clear
        if (count (_testPos nearObjects ["AllVehicles", 8]) == 0) exitWith {
            _spawnPos = _testPos;
        };
    };
    
    _spawnPos
};

// ============================================================================
// VEHICLE PRODUCTION FUNCTIONS
// ============================================================================

// Function: Get production recommendations from intelligence
FAB_fnc_getProductionRecommendations = {
    // Check if intelligence system is available
    if (isNil "BATTLE_opforDeaths") exitWith {
        systemChat "[FABRICATION] Intelligence system not available!";
        createHashMap
    };
    
    private _threats = BATTLE_opforDeaths get "threatAssessment";
    if (isNil "_threats") exitWith {
        systemChat "[FABRICATION] Threat assessment data not available!";
        createHashMap
    };
    
    private _spawns = _threats get "recommended_spawns";
    if (isNil "_spawns") exitWith {
        systemChat "[FABRICATION] Spawn recommendations not available!";
        createHashMap
    };
    
    _spawns
};

// Function: Select vehicle class based on category and weight
FAB_fnc_selectVehicleClass = {
    params ["_category", "_weight"];
    
    private _availableClasses = FAB_vehicleClasses getOrDefault [_category, []];
    if (count _availableClasses == 0) exitWith {"O_Truck_03_transport_F"}; // Fallback
    
    // Higher weight = better chance of getting more advanced vehicle
    private _classIndex = 0;
    if (_weight >= 7 && count _availableClasses > 1) then {
        _classIndex = (count _availableClasses) - 1; // Best vehicle
    } else {
        _classIndex = floor (random (count _availableClasses)); // Random from available
    };
    
    _availableClasses select _classIndex
};

// Function: Spawn vehicle at depot
FAB_fnc_spawnVehicle = {
    params ["_vehicleClass", "_depot"];
    
    // Check if resource system is available
    if (isNil "RES_factionResources") exitWith {
        systemChat "[FABRICATION] Resource system not available - cannot deduct fabrication costs!";
        objNull
    };
    
    // Get fabrication cost for this vehicle
    private _fabricationCost = FAB_vehicleCosts getOrDefault [_vehicleClass, 20]; // Default 20 points
    
    // Check if OPFOR has enough fabrication resources
    private _opforResources = ["OPFOR"] call RES_fnc_getResources;
    private _currentFabrication = _opforResources select 2; // Index 2 = Fabrication
    
    if (_currentFabrication < _fabricationCost) exitWith {
        systemChat format ["[FABRICATION] INSUFFICIENT RESOURCES: Need %1 fabrication points, have %2", 
            _fabricationCost, _currentFabrication];
        systemChat "[FABRICATION] Vehicle production cancelled due to insufficient fabrication resources";
        objNull
    };
    
    // Deduct fabrication cost
    ["OPFOR", 2, -_fabricationCost] call RES_fnc_modifyResource; // Index 2 = Fabrication
    
    private _spawnPos = [_depot] call FAB_fnc_getSafeSpawnPosition;
    private _spawnDir = random 360;
    
    private _vehicle = createVehicle [_vehicleClass, _spawnPos, [], 0, "CAN_COLLIDE"];
    _vehicle setDir _spawnDir;
    _vehicle setPosATL _spawnPos;
    
    // Set vehicle as OPFOR side
    createVehicleCrew _vehicle;
    _vehicle setVehicleLock "UNLOCKED";
    
    // Add to fabrication statistics
    private _totalProduced = FAB_status getOrDefault ["totalVehiclesProduced", 0];
    FAB_status set ["totalVehiclesProduced", _totalProduced + 1];
    
    systemChat format ["[FABRICATION] Produced %1 at depot (Cost: %2 fabrication, %3 total vehicles)", 
        getText (configFile >> "CfgVehicles" >> _vehicleClass >> "displayName"), 
        _fabricationCost, _totalProduced + 1];
    
    _vehicle
};

// Function: Execute production cycle
FAB_fnc_executeProductionCycle = {
    // Get current intelligence recommendations
    private _recommendations = [] call FAB_fnc_getProductionRecommendations;
    if (count _recommendations == 0) exitWith {
        systemChat "[FABRICATION] No production recommendations available";
    };
    
    // Ensure we have a valid depot
    private _currentDepot = FAB_status get "currentDepot";
    if (isNull _currentDepot) then {
        private _flag = [[0,0,0]] call FAB_fnc_findNearestFlag;
        _currentDepot = [_flag] call FAB_fnc_findDepotNearFlag;
        FAB_status set ["currentDepot", _currentDepot];
    };
    
    if (isNull _currentDepot) exitWith {
        systemChat "[FABRICATION] No valid depot available for production!";
    };
    
    // Calculate production queue based on priorities
    private _productionQueue = [];
    private _maxVehicles = FAB_settings get "maxVehiclesPerCycle";
    private _minThreat = FAB_settings get "minimumThreatLevel";
    
    systemChat "[FABRICATION] === PRODUCTION CYCLE STARTED ===";
    
    // Process each category by priority weight
    {
        private _category = _x;
        private _weight = _y;
        
        if (_weight >= _minThreat) then {
            // Calculate how many vehicles to produce (higher weight = more vehicles)
            private _vehiclesToProduce = switch (true) do {
                case (_weight >= 8): {2}; // High priority: 2 vehicles
                case (_weight >= 5): {1}; // Medium priority: 1 vehicle
                default {1}; // Low priority: 1 vehicle
            };
            
            // Add to production queue
            for "_i" from 1 to _vehiclesToProduce do {
                if (count _productionQueue < _maxVehicles) then {
                    _productionQueue pushBack [_category, _weight];
                };
            };
        };
    } forEach _recommendations;
    
    // Execute production
    if (count _productionQueue > 0) then {
        systemChat format ["[FABRICATION] Producing %1 vehicles based on threat analysis", count _productionQueue];
        
        {
            private _category = _x select 0;
            private _weight = _x select 1;
            
            private _vehicleClass = [_category, _weight] call FAB_fnc_selectVehicleClass;
            private _vehicle = [_vehicleClass, _currentDepot] call FAB_fnc_spawnVehicle;
            
            sleep 1; // Small delay between spawns
        } forEach _productionQueue;
        
        FAB_status set ["lastFabricationTime", time];
    } else {
        systemChat "[FABRICATION] No vehicles needed - threat levels below production threshold";
    };
    
    systemChat "[FABRICATION] === PRODUCTION CYCLE COMPLETE ===";
};

// ============================================================================
// MAIN FABRICATION LOOP
// ============================================================================

// Production cycle loop
FAB_fnc_fabricationLoop = {
    while {FAB_status get "enabled"} do {
        private _interval = FAB_settings get "fabricationInterval";
        
        systemChat format ["[FABRICATION] Next production cycle in %1 seconds...", _interval];
        sleep _interval;
        
        [] call FAB_fnc_executeProductionCycle;
    };
};

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

// Function: Get fabrication status
FAB_fnc_getStatus = {
    private _status = createHashMap;
    _status set ["enabled", FAB_status get "enabled"];
    _status set ["totalProduced", FAB_status get "totalVehiclesProduced"];
    _status set ["lastProduction", FAB_status get "lastFabricationTime"];
    _status set ["depot", FAB_status get "currentDepot"];
    
    _status
};

// Function: Toggle fabrication system
FAB_fnc_toggleFabrication = {
    params ["_enable"];
    
    FAB_status set ["enabled", _enable];
    
    if (_enable) then {
        systemChat "[FABRICATION] Vehicle fabrication system enabled";
        [] spawn FAB_fnc_fabricationLoop;
    } else {
        systemChat "[FABRICATION] Vehicle fabrication system disabled";
    };
};

// Function: Force production cycle (manual trigger)
FAB_fnc_forceProductionCycle = {
    systemChat "[FABRICATION] Forcing immediate production cycle...";
    [] call FAB_fnc_executeProductionCycle;
};

// ============================================================================
// PUBLIC FUNCTIONS
// ============================================================================

// Make functions globally accessible
publicVariable "FAB_fnc_findNearestFlag";
publicVariable "FAB_fnc_findDepotNearFlag";
publicVariable "FAB_fnc_getSafeSpawnPosition";
publicVariable "FAB_fnc_getProductionRecommendations";
publicVariable "FAB_fnc_selectVehicleClass";
publicVariable "FAB_fnc_spawnVehicle";
publicVariable "FAB_fnc_executeProductionCycle";
publicVariable "FAB_fnc_getStatus";
publicVariable "FAB_fnc_toggleFabrication";
publicVariable "FAB_fnc_forceProductionCycle";

// ============================================================================
// INITIALIZATION
// ============================================================================

// Wait for intelligence system to be available
systemChat "[FABRICATION] Waiting for intelligence system...";
waitUntil {!isNil "BATTLE_opforDeaths"};
systemChat "[FABRICATION] Intelligence system detected!";

// Wait for resource system to be available
systemChat "[FABRICATION] Waiting for resource system...";
waitUntil {!isNil "RES_factionResources"};
systemChat "[FABRICATION] Resource system detected!";

// Find initial depot location
systemChat "[FABRICATION] Locating production facility...";
private _initialFlag = [[0,0,0]] call FAB_fnc_findNearestFlag;
private _initialDepot = [_initialFlag] call FAB_fnc_findDepotNearFlag;
FAB_status set ["currentDepot", _initialDepot];

if (!isNull _initialDepot) then {
    systemChat "[FABRICATION] Production facility located and operational!";
    
    // Start fabrication loop
    [] spawn FAB_fnc_fabricationLoop;
    
    systemChat "[FABRICATION] === VEHICLE FABRICATION SYSTEM INITIALIZED ===";
    systemChat "[FABRICATION] Commands:";
    systemChat "[FABRICATION] [] call FAB_fnc_forceProductionCycle - Force immediate production";
    systemChat "[FABRICATION] [] call FAB_fnc_getStatus - Get system status";
    systemChat "[FABRICATION] [false] call FAB_fnc_toggleFabrication - Disable system";
    
} else {
    systemChat "[FABRICATION] ERROR: Could not locate production facility!";
    systemChat "[FABRICATION] Please ensure Flag_CSAT_F and Land_RepairDepot_01_tan_F are present on map";
};

diag_log "[FABRICATION] Vehicle fabrication system initialization complete";
