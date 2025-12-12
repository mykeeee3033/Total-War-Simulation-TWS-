/*
 * enhancedMonitoring.sqf
 * Enhanced Monitoring and Debug System
 * 
 * Provides detailed updates every 2 minutes on all aspects of the simulation
 * Includes support for external monitoring via HTTP (requires extension)
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_intervals"};
    
    // Enhanced monitoring configuration
    TWS_monitoringConfig = createHashMap;
    TWS_monitoringConfig set ["enabled", true];
    TWS_monitoringConfig set ["verboseLogging", true];
    TWS_monitoringConfig set ["exportToFile", false]; // Requires file extension
    TWS_monitoringConfig set ["httpMonitoring", false]; // Requires HTTP extension
    TWS_monitoringConfig set ["httpEndpoint", "http://localhost:8080/tws"];
    
    // Monitoring statistics
    TWS_monitoringStats = createHashMap;
    TWS_monitoringStats set ["updateCount", 0];
    TWS_monitoringStats set ["lastUpdate", 0];
    
    // Function to compile comprehensive status
    TWS_fnc_compileDetailedStatus = {
        private _status = createHashMap;
        _status set ["timestamp", diag_tickTime];
        _status set ["missionTime", time];
        
        // Compile data for each faction
        {
            private _faction = _x;
            private _factionData = createHashMap;
            
            // ========== RESOURCES ==========
            private _resources = [_faction] call TWS_fnc_getResources;
            _factionData set ["resources", _resources];
            
            // ========== OPERATIONAL STATUS ==========
            private _tempo = [_faction] call TWS_fnc_getTempo;
            _factionData set ["tempo", _tempo];
            
            // ========== COMMANDER STATUS ==========
            if (!isNil "TWS_commanders") then {
                private _commander = TWS_commanders getOrDefault [_faction, createHashMap];
                _factionData set ["commander", _commander];
            };
            
            // ========== FACTORY STATUS ==========
            private _factories = TWS_worldState get "factories";
            private _factoryStatus = createHashMap;
            private _operationalCount = 0;
            private _totalCount = 0;
            {
                private _data = _y;
                if ((_data get "faction") == _faction) then {
                    _totalCount = _totalCount + 1;
                    if (_data get "operational") then {
                        _operationalCount = _operationalCount + 1;
                        private _type = _data get "type";
                        private _count = _factoryStatus getOrDefault [_type, 0];
                        _factoryStatus set [_type, _count + 1];
                    };
                };
            } forEach _factories;
            _factionData set ["factories", _factoryStatus];
            _factionData set ["factoriesOperational", _operationalCount];
            _factionData set ["factoriesTotal", _totalCount];
            
            // ========== RADAR & AIR DEFENSE ==========
            if (!isNil "TWS_fnc_getAirDefenseReadiness") then {
                private _airDefense = [_faction] call TWS_fnc_getAirDefenseReadiness;
                _factionData set ["airDefense", _airDefense];
            };
            
            // ========== CASUALTIES ==========
            if (!isNil "factionStats") then {
                {
                    if (_x select 0 == _faction) then {
                        _factionData set ["casualties", _x select 1];
                    };
                } forEach factionStats;
            };
            
            // ========== MORALE (if implemented) ==========
            if (!isNil "TWS_morale") then {
                private _morale = TWS_morale getOrDefault [_faction, 0.7];
                _factionData set ["morale", _morale];
            };
            
            // ========== SECTORS (if implemented) ==========
            if (!isNil "TWS_sectors") then {
                private _sectorControl = TWS_sectors getOrDefault [_faction, []];
                _factionData set ["sectorsControlled", count _sectorControl];
            };
            
            _status set [_faction, _factionData];
        } forEach ["BLUFOR", "OPFOR"];
        
        _status
    };
    
    // Function to format status as readable text
    TWS_fnc_formatDetailedStatus = {
        params ["_status"];
        
        private _text = "";
        _text = _text + "============================================" + endl;
        _text = _text + format ["TWS STATUS UPDATE - %1" + endl, time];
        _text = _text + "============================================" + endl;
        
        {
            private _faction = _x;
            private _data = _y;
            
            _text = _text + endl;
            _text = _text + format ["========== %1 ==========" + endl, _faction];
            
            // Resources
            private _resources = _data get "resources";
            _text = _text + "RESOURCES:" + endl;
            {
                _text = _text + format ["  %1: %2" + endl, _x, _y];
            } forEach _resources;
            
            // Operational Status
            _text = _text + endl + "OPERATIONAL:" + endl;
            _text = _text + format ["  Tempo: %1" + endl, _data getOrDefault ["tempo", "N/A"]];
            _text = _text + format ["  Factories: %1/%2 operational" + endl, 
                _data getOrDefault ["factoriesOperational", 0],
                _data getOrDefault ["factoriesTotal", 0]];
            
            // Commander
            if (!isNil {_data get "commander"}) then {
                private _cmd = _data get "commander";
                _text = _text + format ["  Commander Personality: %1" + endl, _cmd getOrDefault ["personality", "N/A"]];
                _text = _text + format ["  Aggressiveness: %1" + endl, _cmd getOrDefault ["aggressiveness", "N/A"]];
            };
            
            // Casualties
            if (!isNil {_data get "casualties"}) then {
                _text = _text + format ["  Total Casualties: %1" + endl, _data get "casualties"];
            };
            
            // Air Defense
            if (!isNil {_data get "airDefense"}) then {
                private _ad = _data get "airDefense";
                _text = _text + format ["  Air Defense Readiness: %1" + endl, _ad getOrDefault ["readinessScore", "N/A"]];
            };
            
            // Morale
            if (!isNil {_data get "morale"}) then {
                _text = _text + format ["  Morale: %1" + endl, _data get "morale"];
            };
            
        } forEach _status;
        
        _text = _text + endl + "============================================" + endl;
        _text
    };
    
    // Function to export status (HTTP or file)
    TWS_fnc_exportStatus = {
        params ["_status"];
        
        // Export to HTTP if enabled
        if (TWS_monitoringConfig get "httpMonitoring") then {
            // Requires extension like "arma3-http-server" or similar
            // This is a placeholder for the HTTP call
            private _endpoint = TWS_monitoringConfig get "httpEndpoint";
            private _jsonData = str _status;
            
            // Example HTTP call (requires extension)
            // ["POST", _endpoint, _jsonData] call TWS_fnc_httpRequest;
            
            diag_log format ["[TWS] Would export to HTTP: %1", _endpoint];
        };
        
        // Export to file if enabled
        if (TWS_monitoringConfig get "exportToFile") then {
            // Requires file writing extension
            // This is a placeholder
            diag_log "[TWS] Would export to file: tws_status.json";
        };
    };
    
    // Function to display concise status update
    TWS_fnc_displayStatusUpdate = {
        params ["_status"];
        
        private _updateNum = (TWS_monitoringStats get "updateCount") + 1;
        TWS_monitoringStats set ["updateCount", _updateNum];
        TWS_monitoringStats set ["lastUpdate", time];
        
        // System chat summary
        systemChat format ["========== TWS Update #%1 ==========", _updateNum];
        
        {
            private _faction = _x;
            private _data = _y;
            
            private _resources = _data get "resources";
            private _ammo = _resources getOrDefault ["ammunition", 0];
            private _fuel = _resources getOrDefault ["fuel", 0];
            private _tempo = _data getOrDefault ["tempo", 1.0];
            
            systemChat format ["%1: Tempo=%2 | Ammo=%3 | Fuel=%4", _faction, _tempo, _ammo, _fuel];
            
            if (!isNil {_data get "commander"}) then {
                private _cmd = _data get "commander";
                private _personality = _cmd getOrDefault ["personality", "unknown"];
                systemChat format ["  Commander: %1", _personality];
            };
            
            private _factories = _data getOrDefault ["factoriesOperational", 0];
            private _factoriesTotal = _data getOrDefault ["factoriesTotal", 0];
            if (_factoriesTotal > 0) then {
                systemChat format ["  Factories: %1/%2", _factories, _factoriesTotal];
            };
            
        } forEach _status;
        
        systemChat "====================================";
    };
    
    // Enhanced monitoring loop
    TWS_fnc_enhancedMonitoringLoop = {
        private _interval = ["DebugUpdateInterval"] call TWS_fnc_getInterval;
        
        while {TWS_monitoringConfig get "enabled"} do {
            // Compile status
            private _status = [] call TWS_fnc_compileDetailedStatus;
            
            // Display in-game
            [_status] call TWS_fnc_displayStatusUpdate;
            
            // Verbose logging
            if (TWS_monitoringConfig get "verboseLogging") then {
                private _text = [_status] call TWS_fnc_formatDetailedStatus;
                diag_log _text;
            };
            
            // Export if enabled
            [_status] call TWS_fnc_exportStatus;
            
            // Wait for next update
            sleep _interval;
        };
    };
    
    // Function to enable/disable monitoring
    TWS_fnc_toggleMonitoring = {
        params ["_enable"];
        
        TWS_monitoringConfig set ["enabled", _enable];
        
        if (_enable) then {
            systemChat "[TWS] Enhanced monitoring enabled";
            [] spawn TWS_fnc_enhancedMonitoringLoop;
        } else {
            systemChat "[TWS] Enhanced monitoring disabled";
        };
    };
    
    // Function to get monitoring statistics
    TWS_fnc_getMonitoringStats = {
        TWS_monitoringStats
    };
    
    // Start monitoring
    [] spawn TWS_fnc_enhancedMonitoringLoop;
    
    // Make public
    publicVariable "TWS_monitoringConfig";
    publicVariable "TWS_monitoringStats";
    publicVariable "TWS_fnc_compileDetailedStatus";
    publicVariable "TWS_fnc_formatDetailedStatus";
    publicVariable "TWS_fnc_exportStatus";
    publicVariable "TWS_fnc_displayStatusUpdate";
    publicVariable "TWS_fnc_toggleMonitoring";
    publicVariable "TWS_fnc_getMonitoringStats";
    
    systemChat "[TWS] Enhanced monitoring system started";
    systemChat format ["[TWS] Updates every %1 seconds", ["DebugUpdateInterval"] call TWS_fnc_getInterval];
    diag_log "[TWS] Enhanced monitoring system initialized";
};
