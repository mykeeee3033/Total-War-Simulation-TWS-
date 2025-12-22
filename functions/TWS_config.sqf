/*
 * TWS_config.sqf
 * Configuration File for Object Role Assignment
 * 
 * Define all buildings, objects, and their roles here for easy management
 * This makes it simple to assign and track all strategic objects in the mission
 */

if (isServer) then {
    // Wait for core systems
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_objectRoles"};
    
    diag_log "[TWS] Loading configuration...";
    systemChat "[TWS] Loading configuration...";
    
    // ============================================================
    // OBJECT CLASS DEFINITIONS
    // ============================================================
    
    // Define what object classes map to what roles
    TWS_objectClassRoles = createHashMap;
    
    // Munitions Factories (Ammunition production)
    TWS_objectClassRoles set ["Land_Factory_Main_F", "munitionsFactory"];
    TWS_objectClassRoles set ["Land_i_Barracks_V1_F", "munitionsFactory"];
    TWS_objectClassRoles set ["Land_Cargo_House_V3_F", "munitionsFactory"];
    
    // Fuel Refineries (Fuel production)
    TWS_objectClassRoles set ["Land_dp_smallTank_F", "fuelRefinery"];
    TWS_objectClassRoles set ["Land_dp_bigTank_F", "fuelRefinery"];
    TWS_objectClassRoles set ["Land_FuelStation_Feed_F", "fuelRefinery"];
    TWS_objectClassRoles set ["Land_fs_feed_F", "fuelRefinery"];
    
    // Vehicle Plants (Vehicle fabrication)
    TWS_objectClassRoles set ["Land_CarService_F", "vehiclePlant"];
    TWS_objectClassRoles set ["Land_Ind_Workshop01_02_F", "vehiclePlant"];
    TWS_objectClassRoles set ["Land_Warehouse_03_F", "vehiclePlant"];
    
    // Aircraft Plants (Aircraft production/repair)
    TWS_objectClassRoles set ["Land_Hangar_F", "aircraftPlant"];
    TWS_objectClassRoles set ["Land_TentHangar_V1_F", "aircraftPlant"];
    
    // Power Stations (Electricity generation)
    TWS_objectClassRoles set ["Land_PowerStation_01_F", "powerStation"];
    TWS_objectClassRoles set ["Land_TTowerBig_1_F", "powerStation"];
    TWS_objectClassRoles set ["Land_TTowerBig_2_F", "powerStation"];
    TWS_objectClassRoles set ["Land_dp_transformer_F", "powerStation"];
    TWS_objectClassRoles set ["Land_Transformer_Station_F", "powerStation"];
    
    // Radar Sites (Air defense, detection, RND)
    TWS_objectClassRoles set ["Land_Radar_F", "radarSite"];
    TWS_objectClassRoles set ["Land_Radar_Small_F", "radarSite"];
    TWS_objectClassRoles set ["Land_Communication_F", "radarSite"];
    
    // HQ Nodes (Command centers)
    TWS_objectClassRoles set ["Land_Cargo_Tower_V1_F", "hqNode"];
    TWS_objectClassRoles set ["Land_Cargo_HQ_V1_F", "hqNode"];
    TWS_objectClassRoles set ["Land_MilOffices_V1_F", "hqNode"];
    
    // Logistics Hubs (Supply distribution)
    TWS_objectClassRoles set ["Land_Cargo_Patrol_V1_F", "logisticsHub"];
    TWS_objectClassRoles set ["Land_Medevac_house_V1_F", "logisticsHub"];
    
    // Communication Antennas (Communication grid)
    TWS_objectClassRoles set ["Land_TTowerSmall_1_F", "antenna"];
    TWS_objectClassRoles set ["Land_TTowerSmall_2_F", "antenna"];
    TWS_objectClassRoles set ["Land_Communication_anchor_F", "antenna"];
    
    // RND Buildings (Research & intelligence)
    TWS_objectClassRoles set ["Land_Research_house_V1_F", "rndBuilding"];
    TWS_objectClassRoles set ["Land_Research_HQ_F", "rndBuilding"];
    
    // Construction/Repair Buildings
    TWS_objectClassRoles set ["Land_Shed_Big_F", "constructionSite"];
    TWS_objectClassRoles set ["Land_i_Shed_Ind_F", "constructionSite"];
    
    // ============================================================
    // MANUAL OBJECT ASSIGNMENTS
    // ============================================================
    
    // BLUFOR Objects
    // Format: [objectVariable, role, faction]
    TWS_manualAssignments_BLUFOR = [
        // Example assignments - replace with actual object variable names from your mission
        // ["blufor_factory_1", "munitionsFactory", "BLUFOR"],
        // ["blufor_refinery_1", "fuelRefinery", "BLUFOR"],
        // ["blufor_hangar_1", "aircraftPlant", "BLUFOR"],
        // ["blufor_power_1", "powerStation", "BLUFOR"],
        // ["blufor_radar_1", "radarSite", "BLUFOR"],
        // ["blufor_hq_1", "hqNode", "BLUFOR"]
    ];
    
    // OPFOR Objects
    TWS_manualAssignments_OPFOR = [
        // Example assignments
        // ["opfor_factory_1", "munitionsFactory", "OPFOR"],
        // ["opfor_refinery_1", "fuelRefinery", "OPFOR"],
        // ["opfor_hangar_1", "aircraftPlant", "OPFOR"],
        // ["opfor_power_1", "powerStation", "OPFOR"],
        // ["opfor_radar_1", "radarSite", "OPFOR"],
        // ["opfor_hq_1", "hqNode", "OPFOR"]
    ];
    
    // ============================================================
    // MARKER-BASED AUTO-ASSIGNMENT
    // ============================================================
    
    // Define marker prefixes and their associated roles
    TWS_markerRoleMapping = createHashMap;
    TWS_markerRoleMapping set ["factory_blu", ["munitionsFactory", "BLUFOR"]];
    TWS_markerRoleMapping set ["factory_opf", ["munitionsFactory", "OPFOR"]];
    TWS_markerRoleMapping set ["refinery_blu", ["fuelRefinery", "BLUFOR"]];
    TWS_markerRoleMapping set ["refinery_opf", ["fuelRefinery", "OPFOR"]];
    TWS_markerRoleMapping set ["hangar_blu", ["aircraftPlant", "BLUFOR"]];
    TWS_markerRoleMapping set ["hangar_opf", ["aircraftPlant", "OPFOR"]];
    TWS_markerRoleMapping set ["power_blu", ["powerStation", "BLUFOR"]];
    TWS_markerRoleMapping set ["power_opf", ["powerStation", "OPFOR"]];
    TWS_markerRoleMapping set ["hq_blu", ["hqNode", "BLUFOR"]];
    TWS_markerRoleMapping set ["hq_opf", ["hqNode", "OPFOR"]];
    TWS_markerRoleMapping set ["antenna_blu", ["antenna", "BLUFOR"]];
    TWS_markerRoleMapping set ["antenna_opf", ["antenna", "OPFOR"]];
    
    // ============================================================
    // SECTOR CONFIGURATION
    // ============================================================
    
    // Sector weight modifiers
    TWS_sectorWeights = createHashMap;
    TWS_sectorWeights set ["baseProximityWeight", 2.0]; // Closer to main base = higher priority
    TWS_sectorWeights set ["clusterWeight", 1.5]; // Part of sector cluster = higher priority
    TWS_sectorWeights set ["frontlineWeight", 1.3]; // Frontline sectors
    TWS_sectorWeights set ["isolatedPenalty", 0.5]; // Standalone isolated sectors
    TWS_sectorWeights set ["underAttackMultiplier", 3.0]; // Sectors under attack
    
    // ============================================================
    // PRODUCTION QUEUE CONFIGURATION
    // ============================================================
    
    // Vehicle production weights based on combat analysis
    TWS_productionWeights = createHashMap;
    TWS_productionWeights set ["infantryDeaths", "transport"]; // Infantry dying → transports
    TWS_productionWeights set ["armorDeaths", "armor"]; // Armor dying → more armor
    TWS_productionWeights set ["aircraftLosses", "aircraft"]; // Aircraft lost → aircraft
    TWS_productionWeights set ["transportLosses", "transport"]; // Transports lost → transports
    
    // Production priority thresholds
    TWS_productionThresholds = createHashMap;
    TWS_productionThresholds set ["urgent", 20]; // 20+ losses = urgent production
    TWS_productionThresholds set ["high", 10]; // 10-19 losses = high priority
    TWS_productionThresholds set ["normal", 5]; // 5-9 losses = normal priority
    
    // ============================================================
    // REINFORCEMENT CONFIGURATION
    // ============================================================
    
    // Reinforcement weights (from user's specification)
    TWS_reinforcementWeights = [
        ["low", 0, 20, "transport"],      // 0-20 casualties = light transports
        ["medium", 21, 80, "apc"],        // 21-80 casualties = APCs + transports
        ["high", 81, 999, "armor"]        // 81+ casualties = armor + APCs
    ];
    
    // ============================================================
    // MORALE CONFIGURATION
    // ============================================================
    
    // Morale thresholds
    TWS_moraleThresholds = createHashMap;
    TWS_moraleThresholds set ["broken", 0.2];    // < 0.2 = broken, give up
    TWS_moraleThresholds set ["low", 0.4];       // 0.2-0.4 = low morale
    TWS_moraleThresholds set ["normal", 0.6];    // 0.4-0.6 = normal
    TWS_moraleThresholds set ["good", 0.8];      // 0.6-0.8 = good morale
    TWS_moraleThresholds set ["excellent", 1.0]; // 0.8-1.0 = excellent
    
    // Morale modifiers
    TWS_moraleModifiers = createHashMap;
    TWS_moraleModifiers set ["casualtyPercentage", -0.3];  // Heavy casualties decrease morale
    TWS_moraleModifiers set ["victoryBonus", 0.2];          // Victories increase morale
    TWS_moraleModifiers set ["trainingBonus", 0.1];         // Completed training increases morale
    TWS_moraleModifiers set ["supplyAbundant", 0.15];       // Good supplies increase morale
    TWS_moraleModifiers set ["supplyCritical", -0.25];      // Critical supplies decrease morale
    
    // ============================================================
    // RESOURCE CONFIGURATION
    // ============================================================
    
    // Extended resource types
    TWS_resourceTypes = [
        "ammunition",      // Basic ammo
        "fuel",            // Basic fuel
        "materials",       // Construction materials
        "vehicles",        // Ground vehicles
        "aircraft",        // Aircraft
        "manpower",        // Available soldiers
        "munitions",       // Advanced munitions (for armor, aircraft, turrets)
        "fabrications",    // Advanced fabrication materials
        "rnd",             // Research & development points
        "electricity",     // Power grid capacity
        "construction"     // Construction workers
    ];
    
    // ============================================================
    // COMMUNICATION GRID CONFIGURATION
    // ============================================================
    
    // Communication range for antennas
    TWS_communicationConfig = createHashMap;
    TWS_communicationConfig set ["antennaRange", 2000]; // 2km range per antenna
    TWS_communicationConfig set ["minAntennas", 1];     // Minimum for basic comms
    TWS_communicationConfig set ["optimalAntennas", 3]; // Optimal coverage
    TWS_communicationConfig set ["delayMultiplier", 2.0]; // Delay multiplier without coverage
    
    // ============================================================
    // FUNCTIONS
    // ============================================================
    
    // Function to apply manual assignments
    TWS_fnc_applyManualAssignments = {
        private _count = 0;
        
        // Apply BLUFOR assignments
        {
            private _objName = _x select 0;
            private _role = _x select 1;
            private _faction = _x select 2;
            
            private _obj = missionNamespace getVariable [_objName, objNull];
            if (!isNull _obj) then {
                [_obj, _role, _faction] call TWS_fnc_assignObjectRole;
                _count = _count + 1;
            } else {
                diag_log format ["[TWS] Warning: Object '%1' not found", _objName];
            };
        } forEach TWS_manualAssignments_BLUFOR;
        
        // Apply OPFOR assignments
        {
            private _objName = _x select 0;
            private _role = _x select 1;
            private _faction = _x select 2;
            
            private _obj = missionNamespace getVariable [_objName, objNull];
            if (!isNull _obj) then {
                [_obj, _role, _faction] call TWS_fnc_assignObjectRole;
                _count = _count + 1;
            } else {
                diag_log format ["[TWS] Warning: Object '%1' not found", _objName];
            };
        } forEach TWS_manualAssignments_OPFOR;
        
        diag_log format ["[TWS] Applied %1 manual object assignments", _count];
        _count
    };
    
    // Function to apply marker-based assignments
    TWS_fnc_applyMarkerAssignments = {
        private _count = 0;
        
        {
            private _prefix = _x;
            private _roleData = _y;
            private _role = _roleData select 0;
            private _faction = _roleData select 1;
            
            // Find all markers with this prefix
            private _markers = allMapMarkers select {toLower _x find _prefix >= 0};
            
            {
                private _markerPos = getMarkerPos _x;
                private _nearObjects = nearestObjects [_markerPos, ["Building", "House"], 100];
                
                if (count _nearObjects > 0) then {
                    private _obj = _nearObjects select 0;
                    [_obj, _role, _faction] call TWS_fnc_assignObjectRole;
                    _count = _count + 1;
                    diag_log format ["[TWS] Assigned %1 to building near marker %2", _role, _x];
                };
            } forEach _markers;
        } forEach TWS_markerRoleMapping;
        
        diag_log format ["[TWS] Applied %1 marker-based assignments", _count];
        _count
    };
    
    // Function to apply class-based auto-assignments
    TWS_fnc_applyClassAssignments = {
        params [["_radius", 10000], ["_center", [0,0,0]]];
        
        private _count = 0;
        private _processedObjects = [];
        
        {
            private _class = _x;
            private _role = _y;
            
            private _objects = nearestObjects [_center, [_class], _radius];
            
            {
                if (!(_x in _processedObjects)) then {
                    // Determine faction based on proximity to friendly sectors
                    // For now, use a simple approach - could be enhanced
                    private _faction = "BLUFOR"; // Default
                    
                    [_x, _role, _faction] call TWS_fnc_assignObjectRole;
                    _processedObjects pushBack _x;
                    _count = _count + 1;
                };
            } forEach _objects;
        } forEach TWS_objectClassRoles;
        
        diag_log format ["[TWS] Applied %1 class-based assignments", _count];
        _count
    };
    
    // Make everything public
    publicVariable "TWS_objectClassRoles";
    publicVariable "TWS_markerRoleMapping";
    publicVariable "TWS_sectorWeights";
    publicVariable "TWS_productionWeights";
    publicVariable "TWS_productionThresholds";
    publicVariable "TWS_reinforcementWeights";
    publicVariable "TWS_moraleThresholds";
    publicVariable "TWS_moraleModifiers";
    publicVariable "TWS_resourceTypes";
    publicVariable "TWS_communicationConfig";
    publicVariable "TWS_fnc_applyManualAssignments";
    publicVariable "TWS_fnc_applyMarkerAssignments";
    publicVariable "TWS_fnc_applyClassAssignments";
    
    diag_log "[TWS] Configuration loaded successfully";
    systemChat "[TWS] Configuration loaded";
};
