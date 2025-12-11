// npc_analyzer.sqf
// Analyzes all NPCs on the map and returns data on their health, ammo, status, and position

// Initialize global variables
if (isNil "npcAnalyzerInterval") then { npcAnalyzerInterval = 60; }; // Default: 60 seconds
if (isNil "npcAnalyzerEnabled") then { npcAnalyzerEnabled = true; };
if (isNil "npcAnalysisData") then { npcAnalysisData = []; };

// Helper function to get faction name
npcAnalyzer_getFactionName = {
    params ["_side"];
    switch (_side) do {
        case west: {"BLUFOR"};
        case east: {"OPFOR"};
        case resistance: {"INDEPENDENT"};
        case civilian: {"CIVILIAN"};
        default {"UNKNOWN"};
    };
};

// Helper function to get unit status
npcAnalyzer_getUnitStatus = {
    params ["_unit"];
    private _statusArray = [];
    
    if (!alive _unit) then {
        _statusArray pushBack "DEAD";
    } else {
        _statusArray pushBack "ALIVE";
        
        if (lifeState _unit == "INCAPACITATED") then {
            _statusArray pushBack "INCAPACITATED";
        };
        
        if (vehicle _unit != _unit) then {
            _statusArray pushBack format["IN_VEHICLE:%1", typeOf vehicle _unit];
        };
        
        if (behaviour _unit == "COMBAT") then {
            _statusArray pushBack "IN_COMBAT";
        };
        
        if (currentWeapon _unit != "") then {
            _statusArray pushBack format["WEAPON:%1", currentWeapon _unit];
        };
    };
    
    _statusArray
};

// Main analysis function
npcAnalyzer_analyzeAll = {
    private _allUnits = allUnits;
    private _timestamp = diag_tickTime;
    private _analysisData = [];
    
    // Organize by faction
    private _factionData = [
        ["BLUFOR", []],
        ["OPFOR", []],
        ["INDEPENDENT", []],
        ["CIVILIAN", []]
    ];
    
    {
        private _unit = _x;
        private _side = side group _unit;
        private _faction = [_side] call npcAnalyzer_getFactionName;
        private _pos = getPos _unit;
        private _health = 1 - (damage _unit); // 1 = full health, 0 = dead
        private _ammoCount = count magazines _unit;
        private _status = [_unit] call npcAnalyzer_getUnitStatus;
        
        private _unitData = [
            ["id", str _unit],
            ["name", name _unit],
            ["type", typeOf _unit],
            ["position", _pos],
            ["health", _health],
            ["damage", damage _unit],
            ["ammo_count", _ammoCount],
            ["status", _status],
            ["group", groupId group _unit],
            ["faction", _faction]
        ];
        
        // Add to appropriate faction array
        {
            if (_x select 0 == _faction) then {
                (_x select 1) pushBack _unitData;
            };
        } forEach _factionData;
        
    } forEach _allUnits;
    
    // Calculate statistics
    private _totalUnits = count _allUnits;
    private _stats = [];
    
    {
        private _factionName = _x select 0;
        private _units = _x select 1;
        private _count = count _units;
        private _aliveCount = 0;
        private _deadCount = 0;
        private _avgHealth = 0;
        private _avgAmmo = 0;
        private _inCombatCount = 0;
        
        {
            private _unitData = _x;
            private _unitStatus = {if (_x select 0 == "status") exitWith {_x select 1}} forEach _unitData;
            private _unitHealth = {if (_x select 0 == "health") exitWith {_x select 1}} forEach _unitData;
            private _unitAmmo = {if (_x select 0 == "ammo_count") exitWith {_x select 1}} forEach _unitData;
            
            if ("ALIVE" in _unitStatus) then {
                _aliveCount = _aliveCount + 1;
                _avgHealth = _avgHealth + _unitHealth;
                _avgAmmo = _avgAmmo + _unitAmmo;
            } else {
                _deadCount = _deadCount + 1;
            };
            
            if ("IN_COMBAT" in _unitStatus) then {
                _inCombatCount = _inCombatCount + 1;
            };
        } forEach _units;
        
        if (_aliveCount > 0) then {
            _avgHealth = _avgHealth / _aliveCount;
            _avgAmmo = _avgAmmo / _aliveCount;
        };
        
        private _factionStats = [
            ["faction", _factionName],
            ["total", _count],
            ["alive", _aliveCount],
            ["dead", _deadCount],
            ["avg_health", _avgHealth],
            ["avg_ammo", _avgAmmo],
            ["in_combat", _inCombatCount]
        ];
        
        _stats pushBack _factionStats;
    } forEach _factionData;
    
    // Build final data structure
    _analysisData = [
        ["timestamp", _timestamp],
        ["total_units", _totalUnits],
        ["statistics", _stats],
        ["factions", _factionData]
    ];
    
    // Store globally
    npcAnalysisData = _analysisData;
    
    _analysisData
};

// Function to format and display analysis
npcAnalyzer_displayAnalysis = {
    params [["_data", npcAnalysisData]];
    
    private _timestamp = {if (_x select 0 == "timestamp") exitWith {_x select 1}} forEach _data;
    private _totalUnits = {if (_x select 0 == "total_units") exitWith {_x select 1}} forEach _data;
    private _statistics = {if (_x select 0 == "statistics") exitWith {_x select 1}} forEach _data;
    
    systemChat "=== NPC ANALYSIS REPORT ===";
    systemChat format ["Timestamp: %1", _timestamp];
    systemChat format ["Total Units: %1", _totalUnits];
    systemChat "---";
    
    {
        private _factionStats = _x;
        private _faction = {if (_x select 0 == "faction") exitWith {_x select 1}} forEach _factionStats;
        private _total = {if (_x select 0 == "total") exitWith {_x select 1}} forEach _factionStats;
        private _alive = {if (_x select 0 == "alive") exitWith {_x select 1}} forEach _factionStats;
        private _dead = {if (_x select 0 == "dead") exitWith {_x select 1}} forEach _factionStats;
        private _avgHealth = {if (_x select 0 == "avg_health") exitWith {_x select 1}} forEach _factionStats;
        private _avgAmmo = {if (_x select 0 == "avg_ammo") exitWith {_x select 1}} forEach _factionStats;
        private _inCombat = {if (_x select 0 == "in_combat") exitWith {_x select 1}} forEach _factionStats;
        
        systemChat format ["%1: Total=%2 | Alive=%3 | Dead=%4", _faction, _total, _alive, _dead];
        systemChat format ["  Avg Health=%.2f | Avg Ammo=%1 | In Combat=%2", _avgHealth, _avgAmmo, _inCombat];
    } forEach _statistics;
    
    systemChat "===========================";
};

// Function to write analysis to diary
npcAnalyzer_writeToDiary = {
    params [["_data", npcAnalysisData]];
    
    private _timestamp = {if (_x select 0 == "timestamp") exitWith {_x select 1}} forEach _data;
    private _totalUnits = {if (_x select 0 == "total_units") exitWith {_x select 1}} forEach _data;
    private _statistics = {if (_x select 0 == "statistics") exitWith {_x select 1}} forEach _data;
    
    private _diaryText = "<font size='16'><b>NPC ANALYSIS REPORT</b></font><br/>";
    _diaryText = _diaryText + format ["<font size='12'>Timestamp: %1</font><br/>", _timestamp];
    _diaryText = _diaryText + format ["<font size='12'>Total Units: %1</font><br/><br/>", _totalUnits];
    
    {
        private _factionStats = _x;
        private _faction = {if (_x select 0 == "faction") exitWith {_x select 1}} forEach _factionStats;
        private _total = {if (_x select 0 == "total") exitWith {_x select 1}} forEach _factionStats;
        private _alive = {if (_x select 0 == "alive") exitWith {_x select 1}} forEach _factionStats;
        private _dead = {if (_x select 0 == "dead") exitWith {_x select 1}} forEach _factionStats;
        private _avgHealth = {if (_x select 0 == "avg_health") exitWith {_x select 1}} forEach _factionStats;
        private _avgAmmo = {if (_x select 0 == "avg_ammo") exitWith {_x select 1}} forEach _factionStats;
        private _inCombat = {if (_x select 0 == "in_combat") exitWith {_x select 1}} forEach _factionStats;
        
        _diaryText = _diaryText + format ["<font size='14' color='#00FF00'><b>%1</b></font><br/>", _faction];
        _diaryText = _diaryText + format ["Total: %1 | Alive: %2 | Dead: %3<br/>", _total, _alive, _dead];
        _diaryText = _diaryText + format ["Avg Health: %.2f | Avg Ammo: %1 | In Combat: %2<br/><br/>", _avgHealth, _avgAmmo, _inCombat];
    } forEach _statistics;
    
    player createDiaryRecord ["Diary", ["NPC Analysis", _diaryText]];
};

// Main monitoring loop
[] spawn {
    systemChat format ["[NPC ANALYZER] Starting analysis (interval: %1s)", npcAnalyzerInterval];
    
    while {npcAnalyzerEnabled} do {
        // Perform analysis
        private _data = call npcAnalyzer_analyzeAll;
        
        // Display results
        [_data] call npcAnalyzer_displayAnalysis;
        
        // Write to diary if player exists
        if (!isNull player) then {
            [_data] call npcAnalyzer_writeToDiary;
        };
        
        sleep npcAnalyzerInterval;
    };
    
    systemChat "[NPC ANALYZER] Stopped";
};

// Register commands for manual control
// Usage: call npcAnalyzer_analyzeNow;
npcAnalyzer_analyzeNow = {
    private _data = call npcAnalyzer_analyzeAll;
    [_data] call npcAnalyzer_displayAnalysis;
    if (!isNull player) then {
        [_data] call npcAnalyzer_writeToDiary;
    };
};

// Usage: npcAnalyzerEnabled = false; to stop monitoring
// Usage: npcAnalyzerInterval = 120; to change interval (requires restart)

systemChat "[NPC ANALYZER] Loaded. Use 'call npcAnalyzer_analyzeNow;' for manual analysis";
