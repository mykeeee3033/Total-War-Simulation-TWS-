/*
 * extendedResources.sqf
 * Extended Resource Management System
 * 
 * Adds additional resource types:
 * - Manpower (available soldiers)
 * - Munitions (advanced ammunition for armor/aircraft)
 * - Fabrications (advanced materials)
 * - RND (research & development points)
 * - Electricity (power grid capacity)
 * - Construction (construction workers)
 */

if (isServer) then {
    // Wait for core systems
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_intervals"};
    
    diag_log "[TWS] Initializing extended resource system...";
    
    // Initialize extended resources for each faction
    {
        private _faction = _x;
        private _resources = [_faction] call TWS_fnc_getResources;
        
        // Add extended resource types if not already present
        if (isNil {_resources get "manpower"}) then {
            _resources set ["manpower", 100]; // 100 soldiers available
        };
        if (isNil {_resources get "munitions"}) then {
            _resources set ["munitions", 500]; // Advanced munitions
        };
        if (isNil {_resources get "fabrications"}) then {
            _resources set ["fabrications", 300]; // Advanced materials
        };
        if (isNil {_resources get "rnd"}) then {
            _resources set ["rnd", 0]; // Research points
        };
        if (isNil {_resources get "electricity"}) then {
            _resources set ["electricity", 1000]; // Power capacity
        };
        if (isNil {_resources get "construction"}) then {
            _resources set ["construction", 20]; // Construction workers
        };
    } forEach ["BLUFOR", "OPFOR"];
    
    // ============================================================
    // MANPOWER SYSTEM
    // ============================================================
    
    // Manpower configuration
    TWS_manpowerConfig = createHashMap;
    TWS_manpowerConfig set ["maxManpower", 500];
    TWS_manpowerConfig set ["minManpower", 0];
    TWS_manpowerConfig set ["casualtyToManpowerRatio", 0.7]; // 70% casualties reduce manpower
    TWS_manpowerConfig set ["resupplyManpowerAmount", 30]; // Manpower gained per resupply
    TWS_manpowerConfig set ["trainingManpowerCost", 10]; // Cost to train units
    TWS_manpowerConfig set ["trainingManpowerGain", 5]; // Manpower gained after training
    
    // Function to deduct manpower (when spawning troops)
    TWS_fnc_deductManpower = {
        params ["_faction", "_amount"];
        
        private _success = [_faction, "manpower", _amount] call TWS_fnc_consumeResource;
        if (_success) then {
            diag_log format ["[TWS] %1 deployed %2 manpower", _faction, _amount];
        } else {
            diag_log format ["[TWS] %1 insufficient manpower to deploy %2 units", _faction, _amount];
        };
        _success
    };
    
    // Function to add manpower (from resupply or training)
    TWS_fnc_addManpower = {
        params ["_faction", "_amount", ["_source", "resupply"]];
        
        [_faction, "manpower", _amount] call TWS_fnc_modifyResource;
        
        private _resources = [_faction] call TWS_fnc_getResources;
        private _current = _resources get "manpower";
        private _max = TWS_manpowerConfig get "maxManpower";
        
        if (_current > _max) then {
            _resources set ["manpower", _max];
        };
        
        diag_log format ["[TWS] %1 gained %2 manpower from %3", _faction, _amount, _source];
        systemChat format ["[TWS] %1 +%2 manpower (%3)", _faction, _amount, _source];
    };
    
    // Function to handle casualty impact on manpower
    TWS_fnc_processCasualties = {
        params ["_faction", "_casualties"];
        
        private _manpowerLoss = floor (_casualties * (TWS_manpowerConfig get "casualtyToManpowerRatio"));
        
        if (_manpowerLoss > 0) then {
            [_faction, "manpower", -_manpowerLoss] call TWS_fnc_modifyResource;
            diag_log format ["[TWS] %1 lost %2 manpower from %3 casualties", _faction, _manpowerLoss, _casualties];
        };
    };
    
    // ============================================================
    // MUNITIONS & FABRICATIONS SYSTEM
    // ============================================================
    
    // Advanced production requirements
    TWS_advancedProduction = createHashMap;
    TWS_advancedProduction set ["armor", createHashMap];
    TWS_advancedProduction set ["aircraft", createHashMap];
    TWS_advancedProduction set ["turret", createHashMap];
    
    // Armor production costs
    private _armorCost = TWS_advancedProduction get "armor";
    _armorCost set ["munitions", 50];
    _armorCost set ["fabrications", 100];
    _armorCost set ["fuel", 30];
    
    // Aircraft production costs
    private _aircraftCost = TWS_advancedProduction get "aircraft";
    _aircraftCost set ["munitions", 100];
    _aircraftCost set ["fabrications", 150];
    _aircraftCost set ["fuel", 50];
    
    // Turret/defensive production costs
    private _turretCost = TWS_advancedProduction get "turret";
    _turretCost set ["munitions", 30];
    _turretCost set ["fabrications", 20];
    
    // Function to check if advanced production is possible
    TWS_fnc_canProduceAdvanced = {
        params ["_faction", "_type"];
        
        private _costs = TWS_advancedProduction get _type;
        if (isNil "_costs") exitWith {false};
        
        private _resources = [_faction] call TWS_fnc_getResources;
        private _canProduce = true;
        
        {
            private _resourceType = _x;
            private _required = _y;
            private _available = _resources getOrDefault [_resourceType, 0];
            
            if (_available < _required) then {
                _canProduce = false;
            };
        } forEach _costs;
        
        _canProduce
    };
    
    // Function to consume resources for advanced production
    TWS_fnc_consumeAdvancedProduction = {
        params ["_faction", "_type"];
        
        private _costs = TWS_advancedProduction get _type;
        if (isNil "_costs") exitWith {false};
        
        private _success = true;
        {
            private _resourceType = _x;
            private _required = _y;
            
            if (![_faction, _resourceType, _required] call TWS_fnc_consumeResource) then {
                _success = false;
            };
        } forEach _costs;
        
        if (_success) then {
            diag_log format ["[TWS] %1 consumed resources for %2 production", _faction, _type];
        };
        
        _success
    };
    
    // ============================================================
    // RND SYSTEM (Research & Development)
    // ============================================================
    
    // RND configuration
    TWS_rndConfig = createHashMap;
    TWS_rndConfig set ["pointsPerTick", 10]; // RND points gained per tick
    TWS_rndConfig set ["radarRange", 5000]; // Range for radar detection
    TWS_rndConfig set ["intelTypes", ["armor", "troops", "turrets", "antennas", "production"]];
    
    // Function to process RND tick
    TWS_fnc_processRNDTick = {
        params ["_faction"];
        
        // Count operational RND buildings
        private _rndBuildings = ["rndBuilding", _faction] call TWS_fnc_getOperationalObjects;
        
        if (count _rndBuildings > 0) then {
            // Generate RND points
            private _points = (count _rndBuildings) * (TWS_rndConfig get "pointsPerTick");
            [_faction, "rnd", _points] call TWS_fnc_modifyResource;
            
            // Randomly reveal enemy intelligence
            private _intelTypes = TWS_rndConfig get "intelTypes";
            private _randomIntel = selectRandom _intelTypes;
            
            [_faction, _randomIntel] call TWS_fnc_revealIntelligence;
            
            diag_log format ["[TWS] %1 RND tick: +%2 points, revealed %3 intel", _faction, _points, _randomIntel];
            systemChat format ["[TWS] %1 RND: Revealed enemy %2 locations", _faction, _randomIntel];
        };
    };
    
    // Function to reveal intelligence
    TWS_fnc_revealIntelligence = {
        params ["_faction", "_intelType"];
        
        // This would integrate with ALiVE or custom detection
        // For now, log the intelligence gain
        diag_log format ["[TWS] %1 gained intelligence on enemy %2", _faction, _intelType];
        
        // Could create markers, update database, etc.
    };
    
    // ============================================================
    // ELECTRICITY SYSTEM
    // ============================================================
    
    // Electricity configuration
    TWS_electricityConfig = createHashMap;
    TWS_electricityConfig set ["powerPerStation", 200];
    TWS_electricityConfig set ["sectorRange", 2000]; // 2km range for power coverage
    TWS_electricityConfig set ["delayMultiplier", 2.0]; // Delay multiplier without power
    
    // Function to calculate electricity coverage
    TWS_fnc_calculateElectricity = {
        params ["_faction"];
        
        // Count operational power stations
        private _powerStations = ["powerStation", _faction] call TWS_fnc_getOperationalObjects;
        
        private _totalPower = (count _powerStations) * (TWS_electricityConfig get "powerPerStation");
        
        // Update electricity resource
        private _resources = [_faction] call TWS_fnc_getResources;
        _resources set ["electricity", _totalPower];
        
        diag_log format ["[TWS] %1 electricity: %2 (%3 stations)", _faction, _totalPower, count _powerStations];
        
        _totalPower
    };
    
    // Function to check if location has power
    TWS_fnc_hasElectricity = {
        params ["_faction", "_position"];
        
        private _powerStations = ["powerStation", _faction] call TWS_fnc_getOperationalObjects;
        private _range = TWS_electricityConfig get "sectorRange";
        
        private _hasPower = false;
        {
            if (_position distance (getPosASL _x) <= _range) then {
                _hasPower = true;
            };
        } forEach _powerStations;
        
        _hasPower
    };
    
    // ============================================================
    // CONSTRUCTION SYSTEM
    // ============================================================
    
    // Construction configuration
    TWS_constructionConfig = createHashMap;
    TWS_constructionConfig set ["maxWorkers", 50];
    TWS_constructionConfig set ["workerCost", 10]; // Materials to train a worker
    TWS_constructionConfig set ["repairCostPerPercent", 5]; // Materials per 1% damage
    
    // Function to repair building
    TWS_fnc_repairBuilding = {
        params ["_faction", "_building"];
        
        if (isNull _building) exitWith {false};
        
        private _damage = damage _building;
        if (_damage <= 0) exitWith {true}; // Already repaired
        
        // Calculate repair cost
        private _damagePercent = floor (_damage * 100);
        private _materialCost = _damagePercent * (TWS_constructionConfig get "repairCostPerPercent");
        private _workerCost = ceil (_damagePercent / 20); // 1 worker per 20% damage
        
        // Check if we have resources
        private _resources = [_faction] call TWS_fnc_getResources;
        private _materials = _resources getOrDefault ["materials", 0];
        private _workers = _resources getOrDefault ["construction", 0];
        
        if (_materials >= _materialCost && _workers >= _workerCost) then {
            // Consume resources
            [_faction, "materials", -_materialCost] call TWS_fnc_modifyResource;
            [_faction, "construction", -_workerCost] call TWS_fnc_modifyResource;
            
            // Repair building
            _building setDamage 0;
            
            // Return workers after repair
            [_faction, "construction", _workerCost] spawn {
                params ["_faction", "_workers"];
                sleep (["RepairCompletionTimeBase"] call TWS_fnc_getInterval);
                [_faction, "construction", _workers] call TWS_fnc_modifyResource;
            };
            
            diag_log format ["[TWS] %1 repaired building (cost: %2 materials, %3 workers)", _faction, _materialCost, _workerCost];
            systemChat format ["[TWS] %1 building repaired", _faction];
            
            // Re-enable object if it was disabled
            [_building, true] call TWS_fnc_setObjectOperational;
            
            true
        } else {
            diag_log format ["[TWS] %1 cannot repair - insufficient resources", _faction];
            false
        };
    };
    
    // ============================================================
    // UPDATE LOOPS
    // ============================================================
    
    // RND update loop
    TWS_fnc_rndUpdateLoop = {
        while {true} do {
            {
                private _faction = _x;
                [_faction] call TWS_fnc_processRNDTick;
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep (["RNDTickInterval"] call TWS_fnc_getInterval);
        };
    };
    
    // Electricity update loop
    TWS_fnc_electricityUpdateLoop = {
        while {true} do {
            {
                private _faction = _x;
                [_faction] call TWS_fnc_calculateElectricity;
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep (["ElectricityUpdateInterval"] call TWS_fnc_getInterval);
        };
    };
    
    // Start update loops
    [] spawn TWS_fnc_rndUpdateLoop;
    [] spawn TWS_fnc_electricityUpdateLoop;
    
    // Make public
    publicVariable "TWS_manpowerConfig";
    publicVariable "TWS_advancedProduction";
    publicVariable "TWS_rndConfig";
    publicVariable "TWS_electricityConfig";
    publicVariable "TWS_constructionConfig";
    publicVariable "TWS_fnc_deductManpower";
    publicVariable "TWS_fnc_addManpower";
    publicVariable "TWS_fnc_processCasualties";
    publicVariable "TWS_fnc_canProduceAdvanced";
    publicVariable "TWS_fnc_consumeAdvancedProduction";
    publicVariable "TWS_fnc_processRNDTick";
    publicVariable "TWS_fnc_revealIntelligence";
    publicVariable "TWS_fnc_calculateElectricity";
    publicVariable "TWS_fnc_hasElectricity";
    publicVariable "TWS_fnc_repairBuilding";
    
    systemChat "[TWS] Extended resource system initialized";
    diag_log "[TWS] Extended resource system initialized";
    diag_log "[TWS] New resources: manpower, munitions, fabrications, rnd, electricity, construction";
};
