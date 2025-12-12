/*
 * advancedReinforcements.sqf
 * Advanced Reinforcement System
 * 
 * Features:
 * - Troops in contact detection and response
 * - Weight-based unit type selection
 * - Instant spawn from manpower pool
 * - Contact frequency tracking
 * - Integration with existing support_manager.sqf
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_intervals"};
    
    diag_log "[TWS] Initializing advanced reinforcement system...";
    
    // Contact tracking
    TWS_contactZones = createHashMap;
    TWS_contactFrequency = createHashMap;
    
    // Reinforcement history
    TWS_reinforcementHistory = createHashMap;
    TWS_reinforcementHistory set ["BLUFOR", []];
    TWS_reinforcementHistory set ["OPFOR", []];
    
    // ============================================================
    // CONTACT DETECTION
    // ============================================================
    
    // Function to register troops in contact
    TWS_fnc_registerContact = {
        params ["_position", "_faction", "_casualties"];
        
        // Find nearest sector
        private _sectorID = [_position] call TWS_fnc_getNearestSector;
        
        // Update contact frequency
        private _currentFrequency = TWS_contactFrequency getOrDefault [_sectorID, 0];
        TWS_contactFrequency set [_sectorID, _currentFrequency + 1];
        
        // Store contact zone
        private _zoneData = createHashMap;
        _zoneData set ["position", _position];
        _zoneData set ["faction", _faction];
        _zoneData set ["casualties", _casualties];
        _zoneData set ["timestamp", diag_tickTime];
        _zoneData set ["frequency", _currentFrequency + 1];
        
        TWS_contactZones set [_sectorID, _zoneData];
        
        // Mark sector under attack
        [_sectorID, _position] call TWS_fnc_markSectorUnderAttack;
        
        // Determine reinforcement weight
        private _weight = [_sectorID, _casualties] call TWS_fnc_determineReinforcementWeight;
        
        // Request reinforcements
        [_faction, _position, _weight, _casualties] call TWS_fnc_requestReinforcements;
        
        diag_log format ["[TWS] Contact registered: %1 at %2 (casualties: %3, weight: %4)", 
            _faction, _sectorID, _casualties, _weight];
    };
    
    // ============================================================
    // REINFORCEMENT WEIGHT CALCULATION
    // ============================================================
    
    // Function to determine reinforcement weight
    TWS_fnc_determineReinforcementWeight = {
        params ["_sectorID", "_casualties"];
        
        private _frequency = TWS_contactFrequency getOrDefault [_sectorID, 0];
        private _weight = "low";
        
        // Base weight on casualties
        {
            private _tier = _x select 0;
            private _minCasualties = _x select 1;
            private _maxCasualties = _x select 2;
            
            if (_casualties >= _minCasualties && _casualties <= _maxCasualties) then {
                _weight = _tier;
            };
        } forEach TWS_reinforcementWeights;
        
        // Increase weight based on frequency
        if (_frequency > 5) then {
            // Frequent contact area - escalate
            if (_weight == "low") then {_weight = "medium"};
            if (_weight == "medium") then {_weight = "high"};
        };
        
        _weight
    };
    
    // ============================================================
    // REINFORCEMENT SPAWNING
    // ============================================================
    
    // Function to request reinforcements
    TWS_fnc_requestReinforcements = {
        params ["_faction", "_position", "_weight", "_casualties"];
        
        // Check morale
        private _moraleData = [_faction] call TWS_fnc_getMoraleStatus;
        private _morale = _moraleData select 0;
        private _moraleStatus = _moraleData select 1;
        
        // Check if we have manpower
        private _resources = [_faction] call TWS_fnc_getResources;
        private _manpower = _resources getOrDefault ["manpower", 0];
        
        if (_manpower < 10) exitWith {
            diag_log format ["[TWS] %1 cannot send reinforcements - insufficient manpower (%2)", _faction, _manpower];
            systemChat format ["[TWS] %1 insufficient manpower for reinforcements", _faction];
        };
        
        // Determine unit type and count based on weight
        private _unitType = "";
        private _unitCount = 0;
        
        switch (_weight) do {
            case "low": {
                _unitType = "transport";
                _unitCount = 1;
            };
            case "medium": {
                _unitType = "apc";
                _unitCount = 2;
            };
            case "high": {
                _unitType = "armor";
                _unitCount = 2;
            };
        };
        
        // Adjust based on morale
        if (_moraleStatus == "broken") then {
            // Don't send reinforcements when broken
            diag_log format ["[TWS] %1 morale broken - reinforcements withheld", _faction];
            exitWith {};
        };
        
        if (_moraleStatus in ["excellent", "good"]) then {
            _unitCount = _unitCount + 1; // Send extra units
        };
        
        // Spawn reinforcements
        [_faction, _position, _unitType, _unitCount] call TWS_fnc_spawnReinforcements;
    };
    
    // Function to spawn reinforcements
    TWS_fnc_spawnReinforcements = {
        params ["_faction", "_position", "_unitType", "_unitCount"];
        
        // Check vehicle pool first
        private _pool = TWS_vehiclePools getOrDefault [_faction, []];
        private _spawnedVehicles = 0;
        
        // Try to use vehicles from pool
        for "_i" from 1 to _unitCount do {
            if (count _pool > 0) then {
                private _vehicle = _pool deleteAt 0;
                
                // Move vehicle to spawn position
                private _spawnPos = [_position, 100, 200, 10, 0, 0.3, 0] call BIS_fnc_findSafePos;
                _vehicle setPos _spawnPos;
                
                // Crew the vehicle
                [_faction, _vehicle] call TWS_fnc_crewVehicle;
                
                // Set waypoint to contact position
                private _grp = group (driver _vehicle);
                if (!isNull _grp) then {
                    private _wp = _grp addWaypoint [_position, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "FULL";
                };
                
                _spawnedVehicles = _spawnedVehicles + 1;
            };
        };
        
        // If pool was empty, spawn new units (from manpower)
        if (_spawnedVehicles == 0) then {
            [_faction, _position, _unitType, _unitCount] call TWS_fnc_spawnEmergencyReinforcements;
        };
        
        // Deduct manpower
        private _manpowerCost = _unitCount * 5;
        [_faction, _manpowerCost] call TWS_fnc_deductManpower;
        
        // Record reinforcement
        private _history = TWS_reinforcementHistory get _faction;
        private _record = createHashMap;
        _record set ["position", _position];
        _record set ["unitType", _unitType];
        _record set ["count", _spawnedVehicles];
        _record set ["timestamp", diag_tickTime];
        _history pushBack _record;
        
        diag_log format ["[TWS] %1 reinforcements dispatched: %2x %3 to %4", 
            _faction, _spawnedVehicles, _unitType, _position];
        systemChat format ["[TWS] %1 reinforcements en route (%2x %3)", 
            _faction, _spawnedVehicles, _unitType];
    };
    
    // Function to crew vehicle with trained units
    TWS_fnc_crewVehicle = {
        params ["_faction", "_vehicle"];
        
        private _side = if (_faction == "BLUFOR") then {west} else {east};
        private _unitClass = if (_faction == "BLUFOR") then {"B_Soldier_F"} else {"O_Soldier_F"};
        
        // Get training bonus
        private _skillBonus = [_faction] call TWS_fnc_getTrainingBonus;
        
        // Create crew
        private _grp = createGroup _side;
        
        // Driver
        private _driver = _grp createUnit [_unitClass, getPosASL _vehicle, [], 0, "NONE"];
        _driver moveInDriver _vehicle;
        _driver setSkill ((skill _driver) + _skillBonus);
        
        // Gunner if available
        if (!isNull (gunner _vehicle)) then {
            private _gunner = _grp createUnit [_unitClass, getPosASL _vehicle, [], 0, "NONE"];
            _gunner moveInGunner _vehicle;
            _gunner setSkill ((skill _gunner) + _skillBonus);
        };
        
        // Commander if available
        if (!isNull (commander _vehicle)) then {
            private _cmdr = _grp createUnit [_unitClass, getPosASL _vehicle, [], 0, "NONE"];
            _cmdr moveInCommander _vehicle;
            _cmdr setSkill ((skill _cmdr) + _skillBonus);
        };
    };
    
    // Function to spawn emergency reinforcements (no vehicles in pool)
    TWS_fnc_spawnEmergencyReinforcements = {
        params ["_faction", "_position", "_unitType", "_unitCount"];
        
        private _side = if (_faction == "BLUFOR") then {west} else {east};
        private _unitClass = if (_faction == "BLUFOR") then {"B_Soldier_F"} else {"O_Soldier_F"};
        
        // Spawn infantry group as emergency response
        private _spawnPos = [_position, 200, 300, 10, 0, 0.3, 0] call BIS_fnc_findSafePos;
        private _grp = createGroup _side;
        
        for "_i" from 1 to (_unitCount * 4) do {
            private _unit = _grp createUnit [_unitClass, _spawnPos, [], 5, "FORM"];
            
            // Apply training bonus
            private _skillBonus = [_faction] call TWS_fnc_getTrainingBonus;
            _unit setSkill ((skill _unit) + _skillBonus);
        };
        
        // Move to contact
        private _wp = _grp addWaypoint [_position, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "FULL";
        
        diag_log format ["[TWS] %1 emergency infantry reinforcements spawned", _faction];
    };
    
    // ============================================================
    // INTEGRATION WITH EXISTING SYSTEMS
    // ============================================================
    
    // Hook into combat_monitor.sqf casualties
    if (!isNil "factionStats") then {
        TWS_fnc_monitorCasualties = {
            [] spawn {
                private _lastCheck = createHashMap;
                _lastCheck set ["BLUFOR", 0];
                _lastCheck set ["OPFOR", 0];
                
                while {true} do {
                    {
                        private _factionName = _x select 0;
                        private _casualties = _x select 1;
                        
                        private _lastCasualties = _lastCheck getOrDefault [_factionName, 0];
                        private _newCasualties = _casualties - _lastCasualties;
                        
                        if (_newCasualties >= 5) then {
                            // Significant casualties - trigger reinforcement check
                            if (!isNil "latestCasualtyPos") then {
                                [latestCasualtyPos, _factionName, _newCasualties] call TWS_fnc_registerContact;
                            };
                            _lastCheck set [_factionName, _casualties];
                        };
                    } forEach factionStats;
                    
                    sleep (["ReinforcementCheckInterval"] call TWS_fnc_getInterval);
                };
            };
        };
        
        [] call TWS_fnc_monitorCasualties;
    };
    
    // ============================================================
    // UPDATE LOOP
    // ============================================================
    
    // Contact zone cleanup loop
    TWS_fnc_contactCleanupLoop = {
        while {true} do {
            private _currentTime = diag_tickTime;
            
            // Clean up old contact zones (>15 minutes)
            {
                private _zoneID = _x;
                private _zoneData = _y;
                private _timestamp = _zoneData getOrDefault ["timestamp", 0];
                
                if (_currentTime - _timestamp > 900) then {
                    TWS_contactZones deleteAt _zoneID;
                };
            } forEach TWS_contactZones;
            
            sleep 300; // Check every 5 minutes
        };
    };
    
    [] spawn TWS_contactCleanupLoop;
    
    // Make public
    publicVariable "TWS_contactZones";
    publicVariable "TWS_contactFrequency";
    publicVariable "TWS_reinforcementHistory";
    publicVariable "TWS_fnc_registerContact";
    publicVariable "TWS_fnc_determineReinforcementWeight";
    publicVariable "TWS_fnc_requestReinforcements";
    publicVariable "TWS_fnc_spawnReinforcements";
    publicVariable "TWS_fnc_crewVehicle";
    publicVariable "TWS_fnc_spawnEmergencyReinforcements";
    
    systemChat "[TWS] Advanced Reinforcement system initialized";
    diag_log "[TWS] Advanced Reinforcement system initialized";
};
