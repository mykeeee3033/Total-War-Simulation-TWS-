/*
 * sectorManagement.sqf
 * Sector Management and Priority System
 * 
 * Features:
 * - Integration with ALiVE sectors or marker-based fallback
 * - Sector weighting based on proximity, clustering, and state
 * - Priority calculation for defensive/offensive operations
 * - Sector control tracking
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_config"};
    
    diag_log "[TWS] Initializing sector management system...";
    
    // Initialize sector tracking
    TWS_sectors = createHashMap;
    TWS_sectors set ["BLUFOR", []];
    TWS_sectors set ["OPFOR", []];
    TWS_sectors set ["sectorData", createHashMap];
    
    // Main base positions (can be configured)
    TWS_mainBases = createHashMap;
    TWS_mainBases set ["BLUFOR", [0, 0, 0]]; // To be set dynamically
    TWS_mainBases set ["OPFOR", [0, 0, 0]];
    
    // Sector state
    TWS_sectorState = createHashMap;
    TWS_sectorState set ["underAttack", []];
    TWS_sectorState set ["contested", []];
    
    // ============================================================
    // SECTOR DETECTION
    // ============================================================
    
    // Function to detect ALiVE sectors
    TWS_fnc_detectALiVESectors = {
        private _aliveDetected = false;
        private _sectors = [];
        
        // Check if ALiVE is present and has sectors
        if (!isNil "ALIVE_sectorGrid") then {
            _aliveDetected = true;
            // Get ALiVE sectors
            _sectors = ALIVE_sectorGrid select {!isNil "_x"};
            diag_log format ["[TWS] Detected %1 ALiVE sectors", count _sectors];
        } else {
            diag_log "[TWS] ALiVE sectors not detected, using marker-based fallback";
        };
        
        [_aliveDetected, _sectors]
    };
    
    // Function to get marker-based sectors (fallback)
    TWS_fnc_getMarkerSectors = {
        private _sectors = [];
        
        // Find all markers with "sector_" prefix
        private _sectorMarkers = allMapMarkers select {
            toLower _x find "sector_" >= 0 || 
            toLower _x find "military_" >= 0 ||
            toLower _x find "poi_" >= 0
        };
        
        {
            private _markerName = _x;
            private _pos = getMarkerPos _markerName;
            private _size = getMarkerSize _markerName;
            
            private _sectorData = createHashMap;
            _sectorData set ["name", _markerName];
            _sectorData set ["position", _pos];
            _sectorData set ["size", _size];
            _sectorData set ["owner", "NONE"];
            
            _sectors pushBack _sectorData;
        } forEach _sectorMarkers;
        
        diag_log format ["[TWS] Created %1 marker-based sectors", count _sectors];
        _sectors
    };
    
    // Function to initialize sectors
    TWS_fnc_initializeSectors = {
        private _detectionResult = [] call TWS_fnc_detectALiVESectors;
        private _usingALiVE = _detectionResult select 0;
        private _sectors = _detectionResult select 1;
        
        // Fallback to markers if ALiVE not detected
        if (!_usingALiVE || count _sectors == 0) then {
            _sectors = [] call TWS_fnc_getMarkerSectors;
        };
        
        // Process each sector
        {
            private _sectorData = _x;
            private _sectorID = if (typeName _sectorData == "HASHMAP") then {
                _sectorData get "name"
            } else {
                str _sectorData
            };
            
            // Register sector
            private _allSectorData = TWS_sectors get "sectorData";
            _allSectorData set [_sectorID, _sectorData];
        } forEach _sectors;
        
        systemChat format ["[TWS] Initialized %1 sectors", count _sectors];
        diag_log format ["[TWS] Sector system initialized with %1 sectors", count _sectors];
    };
    
    // ============================================================
    // SECTOR PRIORITY CALCULATION
    // ============================================================
    
    // Function to calculate sector priority
    TWS_fnc_calculateSectorPriority = {
        params ["_sectorID", "_faction", "_isDefensive"];
        
        private _allSectorData = TWS_sectors get "sectorData";
        private _sectorData = _allSectorData getOrDefault [_sectorID, createHashMap];
        
        if (count _sectorData == 0) exitWith {0};
        
        private _priority = 1.0; // Base priority
        private _sectorPos = _sectorData getOrDefault ["position", [0,0,0]];
        
        // Get main base position
        private _mainBase = TWS_mainBases getOrDefault [_faction, [0,0,0]];
        if (_mainBase isEqualTo [0,0,0]) then {
            // Try to find main base dynamically
            _mainBase = [_faction] call TWS_fnc_findMainBase;
            TWS_mainBases set [_faction, _mainBase];
        };
        
        // Distance to main base
        private _distanceToBase = _sectorPos distance _mainBase;
        
        // Proximity weight - closer sectors have higher priority in defensive mode
        if (_isDefensive) then {
            private _proximityWeight = TWS_sectorWeights get "baseProximityWeight";
            if (_distanceToBase < 2000) then {
                _priority = _priority * _proximityWeight;
            } else {
                if (_distanceToBase > 5000) then {
                    _priority = _priority * (TWS_sectorWeights get "isolatedPenalty");
                };
            };
        } else {
            // Offensive mode - prioritize sectors farther from base (frontline)
            if (_distanceToBase > 3000) then {
                _priority = _priority * (TWS_sectorWeights get "frontlineWeight");
            };
        };
        
        // Cluster weight - sectors near other sectors get higher priority
        private _nearSectors = [_sectorPos, 3000] call TWS_fnc_countNearbySectors;
        if (_nearSectors > 2) then {
            _priority = _priority * (TWS_sectorWeights get "clusterWeight");
        };
        
        // Under attack multiplier
        private _underAttack = TWS_sectorState get "underAttack";
        if (_sectorID in _underAttack) then {
            _priority = _priority * (TWS_sectorWeights get "underAttackMultiplier");
        };
        
        _priority
    };
    
    // Function to count nearby sectors
    TWS_fnc_countNearbySectors = {
        params ["_position", "_radius"];
        
        private _count = 0;
        private _allSectorData = TWS_sectors get "sectorData";
        
        {
            private _sectorData = _y;
            private _sectorPos = _sectorData getOrDefault ["position", [0,0,0]];
            if (_position distance _sectorPos <= _radius && _position distance _sectorPos > 0) then {
                _count = _count + 1;
            };
        } forEach _allSectorData;
        
        _count
    };
    
    // Function to find main base
    TWS_fnc_findMainBase = {
        params ["_faction"];
        
        // Try to find HQ nodes
        private _hqNodes = ["hqNode", _faction] call TWS_fnc_getOperationalObjects;
        if (count _hqNodes > 0) then {
            getPosASL (_hqNodes select 0)
        } else {
            // Fallback: find marker with "base_" prefix
            private _baseMarkers = allMapMarkers select {
                toLower _x find ("base_" + toLower _faction) >= 0 ||
                toLower _x find ("hq_" + toLower _faction) >= 0
            };
            
            if (count _baseMarkers > 0) then {
                getMarkerPos (_baseMarkers select 0)
            } else {
                [0, 0, 0]
            };
        };
    };
    
    // ============================================================
    // SECTOR CONTROL TRACKING
    // ============================================================
    
    // Function to update sector ownership
    TWS_fnc_updateSectorOwnership = {
        params ["_sectorID", "_newOwner"];
        
        private _allSectorData = TWS_sectors get "sectorData";
        private _sectorData = _allSectorData getOrDefault [_sectorID, createHashMap];
        
        if (count _sectorData == 0) exitWith {};
        
        private _oldOwner = _sectorData getOrDefault ["owner", "NONE"];
        _sectorData set ["owner", _newOwner];
        
        // Update faction sector lists
        if (_oldOwner != "NONE") then {
            private _oldList = TWS_sectors get _oldOwner;
            _oldList = _oldList - [_sectorID];
            TWS_sectors set [_oldOwner, _oldList];
        };
        
        if (_newOwner != "NONE") then {
            private _newList = TWS_sectors get _newOwner;
            _newList pushBackUnique _sectorID;
            TWS_sectors set [_newOwner, _newList];
        };
        
        diag_log format ["[TWS] Sector %1 ownership changed: %2 → %3", _sectorID, _oldOwner, _newOwner];
    };
    
    // Function to mark sector under attack
    TWS_fnc_markSectorUnderAttack = {
        params ["_sectorID", "_position"];
        
        private _underAttack = TWS_sectorState get "underAttack";
        _underAttack pushBackUnique _sectorID;
        
        systemChat format ["[TWS] Sector under attack: %1", _sectorID];
        diag_log format ["[TWS] Sector %1 marked as under attack", _sectorID];
        
        // Auto-clear after 10 minutes
        [_sectorID] spawn {
            params ["_id"];
            sleep 600;
            private _list = TWS_sectorState get "underAttack";
            _list = _list - [_id];
            TWS_sectorState set ["underAttack", _list];
        };
    };
    
    // Function to get nearest sector to position
    TWS_fnc_getNearestSector = {
        params ["_position"];
        
        private _nearest = "";
        private _nearestDist = 999999;
        
        private _allSectorData = TWS_sectors get "sectorData";
        {
            private _sectorID = _x;
            private _sectorData = _y;
            private _sectorPos = _sectorData getOrDefault ["position", [0,0,0]];
            private _dist = _position distance _sectorPos;
            
            if (_dist < _nearestDist) then {
                _nearest = _sectorID;
                _nearestDist = _dist;
            };
        } forEach _allSectorData;
        
        _nearest
    };
    
    // Function to get priority sectors for faction
    TWS_fnc_getPrioritySectors = {
        params ["_faction", ["_isDefensive", true], ["_count", 5]];
        
        private _allSectorData = TWS_sectors get "sectorData";
        private _sectorPriorities = [];
        
        {
            private _sectorID = _x;
            private _priority = [_sectorID, _faction, _isDefensive] call TWS_fnc_calculateSectorPriority;
            _sectorPriorities pushBack [_sectorID, _priority];
        } forEach _allSectorData;
        
        // Sort by priority (highest first)
        _sectorPriorities sort false;
        
        // Return top N sectors
        private _result = [];
        for "_i" from 0 to ((_count min (count _sectorPriorities)) - 1) do {
            _result pushBack (_sectorPriorities select _i select 0);
        };
        
        _result
    };
    
    // ============================================================
    // UPDATE LOOP
    // ============================================================
    
    // Sector evaluation loop
    TWS_fnc_sectorEvaluationLoop = {
        while {true} do {
            // Evaluate priority sectors for each faction
            {
                private _faction = _x;
                private _commander = TWS_commanders getOrDefault [_faction, createHashMap];
                private _personality = _commander getOrDefault ["personality", "balanced"];
                
                // Determine if defensive or offensive
                private _isDefensive = _personality in ["cautious", "recovery", "logisticsFirst"];
                
                // Get priority sectors
                private _prioritySectors = [_faction, _isDefensive, 10] call TWS_fnc_getPrioritySectors;
                
                diag_log format ["[TWS] %1 priority sectors (%2 mode): %3", 
                    _faction, 
                    if (_isDefensive) then {"defensive"} else {"offensive"},
                    _prioritySectors select [0, 5]
                ];
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep (["SectorEvaluationInterval"] call TWS_fnc_getInterval);
        };
    };
    
    // Initialize sectors
    [] call TWS_fnc_initializeSectors;
    
    // Start evaluation loop
    [] spawn TWS_fnc_sectorEvaluationLoop;
    
    // Make public
    publicVariable "TWS_sectors";
    publicVariable "TWS_mainBases";
    publicVariable "TWS_sectorState";
    publicVariable "TWS_fnc_detectALiVESectors";
    publicVariable "TWS_fnc_getMarkerSectors";
    publicVariable "TWS_fnc_initializeSectors";
    publicVariable "TWS_fnc_calculateSectorPriority";
    publicVariable "TWS_fnc_countNearbySectors";
    publicVariable "TWS_fnc_findMainBase";
    publicVariable "TWS_fnc_updateSectorOwnership";
    publicVariable "TWS_fnc_markSectorUnderAttack";
    publicVariable "TWS_fnc_getNearestSector";
    publicVariable "TWS_fnc_getPrioritySectors";
    
    systemChat "[TWS] Sector Management system initialized";
    diag_log "[TWS] Sector Management system initialized";
};
