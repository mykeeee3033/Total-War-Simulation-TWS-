/*
 * communicationGrid.sqf
 * Communication Grid Coverage System
 * 
 * Features:
 * - Antenna coverage calculation per sector
 * - Order delays without coverage
 * - Support availability based on coverage
 * - Coverage visualization
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_intervals"};
    
    diag_log "[TWS] Initializing communication grid system...";
    
    // Communication coverage data
    TWS_commCoverage = createHashMap;
    TWS_commCoverage set ["BLUFOR", createHashMap];
    TWS_commCoverage set ["OPFOR", createHashMap];
    
    // ============================================================
    // ANTENNA DETECTION
    // ============================================================
    
    // Function to get operational antennas
    TWS_fnc_getOperationalAntennas = {
        params ["_faction"];
        
        private _antennas = ["antenna", _faction] call TWS_fnc_getOperationalObjects;
        _antennas
    };
    
    // ============================================================
    // COVERAGE CALCULATION
    // ============================================================
    
    // Function to calculate coverage for position
    TWS_fnc_calculateCommCoverage = {
        params ["_faction", "_position"];
        
        private _antennas = [_faction] call TWS_fnc_getOperationalAntennas;
        private _range = TWS_communicationConfig get "antennaRange";
        
        private _coveringAntennas = 0;
        {
            if (_position distance (getPosASL _x) <= _range) then {
                _coveringAntennas = _coveringAntennas + 1;
            };
        } forEach _antennas;
        
        _coveringAntennas
    };
    
    // Function to check if position has coverage
    TWS_fnc_hasCommunication = {
        params ["_faction", "_position"];
        
        private _coveringAntennas = [_faction, _position] call TWS_fnc_calculateCommCoverage;
        private _minRequired = TWS_communicationConfig get "minAntennas";
        
        _coveringAntennas >= _minRequired
    };
    
    // Function to get coverage quality
    TWS_fnc_getCoverageQuality = {
        params ["_faction", "_position"];
        
        private _coveringAntennas = [_faction, _position] call TWS_fnc_calculateCommCoverage;
        private _optimal = TWS_communicationConfig get "optimalAntennas";
        
        private _quality = "none";
        if (_coveringAntennas >= _optimal) then {
            _quality = "excellent";
        } else {
            if (_coveringAntennas >= 2) then {
                _quality = "good";
            } else {
                if (_coveringAntennas >= 1) then {
                    _quality = "poor";
                };
            };
        };
        
        _quality
    };
    
    // ============================================================
    // SECTOR COVERAGE TRACKING
    // ============================================================
    
    // Function to update sector communication coverage
    TWS_fnc_updateSectorCommCoverage = {
        params ["_faction"];
        
        private _coverage = TWS_commCoverage get _faction;
        private _allSectorData = TWS_sectors get "sectorData";
        
        {
            private _sectorID = _x;
            private _sectorData = _y;
            private _sectorPos = _sectorData getOrDefault ["position", [0,0,0]];
            
            // Calculate coverage
            private _antennaCount = [_faction, _sectorPos] call TWS_fnc_calculateCommCoverage;
            private _quality = [_faction, _sectorPos] call TWS_fnc_getCoverageQuality;
            
            private _sectorCoverage = createHashMap;
            _sectorCoverage set ["antennas", _antennaCount];
            _sectorCoverage set ["quality", _quality];
            _sectorCoverage set ["hasCoverage", _antennaCount >= 1];
            
            _coverage set [_sectorID, _sectorCoverage];
        } forEach _allSectorData;
        
        diag_log format ["[TWS] %1 communication coverage updated for %2 sectors", 
            _faction, count _coverage];
    };
    
    // ============================================================
    // DELAY CALCULATION
    // ============================================================
    
    // Function to calculate order delay
    TWS_fnc_calculateOrderDelay = {
        params ["_faction", "_position"];
        
        private _baseDelay = 0;
        private _hasCoverage = [_faction, _position] call TWS_fnc_hasCommunication;
        
        if (!_hasCoverage) then {
            // No coverage - apply delay multiplier
            private _multiplier = TWS_communicationConfig get "delayMultiplier";
            _baseDelay = _baseDelay + (_multiplier * 60); // Additional delay in seconds
            
            diag_log format ["[TWS] %1 order delay at %2: %3s (no comm coverage)", 
                _faction, _position, _baseDelay];
        };
        
        // Check electricity coverage
        if (!([_faction, _position] call TWS_fnc_hasElectricity)) then {
            _baseDelay = _baseDelay + 60; // Additional minute
        };
        
        _baseDelay
    };
    
    // Function to apply order delay
    TWS_fnc_applyOrderDelay = {
        params ["_faction", "_position", "_code"];
        
        private _delay = [_faction, _position] call TWS_fnc_calculateOrderDelay;
        
        if (_delay > 0) then {
            systemChat format ["[TWS] %1 order delayed %2s due to poor communications", 
                _faction, _delay];
        };
        
        [{
            params ["_code"];
            call _code;
        }, [_code], _delay] call CBA_fnc_waitAndExecute;
    };
    
    // ============================================================
    // SUPPORT AVAILABILITY
    // ============================================================
    
    // Function to check if support is available
    TWS_fnc_isSupportAvailable = {
        params ["_faction", "_position", "_supportType"];
        
        private _hasCoverage = [_faction, _position] call TWS_fnc_hasCommunication;
        
        // Without coverage, only emergency support
        if (!_hasCoverage) then {
            if (_supportType in ["cas", "artillery"]) then {
                // Air support requires coverage
                false
            } else {
                // Ground support can still happen, just delayed
                true
            };
        } else {
            true
        };
    };
    
    // ============================================================
    // COVERAGE REPORTING
    // ============================================================
    
    // Function to get coverage report
    TWS_fnc_getCommCoverageReport = {
        params ["_faction"];
        
        private _coverage = TWS_commCoverage get _faction;
        private _report = createHashMap;
        
        private _excellentCount = 0;
        private _goodCount = 0;
        private _poorCount = 0;
        private _noneCount = 0;
        
        {
            private _sectorCoverage = _y;
            private _quality = _sectorCoverage get "quality";
            
            switch (_quality) do {
                case "excellent": {_excellentCount = _excellentCount + 1};
                case "good": {_goodCount = _goodCount + 1};
                case "poor": {_poorCount = _poorCount + 1};
                case "none": {_noneCount = _noneCount + 1};
            };
        } forEach _coverage;
        
        _report set ["excellent", _excellentCount];
        _report set ["good", _goodCount];
        _report set ["poor", _poorCount];
        _report set ["none", _noneCount];
        _report set ["totalSectors", count _coverage];
        
        _report
    };
    
    // ============================================================
    // VISUALIZATION (OPTIONAL)
    // ============================================================
    
    // Function to visualize coverage (debug)
    TWS_fnc_visualizeCommCoverage = {
        params ["_faction"];
        
        private _antennas = [_faction] call TWS_fnc_getOperationalAntennas;
        private _range = TWS_communicationConfig get "antennaRange";
        
        // Delete old markers
        {
            if (markerText _x find "COMM_" >= 0) then {
                deleteMarker _x;
            };
        } forEach allMapMarkers;
        
        // Create new markers
        {
            private _antenna = _x;
            private _pos = getPosASL _antenna;
            private _markerName = format ["COMM_%1_%2", _faction, _forEachIndex];
            
            private _marker = createMarker [_markerName, _pos];
            _marker setMarkerShape "ELLIPSE";
            _marker setMarkerSize [_range, _range];
            _marker setMarkerBrush "Border";
            _marker setMarkerColor (if (_faction == "BLUFOR") then {"ColorBLUE"} else {"ColorRED"});
            _marker setMarkerAlpha 0.3;
        } forEach _antennas;
        
        systemChat format ["[TWS] %1 communication coverage visualized", _faction];
    };
    
    // ============================================================
    // UPDATE LOOP
    // ============================================================
    
    // Communication coverage update loop
    TWS_fnc_commCoverageUpdateLoop = {
        while {true} do {
            {
                private _faction = _x;
                [_faction] call TWS_fnc_updateSectorCommCoverage;
                
                // Get report
                private _report = [_faction] call TWS_fnc_getCommCoverageReport;
                private _excellent = _report get "excellent";
                private _good = _report get "good";
                private _poor = _report get "poor";
                private _none = _report get "none";
                
                diag_log format ["[TWS] %1 comm coverage: Excellent=%2, Good=%3, Poor=%4, None=%5", 
                    _faction, _excellent, _good, _poor, _none];
            } forEach ["BLUFOR", "OPFOR"];
            
            sleep (["CommunicationCheckInterval"] call TWS_fnc_getInterval);
        };
    };
    
    [] spawn TWS_fnc_commCoverageUpdateLoop;
    
    // Make public
    publicVariable "TWS_commCoverage";
    publicVariable "TWS_fnc_getOperationalAntennas";
    publicVariable "TWS_fnc_calculateCommCoverage";
    publicVariable "TWS_fnc_hasCommunication";
    publicVariable "TWS_fnc_getCoverageQuality";
    publicVariable "TWS_fnc_updateSectorCommCoverage";
    publicVariable "TWS_fnc_calculateOrderDelay";
    publicVariable "TWS_fnc_applyOrderDelay";
    publicVariable "TWS_fnc_isSupportAvailable";
    publicVariable "TWS_fnc_getCommCoverageReport";
    publicVariable "TWS_fnc_visualizeCommCoverage";
    
    systemChat "[TWS] Communication Grid system initialized";
    diag_log "[TWS] Communication Grid system initialized";
};
