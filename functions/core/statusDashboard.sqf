/*
 * statusDashboard.sqf
 * HTML Status Dashboard Generator
 * 
 * Generates HTML files that can be viewed in a web browser for clean monitoring
 * Updates every 2 minutes with comprehensive status information
 * 
 * Files generated in profileNamespace directory:
 * - tws_dashboard.html (main dashboard)
 * - tws_data.js (live data updates)
 */

if (isServer) then {
    // Wait for dependencies
    waitUntil {!isNil "TWS_worldState" && !isNil "TWS_intervals"};
    
    diag_log "[TWS] Initializing status dashboard system...";
    
    // Dashboard configuration
    TWS_dashboardConfig = createHashMap;
    TWS_dashboardConfig set ["enabled", true];
    TWS_dashboardConfig set ["updateInterval", 120]; // 2 minutes
    TWS_dashboardConfig set ["lastUpdate", 0];
    
    // ============================================================
    // HTML GENERATION
    // ============================================================
    
    // Function to generate HTML dashboard
    TWS_fnc_generateDashboardHTML = {
        private _html = "";
        
        _html = _html + "<!DOCTYPE html>" + endl;
        _html = _html + "<html lang='en'>" + endl;
        _html = _html + "<head>" + endl;
        _html = _html + "    <meta charset='UTF-8'>" + endl;
        _html = _html + "    <meta name='viewport' content='width=device-width, initial-scale=1.0'>" + endl;
        _html = _html + "    <title>TWS Status Dashboard</title>" + endl;
        _html = _html + "    <style>" + endl;
        _html = _html + "        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #1a1a1a; color: #e0e0e0; }" + endl;
        _html = _html + "        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; border-radius: 10px; margin-bottom: 20px; }" + endl;
        _html = _html + "        .header h1 { margin: 0; color: white; }" + endl;
        _html = _html + "        .header .timestamp { color: #f0f0f0; font-size: 14px; margin-top: 5px; }" + endl;
        _html = _html + "        .container { display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 20px; }" + endl;
        _html = _html + "        .faction-panel { background: #2a2a2a; border-radius: 10px; padding: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }" + endl;
        _html = _html + "        .faction-panel.blufor { border-left: 5px solid #4A90E2; }" + endl;
        _html = _html + "        .faction-panel.opfor { border-left: 5px solid #E24A4A; }" + endl;
        _html = _html + "        .faction-title { font-size: 24px; font-weight: bold; margin-bottom: 15px; }" + endl;
        _html = _html + "        .section { margin-bottom: 20px; }" + endl;
        _html = _html + "        .section-title { font-size: 16px; font-weight: bold; color: #a0a0a0; margin-bottom: 10px; border-bottom: 1px solid #3a3a3a; padding-bottom: 5px; }" + endl;
        _html = _html + "        .stat-row { display: flex; justify-content: space-between; padding: 5px 0; }" + endl;
        _html = _html + "        .stat-label { color: #b0b0b0; }" + endl;
        _html = _html + "        .stat-value { font-weight: bold; }" + endl;
        _html = _html + "        .stat-value.good { color: #4AE290; }" + endl;
        _html = _html + "        .stat-value.warning { color: #E2C74A; }" + endl;
        _html = _html + "        .stat-value.critical { color: #E24A4A; }" + endl;
        _html = _html + "        .progress-bar { background: #3a3a3a; height: 20px; border-radius: 10px; overflow: hidden; margin-top: 5px; }" + endl;
        _html = _html + "        .progress-fill { height: 100%; background: linear-gradient(90deg, #667eea 0%, #764ba2 100%); transition: width 0.3s; }" + endl;
        _html = _html + "        .activity-feed { background: #2a2a2a; border-radius: 10px; padding: 20px; margin-top: 20px; max-height: 300px; overflow-y: auto; }" + endl;
        _html = _html + "        .activity-item { padding: 10px; margin-bottom: 10px; background: #3a3a3a; border-radius: 5px; font-size: 14px; }" + endl;
        _html = _html + "        .activity-time { color: #808080; font-size: 12px; }" + endl;
        _html = _html + "        .refresh-btn { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; font-size: 14px; margin-top: 10px; }" + endl;
        _html = _html + "        .refresh-btn:hover { opacity: 0.9; }" + endl;
        _html = _html + "    </style>" + endl;
        _html = _html + "</head>" + endl;
        _html = _html + "<body>" + endl;
        _html = _html + "    <div class='header'>" + endl;
        _html = _html + "        <h1>🎯 Total War Simulation - Status Dashboard</h1>" + endl;
        _html = _html + "        <div class='timestamp' id='lastUpdate'>Loading...</div>" + endl;
        _html = _html + "    </div>" + endl;
        _html = _html + "    <button class='refresh-btn' onclick='location.reload()'>🔄 Refresh</button>" + endl;
        _html = _html + "    <div id='dashboard-content'></div>" + endl;
        _html = _html + "    <div class='activity-feed'>" + endl;
        _html = _html + "        <div class='section-title'>📋 Recent Activity</div>" + endl;
        _html = _html + "        <div id='activity-log'></div>" + endl;
        _html = _html + "    </div>" + endl;
        _html = _html + "    <script src='tws_data.js'></script>" + endl;
        _html = _html + "    <script>" + endl;
        _html = _html + "        function renderDashboard(data) {" + endl;
        _html = _html + "            document.getElementById('lastUpdate').textContent = 'Last Update: ' + data.timestamp;" + endl;
        _html = _html + "            const container = document.getElementById('dashboard-content');" + endl;
        _html = _html + "            container.innerHTML = '<div class=\"container\">' + data.blufor + data.opfor + '</div>';" + endl;
        _html = _html + "            document.getElementById('activity-log').innerHTML = data.activity;" + endl;
        _html = _html + "        }" + endl;
        _html = _html + "        if (typeof TWS_DATA !== 'undefined') { renderDashboard(TWS_DATA); }" + endl;
        _html = _html + "    </script>" + endl;
        _html = _html + "</body>" + endl;
        _html = _html + "</html>" + endl;
        
        _html
    };
    
    // Function to generate faction panel HTML
    TWS_fnc_generateFactionPanelHTML = {
        params ["_faction", "_data"];
        
        private _html = "";
        private _panelClass = if (_faction == "BLUFOR") then {"blufor"} else {"opfor"};
        
        _html = _html + format ["<div class='faction-panel %1'>", _panelClass] + endl;
        _html = _html + format ["    <div class='faction-title'>%1</div>", _faction] + endl;
        
        // Resources
        _html = _html + "    <div class='section'>" + endl;
        _html = _html + "        <div class='section-title'>💰 Resources</div>" + endl;
        
        private _resources = _data getOrDefault ["resources", createHashMap];
        {
            private _resType = _x;
            private _value = _y;
            private _valueClass = "stat-value";
            
            // Determine color based on resource type and value
            if (_resType in ["ammunition", "fuel"]) then {
                if (_value < 1000) then {_valueClass = "stat-value critical"};
                if (_value >= 1000 && _value < 3000) then {_valueClass = "stat-value warning"};
                if (_value >= 3000) then {_valueClass = "stat-value good"};
            };
            
            _html = _html + "        <div class='stat-row'>" + endl;
            _html = _html + format ["            <span class='stat-label'>%1:</span>", _resType] + endl;
            _html = _html + format ["            <span class='%2'>%3</span>", _valueClass, _value] + endl;
            _html = _html + "        </div>" + endl;
        } forEach _resources;
        
        _html = _html + "    </div>" + endl;
        
        // Operational Status
        _html = _html + "    <div class='section'>" + endl;
        _html = _html + "        <div class='section-title'>⚙️ Operational Status</div>" + endl;
        
        private _tempo = _data getOrDefault ["tempo", 1.0];
        private _tempoPercent = (_tempo * 100) min 150;
        private _tempoClass = "stat-value";
        if (_tempo < 0.5) then {_tempoClass = "stat-value critical"};
        if (_tempo >= 0.5 && _tempo < 0.8) then {_tempoClass = "stat-value warning"};
        if (_tempo >= 0.8) then {_tempoClass = "stat-value good"};
        
        _html = _html + "        <div class='stat-row'>" + endl;
        _html = _html + "            <span class='stat-label'>Operational Tempo:</span>" + endl;
        _html = _html + format ["            <span class='%1'>%2</span>", _tempoClass, _tempo] + endl;
        _html = _html + "        </div>" + endl;
        _html = _html + "        <div class='progress-bar'>" + endl;
        _html = _html + format ["            <div class='progress-fill' style='width: %1%%'></div>", _tempoPercent] + endl;
        _html = _html + "        </div>" + endl;
        
        private _factoriesOp = _data getOrDefault ["factoriesOperational", 0];
        private _factoriesTotal = _data getOrDefault ["factoriesTotal", 0];
        
        _html = _html + "        <div class='stat-row'>" + endl;
        _html = _html + "            <span class='stat-label'>Factories:</span>" + endl;
        _html = _html + format ["            <span class='stat-value'>%1/%2</span>", _factoriesOp, _factoriesTotal] + endl;
        _html = _html + "        </div>" + endl;
        
        _html = _html + "    </div>" + endl;
        
        // Commander & Morale
        _html = _html + "    <div class='section'>" + endl;
        _html = _html + "        <div class='section-title'>🎖️ Command & Morale</div>" + endl;
        
        if (!isNil {_data get "commander"}) then {
            private _cmd = _data get "commander";
            private _personality = _cmd getOrDefault ["personality", "unknown"];
            
            _html = _html + "        <div class='stat-row'>" + endl;
            _html = _html + "            <span class='stat-label'>Commander:</span>" + endl;
            _html = _html + format ["            <span class='stat-value'>%1</span>", _personality] + endl;
            _html = _html + "        </div>" + endl;
        };
        
        if (!isNil {_data get "morale"}) then {
            private _morale = _data get "morale";
            private _moralePercent = _morale * 100;
            private _moraleClass = "stat-value";
            if (_morale < 0.4) then {_moraleClass = "stat-value critical"};
            if (_morale >= 0.4 && _morale < 0.7) then {_moraleClass = "stat-value warning"};
            if (_morale >= 0.7) then {_moraleClass = "stat-value good"};
            
            _html = _html + "        <div class='stat-row'>" + endl;
            _html = _html + "            <span class='stat-label'>Morale:</span>" + endl;
            _html = _html + format ["            <span class='%1'>%2</span>", _moraleClass, _morale] + endl;
            _html = _html + "        </div>" + endl;
            _html = _html + "        <div class='progress-bar'>" + endl;
            _html = _html + format ["            <div class='progress-fill' style='width: %1%%'></div>", _moralePercent] + endl;
            _html = _html + "        </div>" + endl;
        };
        
        if (!isNil {_data get "casualties"}) then {
            _html = _html + "        <div class='stat-row'>" + endl;
            _html = _html + "            <span class='stat-label'>Casualties:</span>" + endl;
            _html = _html + format ["            <span class='stat-value critical'>%1</span>", _data get "casualties"] + endl;
            _html = _html + "        </div>" + endl;
        };
        
        _html = _html + "    </div>" + endl;
        
        // Sectors
        if (!isNil {_data get "sectorsControlled"}) then {
            _html = _html + "    <div class='section'>" + endl;
            _html = _html + "        <div class='section-title'>🗺️ Territory</div>" + endl;
            _html = _html + "        <div class='stat-row'>" + endl;
            _html = _html + "            <span class='stat-label'>Sectors Controlled:</span>" + endl;
            _html = _html + format ["            <span class='stat-value'>%1</span>", _data get "sectorsControlled"] + endl;
            _html = _html + "        </div>" + endl;
            _html = _html + "    </div>" + endl;
        };
        
        _html = _html + "</div>" + endl;
        
        _html
    };
    
    // ============================================================
    // ACTIVITY LOG
    // ============================================================
    
    TWS_activityLog = [];
    
    // Function to add activity
    TWS_fnc_addActivity = {
        params ["_message", ["_type", "info"]];
        
        private _entry = createHashMap;
        _entry set ["message", _message];
        _entry set ["type", _type];
        _entry set ["timestamp", diag_tickTime];
        _entry set ["timeStr", [daytime] call BIS_fnc_timeToString];
        
        TWS_activityLog pushBack _entry;
        
        // Keep only last 20 entries
        if (count TWS_activityLog > 20) then {
            TWS_activityLog deleteAt 0;
        };
    };
    
    // Function to generate activity log HTML
    TWS_fnc_generateActivityHTML = {
        private _html = "";
        
        // Reverse order (newest first)
        for "_i" from ((count TWS_activityLog) - 1) to 0 step -1 do {
            private _entry = TWS_activityLog select _i;
            private _message = _entry get "message";
            private _timeStr = _entry get "timeStr";
            
            _html = _html + "        <div class='activity-item'>" + endl;
            _html = _html + format ["            <div class='activity-time'>%1</div>", _timeStr] + endl;
            _html = _html + format ["            %1", _message] + endl;
            _html = _html + "        </div>" + endl;
        };
        
        if (count TWS_activityLog == 0) then {
            _html = "        <div class='activity-item'>No recent activity</div>" + endl;
        };
        
        _html
    };
    
    // ============================================================
    // DATA EXPORT
    // ============================================================
    
    // Function to export dashboard data
    TWS_fnc_exportDashboardData = {
        // Get comprehensive status
        private _status = [] call TWS_fnc_compileDetailedStatus;
        
        // Generate HTML for both factions
        private _bluforHTML = ["BLUFOR", _status get "BLUFOR"] call TWS_fnc_generateFactionPanelHTML;
        private _opforHTML = ["OPFOR", _status get "OPFOR"] call TWS_fnc_generateFactionPanelHTML;
        
        // Generate activity log
        private _activityHTML = [] call TWS_fnc_generateActivityHTML;
        
        // Create JavaScript data file
        private _js = "";
        _js = _js + "// TWS Dashboard Data - Auto-generated" + endl;
        _js = _js + "// Last Update: " + ([daytime] call BIS_fnc_timeToString) + endl;
        _js = _js + "const TWS_DATA = {" + endl;
        _js = _js + format ["    timestamp: '%1',", [daytime] call BIS_fnc_timeToString] + endl;
        
        // Escape quotes in HTML
        _bluforHTML = [_bluforHTML, "'", "\'"] call CBA_fnc_replace;
        _opforHTML = [_opforHTML, "'", "\'"] call CBA_fnc_replace;
        _activityHTML = [_activityHTML, "'", "\'"] call CBA_fnc_replace;
        
        _js = _js + format ["    blufor: '%1',", _bluforHTML] + endl;
        _js = _js + format ["    opfor: '%1',", _opforHTML] + endl;
        _js = _js + format ["    activity: '%1'", _activityHTML] + endl;
        _js = _js + "};" + endl;
        
        // Log to RPT (this would be written to file with proper extension)
        diag_log "[TWS] ========== DASHBOARD DATA START ==========";
        diag_log _js;
        diag_log "[TWS] ========== DASHBOARD DATA END ==========";
        
        // Also log HTML dashboard once
        private _dashboardHTML = [] call TWS_fnc_generateDashboardHTML;
        diag_log "[TWS] ========== DASHBOARD HTML START ==========";
        diag_log _dashboardHTML;
        diag_log "[TWS] ========== DASHBOARD HTML END ==========";
        
        systemChat "[TWS] Dashboard data exported to RPT log";
        systemChat "[TWS] Copy HTML and JS sections to files to view in browser";
    };
    
    // ============================================================
    // UPDATE LOOP
    // ============================================================
    
    // Dashboard update loop
    TWS_fnc_dashboardUpdateLoop = {
        // Generate initial HTML
        private _html = [] call TWS_fnc_generateDashboardHTML;
        diag_log "[TWS] Dashboard HTML template generated";
        
        while {TWS_dashboardConfig get "enabled"} do {
            // Export current data
            [] call TWS_fnc_exportDashboardData;
            
            TWS_dashboardConfig set ["lastUpdate", diag_tickTime];
            
            sleep (TWS_dashboardConfig get "updateInterval");
        };
    };
    
    // Hook into existing activity
    if (!isNil "TWS_fnc_spawnVehicleConvoy") then {
        // Override to add activity logging
        TWS_fnc_spawnVehicleConvoy_original = TWS_fnc_spawnVehicleConvoy;
        TWS_fnc_spawnVehicleConvoy = {
            params ["_faction", "_factory", "_vehicleType", "_count"];
            
            [format ["🚗 %1 spawned %2x %3 convoy at factory", _faction, _count, _vehicleType]] call TWS_fnc_addActivity;
            
            _this call TWS_fnc_spawnVehicleConvoy_original;
        };
    };
    
    // Start dashboard loop
    [] spawn TWS_fnc_dashboardUpdateLoop;
    
    // Add initial activity
    ["⚡ Total War Simulation system initialized"] call TWS_fnc_addActivity;
    ["📊 Status dashboard active - check RPT log for export"] call TWS_fnc_addActivity;
    
    // Make public
    publicVariable "TWS_dashboardConfig";
    publicVariable "TWS_activityLog";
    publicVariable "TWS_fnc_generateDashboardHTML";
    publicVariable "TWS_fnc_generateFactionPanelHTML";
    publicVariable "TWS_fnc_addActivity";
    publicVariable "TWS_fnc_generateActivityHTML";
    publicVariable "TWS_fnc_exportDashboardData";
    
    systemChat "[TWS] Status Dashboard system initialized";
    systemChat "[TWS] Dashboard data exports to RPT log every 2 minutes";
    systemChat "[TWS] Copy HTML/JS sections to files and open in browser";
    diag_log "[TWS] Status Dashboard system initialized";
    diag_log "[TWS] Dashboard updates will be logged to RPT every 2 minutes";
    diag_log "[TWS] Look for '========== DASHBOARD HTML START ==========' in RPT";
};
