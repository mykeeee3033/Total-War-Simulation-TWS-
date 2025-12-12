/*
 * sectorAreaSystem.sqf
 * Dynamic Sector Area Management with Unit Scanning
 * 
 * Features:
 * - Radius-based unit scanning for ownership determination
 * - 3-state system: occupied, contested, captured
 * - Per-minute status checks
 * - Integration with morale, reinforcements, supply chain
 * - Notifications for status changes
 * - Ammo/supply scanning for resupply priorities
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_sectors"};
    
    diag_log "[TWS] Initializing sector area system...";
    systemChat "[TWS] Initializing sector area system...";
    
    // Sector area configuration
    TWS_sectorAreas = createHashMap;
    TWS_sectorAreas set ["areas", createHashMap];
    TWS_sectorAreas set ["scanRadius", 200]; // 200m radius for unit scanning
    TWS_sectorAreas set ["scanInterval", 60]; // Check every 60 seconds
    
    // Sector states
    TWS_SECTOR_OCCUPIED = "OCCUPIED";
    TWS_SECTOR_CONTESTED = "CONTESTED";
    TWS_SECTOR_CAPTURED = "CAPTURED";
    
    // Function to register sector area
    TWS_fnc_registerSectorArea = {
        params ["_sectorID", "_position", "_definingObject", "_faction"];
        
        private _areas = TWS_sectorAreas get "areas";
        
        private _areaData = createHashMap;
        _areaData set ["id", _sectorID];
        _areaData set ["position", _position];
        _areaData set ["object", _definingObject];
        _areaData set ["owner", _faction];
        _areaData set ["state", TWS_SECTOR_OCCUPIED];
        _areaData set ["lastState", TWS_SECTOR_OCCUPIED];
        _areaData set ["bluforCount", 0];
        _areaData set ["opforCount", 0];
        _areaData set ["ammoLevel", 100]; // 0-100
        _areaData set ["resourcePoints", 100];
        _areaData set ["needsResupply", false];
        _areaData set ["resupplyPriority", 0];
        _areaData set ["lastScan", 0];
        
        _areas set [_sectorID, _areaData];
        
        diag_log format ["[TWS] Registered sector area: %1 at %2 (owner: %3)", _sectorID, _position, _faction];
        
        _areaData
    };
    
    // Function to scan sector area for units
    TWS_fnc_scanSectorArea = {
        params ["_sectorID"];
        
        private _areas = TWS_sectorAreas get "areas";
        private _areaData = _areas getOrDefault [_sectorID, createHashMap];
        
        if (count _areaData == 0) exitWith {
            diag_log format ["[TWS] Cannot scan unknown sector: %1", _sectorID];
        };
        
        private _position = _areaData get "position";
        private _radius = TWS_sectorAreas get "scanRadius";
        
        // Find all units in radius
        private _nearUnits = _position nearEntities [["CAManBase"], _radius];
        
        // Count by faction
        private _bluforCount = 0;
        private _opforCount = 0;
        
        {
            if (alive _x) then {
                private _side = side group _x;
                if (_side == west) then {
                    _bluforCount = _bluforCount + 1;
                };
                if (_side == east) then {
                    _opforCount = _opforCount + 1;
                };
            };
        } forEach _nearUnits;
        
        // Update counts
        _areaData set ["bluforCount", _bluforCount];
        _areaData set ["opforCount", _opforCount];
        _areaData set ["lastScan", diag_tickTime];
        
        // Determine new state and owner
        private _oldOwner = _areaData get "owner";
        private _oldState = _areaData get "state";
        private _newOwner = _oldOwner;
        private _newState = _oldState;
        
        // Determine control based on unit counts
        if (_bluforCount > 0 && _opforCount > 0) then {
            // Both sides present = contested
            _newState = TWS_SECTOR_CONTESTED;
        } else {
            if (_bluforCount > _opforCount * 2) then {
                // BLUFOR dominates
                _newOwner = "BLUFOR";
                _newState = if (_oldOwner == "BLUFOR") then {TWS_SECTOR_OCCUPIED} else {TWS_SECTOR_CAPTURED};
            } else {
                if (_opforCount > _bluforCount * 2) then {
                    // OPFOR dominates
                    _newOwner = "OPFOR";
                    _newState = if (_oldOwner == "OPFOR") then {TWS_SECTOR_OCCUPIED} else {TWS_SECTOR_CAPTURED};
                } else {
                    // Maintain current ownership if minor presence
                    if (_bluforCount > 0 || _opforCount > 0) then {
                        _newState = TWS_SECTOR_CONTESTED;
                    };
                };
            };
        };
        
        // Update ownership and state
        _areaData set ["owner", _newOwner];
        _areaData set ["lastState", _oldState];
        _areaData set ["state", _newState];
        
        // Check for state changes and notify
        if (_oldState != _newState || _oldOwner != _newOwner) then {
            private _stateDesc = format ["%1 (%2)", _newState, _newOwner];
            private _oldStateDesc = format ["%1 (%2)", _oldState, _oldOwner];
            
            [_sectorID, _oldStateDesc, _stateDesc, _position] call TWS_fnc_notifySectorChange;
            
            // Apply morale and resource effects
            [_sectorID, _oldOwner, _newOwner, _newState] call TWS_fnc_applySectorChangeEffects;
        };
        
        _areaData
    };
    
    // Function to apply effects of sector changes
    TWS_fnc_applySectorChangeEffects = {
        params ["_sectorID", "_oldOwner", "_newOwner", "_newState"];
        
        // Morale effects
        if (_newState == TWS_SECTOR_CAPTURED) then {
            if (_oldOwner != "NONE" && _oldOwner != _newOwner) then {
                // Losing faction loses morale
                if (!isNil "TWS_fnc_modifyMorale") then {
                    [_oldOwner, -0.1] call TWS_fnc_modifyMorale;
                };
                // Capturing faction gains morale
                if (!isNil "TWS_fnc_modifyMorale") then {
                    [_newOwner, 0.05] call TWS_fnc_modifyMorale;
                };
            };
        };
        
        // Notify reinforcement system
        if (_newState == TWS_SECTOR_CONTESTED) then {
            private _areas = TWS_sectorAreas get "areas";
            private _areaData = _areas getOrDefault [_sectorID, createHashMap];
            private _position = _areaData getOrDefault ["position", [0,0,0]];
            
            // Mark sector under attack
            if (!isNil "TWS_fnc_markSectorUnderAttack") then {
                [_sectorID, _position] call TWS_fnc_markSectorUnderAttack;
            };
        };
        
        diag_log format ["[TWS] Sector change effects applied for %1: %2 -> %3 (state: %4)", 
            _sectorID, _oldOwner, _newOwner, _newState];
    };
    
    // Function to scan sector area for ammo/supplies
    TWS_fnc_scanSectorAmmo = {
        params ["_sectorID"];
        
        private _areas = TWS_sectorAreas get "areas";
        private _areaData = _areas getOrDefault [_sectorID, createHashMap];
        
        if (count _areaData == 0) exitWith {0};
        
        private _position = _areaData get "position";
        private _radius = TWS_sectorAreas get "scanRadius";
        
        // Find all units and crates in radius
        private _nearUnits = _position nearEntities [["CAManBase"], _radius];
        private _nearCrates = _position nearObjects [["ReammoBox_F", "Box_NATO_Ammo_F", "Box_East_Ammo_F"], _radius];
        
        // Calculate average ammo level
        private _totalAmmo = 0;
        private _count = 0;
        
        // Check soldiers
        {
            if (alive _x) then {
                private _magazines = magazines _x;
                _totalAmmo = _totalAmmo + (count _magazines);
                _count = _count + 1;
            };
        } forEach _nearUnits;
        
        // Check crates (simplified - assume crates with items = 100 ammo equivalent)
        {
            private _items = getMagazineCargo _x;
            if (count (_items select 0) > 0) then {
                _totalAmmo = _totalAmmo + 100;
                _count = _count + 1;
            };
        } forEach _nearCrates;
        
        // Calculate average ammo level (0-100 scale)
        private _ammoLevel = if (_count > 0) then {
            ((_totalAmmo / _count) * 10) min 100
        } else {
            0
        };
        
        _areaData set ["ammoLevel", _ammoLevel];
        
        // Determine if resupply is needed
        private _needsResupply = _ammoLevel < 40;
        _areaData set ["needsResupply", _needsResupply];
        
        // Calculate resupply priority
        if (_needsResupply) then {
            private _priority = [_sectorID] call TWS_fnc_calculateResupplyPriority;
            _areaData set ["resupplyPriority", _priority];
        } else {
            _areaData set ["resupplyPriority", 0];
        };
        
        _ammoLevel
    };
    
    // Function to calculate resupply priority for sector
    TWS_fnc_calculateResupplyPriority = {
        params ["_sectorID"];
        
        private _areas = TWS_sectorAreas get "areas";
        private _areaData = _areas getOrDefault [_sectorID, createHashMap];
        
        if (count _areaData == 0) exitWith {0};
        
        private _priority = 1.0;
        
        // Factor 1: Ammo level (lower = higher priority)
        private _ammoLevel = _areaData getOrDefault ["ammoLevel", 100];
        if (_ammoLevel < 20) then {
            _priority = _priority * 3.0; // Critical
        } else {
            if (_ammoLevel < 40) then {
                _priority = _priority * 2.0; // High
            };
        };
        
        // Factor 2: Proximity to main base (closer = higher priority)
        private _position = _areaData get "position";
        private _owner = _areaData get "owner";
        private _mainBase = TWS_mainBases getOrDefault [_owner, [0,0,0]];
        private _distance = _position distance _mainBase;
        
        if (_distance < 2000) then {
            _priority = _priority * 1.5;
        } else {
            if (_distance > 5000) then {
                _priority = _priority * 0.7;
            };
        };
        
        // Factor 3: Sector state
        private _state = _areaData get "state";
        if (_state == TWS_SECTOR_CONTESTED) then {
            _priority = _priority * 2.5; // Contested areas are critical
        };
        
        // Factor 4: Unit count (more units = higher priority)
        private _unitCount = (_areaData getOrDefault ["bluforCount", 0]) + (_areaData getOrDefault ["opforCount", 0]);
        if (_unitCount > 20) then {
            _priority = _priority * 1.3;
        };
        
        _priority
    };
    
    // Function to get sectors needing resupply
    TWS_fnc_getSectorsNeedingResupply = {
        params ["_faction"];
        
        private _areas = TWS_sectorAreas get "areas";
        private _needingResupply = [];
        
        {
            private _sectorID = _x;
            private _areaData = _y;
            
            if ((_areaData get "owner") == _faction && (_areaData get "needsResupply")) then {
                _needingResupply pushBack [_sectorID, _areaData get "resupplyPriority"];
            };
        } forEach _areas;
        
        // Sort by priority (highest first)
        _needingResupply sort {(_y select 1) - (_x select 1)};
        
        // Return just sector IDs
        _needingResupply apply {_x select 0}
    };
    
    // Function to add resource points to sector
    TWS_fnc_addSectorResources = {
        params ["_sectorID", "_amount"];
        
        private _areas = TWS_sectorAreas get "areas";
        private _areaData = _areas getOrDefault [_sectorID, createHashMap];
        
        if (count _areaData == 0) exitWith {};
        
        private _current = _areaData getOrDefault ["resourcePoints", 0];
        private _new = _current + _amount;
        _areaData set ["resourcePoints", _new];
        
        // Also update ammo level
        private _ammoLevel = _areaData getOrDefault ["ammoLevel", 0];
        _areaData set ["ammoLevel", (_ammoLevel + 20) min 100];
        
        private _position = _areaData get "position";
        ["OPFOR", _position, "supplies", _amount] call TWS_fnc_notifyResupply;
        
        diag_log format ["[TWS] Added %1 resource points to sector %2 (new total: %3)", _amount, _sectorID, _new];
    };
    
    // Sector scanning loop
    TWS_fnc_sectorScanningLoop = {
        while {true} do {
            private _areas = TWS_sectorAreas get "areas";
            
            {
                private _sectorID = _x;
                
                // Scan for units and ownership
                [_sectorID] call TWS_fnc_scanSectorArea;
                
                // Scan for ammo needs
                [_sectorID] call TWS_fnc_scanSectorAmmo;
                
                sleep 1; // Small delay between sectors
            } forEach _areas;
            
            sleep (TWS_sectorAreas get "scanInterval");
        };
    };
    
    // Start scanning loop
    [] spawn TWS_fnc_sectorScanningLoop;
    
    // Make public
    publicVariable "TWS_sectorAreas";
    publicVariable "TWS_SECTOR_OCCUPIED";
    publicVariable "TWS_SECTOR_CONTESTED";
    publicVariable "TWS_SECTOR_CAPTURED";
    publicVariable "TWS_fnc_registerSectorArea";
    publicVariable "TWS_fnc_scanSectorArea";
    publicVariable "TWS_fnc_applySectorChangeEffects";
    publicVariable "TWS_fnc_scanSectorAmmo";
    publicVariable "TWS_fnc_calculateResupplyPriority";
    publicVariable "TWS_fnc_getSectorsNeedingResupply";
    publicVariable "TWS_fnc_addSectorResources";
    
    systemChat "[TWS] Sector area system initialized";
    diag_log "[TWS] Sector area system initialized - scanning every 60 seconds";
};
