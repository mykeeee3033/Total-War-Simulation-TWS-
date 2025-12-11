/*
 * chatGPTIntegration.sqf
 * Grand Strategy AI Layer
 * 
 * Purpose: ChatGPT acts as Grand Strategist above OPCOM
 * - ALiVE OPCOM = Tactical + Operational layer
 * - Commander AI = Operational + Strategic layer  
 * - ChatGPT = Grand Strategy layer
 * 
 * Generates periodic strategic reports and exports recommendations
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_commanders"};
    
    // ChatGPT integration configuration
    TWS_chatGPTConfig = createHashMap;
    TWS_chatGPTConfig set ["enabled", true];
    TWS_chatGPTConfig set ["reportInterval", 1800]; // 30 minutes
    TWS_chatGPTConfig set ["exportPath", "commanderReport.txt"];
    TWS_chatGPTConfig set ["exportJSON", true];
    
    // Function to compile strategic report
    TWS_fnc_compileStrategicReport = {
        private _report = createHashMap;
        _report set ["timestamp", diag_tickTime];
        _report set ["missionTime", time];
        _report set ["date", date];
        
        // Compile data for each faction
        private _factions = createHashMap;
        
        {
            private _faction = _x;
            private _factionData = createHashMap;
            
            // Resources
            private _resources = [_faction] call TWS_fnc_getResources;
            _factionData set ["resources", _resources];
            
            // Operational tempo
            private _tempo = [_faction] call TWS_fnc_getTempo;
            _factionData set ["tempo", _tempo];
            
            // Logistics status
            private _logStatus = [_faction] call TWS_fnc_getLogisticsStatus;
            _factionData set ["logistics", _logStatus];
            
            // Commander personality
            private _commander = TWS_commanders get _faction;
            _factionData set ["commander", _commander];
            
            // OPCOM recommendations
            private _opcomRec = [_faction] call TWS_fnc_getOPCOMRecommendations;
            _factionData set ["opcomRecommendations", _opcomRec];
            
            // Air defense readiness
            private _airDefense = [_faction] call TWS_fnc_getAirDefenseReadiness;
            _factionData set ["airDefense", _airDefense];
            
            // Factory status
            private _factories = TWS_worldState get "factories";
            private _factoryCount = 0;
            private _operationalFactories = 0;
            {
                private _data = _y;
                if ((_data get "faction") == _faction) then {
                    _factoryCount = _factoryCount + 1;
                    if (_data get "operational") then {
                        _operationalFactories = _operationalFactories + 1;
                    };
                };
            } forEach _factories;
            _factionData set ["totalFactories", _factoryCount];
            _factionData set ["operationalFactories", _operationalFactories];
            
            // Casualties (from combat_monitor.sqf integration)
            if (!isNil "factionStats") then {
                {
                    if (_x select 0 == _faction) then {
                        _factionData set ["casualties", _x select 1];
                    };
                } forEach factionStats;
            };
            
            _factions set [_faction, _factionData];
        } forEach ["BLUFOR", "OPFOR"];
        
        _report set ["factions", _factions];
        
        // World state
        private _worldSummary = [] call TWS_fnc_getWorldStateSummary;
        _report set ["worldState", _worldSummary];
        
        _report
    };
    
    // Function to format report as human-readable text
    TWS_fnc_formatReportText = {
        params ["_report"];
        
        private _text = "";
        _text = _text + "========================================" + endl;
        _text = _text + "STRATEGIC SITUATION REPORT" + endl;
        _text = _text + "========================================" + endl;
        _text = _text + format ["Mission Time: %1 seconds" + endl, _report get "missionTime"];
        _text = _text + format ["Report Generated: %1" + endl, _report get "timestamp"];
        _text = _text + endl;
        
        private _factions = _report get "factions";
        
        {
            private _faction = _x;
            private _data = _y;
            
            _text = _text + "----------------------------------------" + endl;
            _text = _text + format ["%1 SITUATION" + endl, _faction];
            _text = _text + "----------------------------------------" + endl;
            
            // Resources
            private _resources = _data get "resources";
            _text = _text + "RESOURCES:" + endl;
            _text = _text + format ["  Ammunition: %1" + endl, _resources getOrDefault ["ammunition", 0]];
            _text = _text + format ["  Fuel: %1" + endl, _resources getOrDefault ["fuel", 0]];
            _text = _text + format ["  Materials: %1" + endl, _resources getOrDefault ["materials", 0]];
            _text = _text + format ["  Vehicles: %1" + endl, _resources getOrDefault ["vehicles", 0]];
            _text = _text + format ["  Aircraft: %1" + endl, _resources getOrDefault ["aircraft", 0]];
            _text = _text + endl;
            
            // Operational status
            _text = _text + "OPERATIONAL STATUS:" + endl;
            _text = _text + format ["  Operational Tempo: %1" + endl, _data get "tempo"];
            _text = _text + format ["  Factories Operational: %1/%2" + endl, 
                _data get "operationalFactories", _data get "totalFactories"];
            
            private _airDef = _data get "airDefense";
            _text = _text + format ["  Radar Sites: %1" + endl, _airDef get "operationalRadars"];
            _text = _text + format ["  Air Defense Readiness: %1" + endl, _airDef get "readinessScore"];
            _text = _text + endl;
            
            // Commander status
            private _commander = _data get "commander";
            _text = _text + "COMMANDER STATUS:" + endl;
            _text = _text + format ["  Personality: %1" + endl, _commander get "personality"];
            _text = _text + format ["  Aggressiveness: %1" + endl, _commander get "aggressiveness"];
            
            private _opcomRec = _data get "opcomRecommendations";
            _text = _text + format ["  Recommended Aggro: %1" + endl, _opcomRec get "adjustedAggressiveness"];
            _text = _text + endl;
            
            // Casualties
            if (!isNil {_data get "casualties"}) then {
                _text = _text + format ["  Total Casualties: %1" + endl, _data get "casualties"];
                _text = _text + endl;
            };
            
        } forEach _factions;
        
        _text = _text + "========================================" + endl;
        _text = _text + "STRATEGIC RECOMMENDATIONS NEEDED:" + endl;
        _text = _text + "========================================" + endl;
        _text = _text + "1. Strategic shift recommendations" + endl;
        _text = _text + "2. Doctrine adjustments" + endl;
        _text = _text + "3. Priority target selection" + endl;
        _text = _text + "4. Force posture recommendations" + endl;
        _text = _text + "5. Logistical adjustments" + endl;
        _text = _text + endl;
        
        _text
    };
    
    // Function to export report to file
    TWS_fnc_exportReport = {
        params ["_report"];
        
        private _text = [_report] call TWS_fnc_formatReportText;
        
        // Save to file (requires file operations extension or manual copy)
        // For now, log to diary and system
        diag_log "========== STRATEGIC REPORT START ==========";
        diag_log _text;
        diag_log "========== STRATEGIC REPORT END ==========";
        
        // Also output to hint for visibility
        systemChat "[TWS] Strategic report generated - check RPT log";
        
        // If JSON export enabled, format as JSON-like structure
        if (TWS_chatGPTConfig get "exportJSON") then {
            private _json = str _report;
            diag_log format ["[TWS] JSON Report: %1", _json];
        };
        
        _text
    };
    
    // Function to apply strategic recommendations (manual or automated)
    TWS_fnc_applyRecommendations = {
        params ["_faction", "_recommendations"];
        
        // _recommendations is a hashmap with keys:
        // "personality", "productionPriority", "targetPriority", "posture"
        
        if (!isNil {_recommendations get "personality"}) then {
            private _personality = _recommendations get "personality";
            [_faction, _personality] call TWS_fnc_setCommanderPersonality;
        };
        
        if (!isNil {_recommendations get "posture"}) then {
            private _posture = _recommendations get "posture";
            // Apply force posture changes
            diag_log format ["[TWS] Applied posture recommendation for %1: %2", _faction, _posture];
        };
        
        if (!isNil {_recommendations get "productionPriority"}) then {
            private _priority = _recommendations get "productionPriority";
            // Adjust production priorities
            diag_log format ["[TWS] Applied production priority for %1: %2", _faction, _priority];
        };
        
        systemChat format ["[TWS] Strategic recommendations applied for %1", _faction];
    };
    
    // Periodic report generation loop
    TWS_fnc_strategicReportLoop = {
        while {TWS_chatGPTConfig get "enabled"} do {
            // Generate report
            private _report = [] call TWS_fnc_compileStrategicReport;
            
            // Export report
            [_report] call TWS_fnc_exportReport;
            
            // Wait for next report interval
            sleep (TWS_chatGPTConfig get "reportInterval");
        };
    };
    
    // Start report generation
    [] spawn TWS_fnc_strategicReportLoop;
    
    publicVariable "TWS_chatGPTConfig";
    publicVariable "TWS_fnc_compileStrategicReport";
    publicVariable "TWS_fnc_formatReportText";
    publicVariable "TWS_fnc_exportReport";
    publicVariable "TWS_fnc_applyRecommendations";
    
    systemChat "[TWS] ChatGPT Integration / Strategic Reporting initialized";
    diag_log "[TWS] ChatGPT Integration initialized - reports will generate every 30 minutes";
};
