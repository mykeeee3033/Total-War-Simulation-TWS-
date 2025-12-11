/*
 * TWS_config_example.sqf
 * Configuration Examples for Total War Simulation System
 * 
 * Copy this file and customize it for your mission
 * Execute after TWS initialization: [] execVM "TWS_config_example.sqf";
 */

// Wait for TWS to initialize
waitUntil {!isNil "TWS_initialized"};

if (isServer) then {
    systemChat "[TWS] Loading custom configuration...";
    
    // ================================================================
    // EXAMPLE 1: Manual Object Role Assignment
    // ================================================================
    
    // Assign specific buildings/objects to roles
    // Replace 'objectName' with actual object variable names from your mission
    
    /*
    // BLUFOR installations
    [blufor_munitions_plant, "munitionsFactory", "BLUFOR"] call TWS_fnc_assignObjectRole;
    [blufor_fuel_depot, "fuelRefinery", "BLUFOR"] call TWS_fnc_assignObjectRole;
    [blufor_vehicle_factory, "vehiclePlant", "BLUFOR"] call TWS_fnc_assignObjectRole;
    [blufor_airfield_hangar, "aircraftPlant", "BLUFOR"] call TWS_fnc_assignObjectRole;
    [blufor_power_plant, "powerStation", "BLUFOR"] call TWS_fnc_assignObjectRole;
    
    // OPFOR installations
    [opfor_munitions_plant, "munitionsFactory", "OPFOR"] call TWS_fnc_assignObjectRole;
    [opfor_fuel_depot, "fuelRefinery", "OPFOR"] call TWS_fnc_assignObjectRole;
    [opfor_vehicle_factory, "vehiclePlant", "OPFOR"] call TWS_fnc_assignObjectRole;
    [opfor_airfield_hangar, "aircraftPlant", "OPFOR"] call TWS_fnc_assignObjectRole;
    [opfor_power_plant, "powerStation", "OPFOR"] call TWS_fnc_assignObjectRole;
    */
    
    // ================================================================
    // EXAMPLE 2: Set Initial Resources
    // ================================================================
    
    // Adjust starting resources for each faction
    ["BLUFOR", "ammunition", 5000] call TWS_fnc_modifyResource;
    ["BLUFOR", "fuel", 3000] call TWS_fnc_modifyResource;
    ["BLUFOR", "vehicles", 20] call TWS_fnc_modifyResource;
    
    ["OPFOR", "ammunition", 8000] call TWS_fnc_modifyResource;
    ["OPFOR", "fuel", 4000] call TWS_fnc_modifyResource;
    ["OPFOR", "vehicles", 30] call TWS_fnc_modifyResource;
    
    // ================================================================
    // EXAMPLE 3: Set Initial Commander Personalities
    // ================================================================
    
    // Make BLUFOR cautious and OPFOR aggressive
    ["BLUFOR", "cautious"] call TWS_fnc_setCommanderPersonality;
    ["OPFOR", "aggressive"] call TWS_fnc_setCommanderPersonality;
    
    // ================================================================
    // EXAMPLE 4: Adjust Production Rates
    // ================================================================
    
    // Increase munitions production rate
    private _munitionsFactory = TWS_roleDefinitions get "munitionsFactory";
    _munitionsFactory set ["productionRate", 200]; // Double production
    
    // Decrease fuel production rate
    private _fuelRefinery = TWS_roleDefinitions get "fuelRefinery";
    _fuelRefinery set ["productionRate", 25]; // Half production
    
    // ================================================================
    // EXAMPLE 5: Adjust Resource Thresholds
    // ================================================================
    
    // Make the factions more sensitive to resource shortages
    TWS_resourceThresholds set ["critical", 1000]; // Raised from 500
    TWS_resourceThresholds set ["low", 3000]; // Raised from 2000
    
    // ================================================================
    // EXAMPLE 6: Enable Optional Systems
    // ================================================================
    
    // Enable geopolitical events for more dynamic gameplay
    // [true] call TWS_fnc_toggleGeopolitics;
    
    // Enable civilian economy simulation
    // [true] call TWS_fnc_toggleCivilianEconomy;
    
    // ================================================================
    // EXAMPLE 7: Adjust Timing Intervals
    // ================================================================
    
    // Faster production cycles (3 minutes instead of 5)
    // TWS_logisticsConfig set ["productionInterval", 180];
    
    // More frequent strategic reports (15 minutes instead of 30)
    // TWS_chatGPTConfig set ["reportInterval", 900];
    
    // ================================================================
    // EXAMPLE 8: Register OPCOM Objects (if using ALiVE)
    // ================================================================
    
    /*
    // If you have ALiVE OPCOM modules, register them
    ["BLUFOR", opcom_blufor] call TWS_fnc_registerOPCOM;
    ["OPFOR", opcom_opfor] call TWS_fnc_registerOPCOM;
    */
    
    // ================================================================
    // EXAMPLE 9: Adjust Air Defense Settings
    // ================================================================
    
    // Reduce fuel cost per scramble
    TWS_radarDefenseConfig set ["fuelCostPerScramble", 10]; // Reduced from 20
    
    // Lower minimum tempo for scrambles (more permissive)
    TWS_radarDefenseConfig set ["minTempo", 0.3]; // Reduced from 0.4
    
    // ================================================================
    // EXAMPLE 10: Create Custom Event Handlers
    // ================================================================
    
    // Monitor when resources get critically low
    [] spawn {
        while {true} do {
            {
                private _faction = _x;
                private _resources = [_faction] call TWS_fnc_getResources;
                private _ammo = _resources getOrDefault ["ammunition", 0];
                private _fuel = _resources getOrDefault ["fuel", 0];
                
                if (_ammo < 1000 || _fuel < 1000) then {
                    systemChat format ["[TWS] WARNING: %1 resources critical! Ammo: %2, Fuel: %3",
                        _faction, _ammo, _fuel];
                };
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep 300; // Check every 5 minutes
        };
    };
    
    // ================================================================
    // EXAMPLE 11: Marker-Based Auto-Assignment
    // ================================================================
    
    // Automatically assign roles to buildings near specific markers
    private _assignNearMarker = {
        params ["_markerName", "_role", "_faction", "_radius"];
        
        private _pos = getMarkerPos _markerName;
        private _buildings = nearestObjects [_pos, ["Building", "House"], _radius];
        
        if (count _buildings > 0) then {
            private _building = _buildings select 0;
            [_building, _role, _faction] call TWS_fnc_assignObjectRole;
            systemChat format ["[TWS] Assigned %1 to building near %2", _role, _markerName];
        };
    };
    
    // Example usage:
    // ["marker_blufor_factory", "munitionsFactory", "BLUFOR", 100] call _assignNearMarker;
    // ["marker_opfor_refinery", "fuelRefinery", "OPFOR", 100] call _assignNearMarker;
    
    // ================================================================
    
    systemChat "[TWS] Custom configuration loaded!";
    diag_log "[TWS] Custom configuration applied";
};
