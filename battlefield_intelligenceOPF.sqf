/*
 * Battlefield Intelligence - OPFOR Death Monitoring
 * 
 * Description: Monitors OPFOR casualties and tracks what killed them
 * Usage: [] execVM "battlefield_intelligenceOPF.sqf"
 * 
 * Features:
 * - Tracks OPFOR deaths only
 * - Identifies killer weapon/vehicle type
 * - Stores data for use by other scripts
 * 
 * Data Structure: BATTLE_opforDeaths
 */

if (!isServer) exitWith {
    diag_log "[BATTLE] Battlefield intelligence only runs on server";
};

diag_log "[BATTLE] Initializing OPFOR death monitoring...";

// ============================================================================
// DATA STORAGE
// ============================================================================

// Main death tracking database
if (isNil "BATTLE_opforDeaths") then {
    BATTLE_opforDeaths = createHashMap;
    
    // Death counters by killer type (simplified)
    BATTLE_opforDeaths set ["killedBy", createHashMap];
    (BATTLE_opforDeaths get "killedBy") set ["infantry", 0];
    (BATTLE_opforDeaths get "killedBy") set ["tank", 0];
    (BATTLE_opforDeaths get "killedBy") set ["apc", 0];
    (BATTLE_opforDeaths get "killedBy") set ["air", 0];
    (BATTLE_opforDeaths get "killedBy") set ["naval", 0];
    (BATTLE_opforDeaths get "killedBy") set ["unknown", 0];
    
    // Total death counter
    BATTLE_opforDeaths set ["totalDeaths", 0];
    
    // THREAT ASSESSMENT DATA for tactical decision making
    BATTLE_opforDeaths set ["threatAssessment", createHashMap];
    
    // Current threat levels (0-100 scale)
    private _threats = BATTLE_opforDeaths get "threatAssessment";
    _threats set ["infantry_threat", 0];
    _threats set ["armor_threat", 0];
    _threats set ["air_threat", 0];
    _threats set ["naval_threat", 0];
    
    // Recommended counter-assets (spawn weights 0-10)
    _threats set ["recommended_spawns", createHashMap];
    private _spawns = _threats get "recommended_spawns";
    _spawns set ["tanks", 0];           // Counter for armor/infantry
    _spawns set ["apcs", 0];            // Counter for infantry
    _spawns set ["infantry_at", 0];     // Counter for armor
    _spawns set ["air_attack", 0];      // Counter for ground threats
    _spawns set ["air_aa", 0];          // Counter for air threats
    _spawns set ["naval", 0];           // Counter for naval threats
    
    // Tactical priorities (what to focus on)
    _threats set ["primary_threat", "none"];
    _threats set ["threat_level", "low"];  // low, medium, high, critical
    
    // INTELLIGENCE RESET SYSTEM
    BATTLE_opforDeaths set ["resetInterval", 1800]; // 30 minutes - reset stats for current relevance
    BATTLE_opforDeaths set ["lastResetTime", time];
    BATTLE_opforDeaths set ["resetEnabled", true];
    
    publicVariable "BATTLE_opforDeaths";
};

// ============================================================================
// KILLER ANALYSIS FUNCTIONS
// ============================================================================

// Function: Analyze what killed the OPFOR soldier (simplified)
BATTLE_fnc_analyzeKiller = {
    params ["_unit", "_killer", "_instigator"];
    
    // Check if killer exists
    if (isNull _killer) exitWith {"unknown"};
    
    private _killerVehicle = vehicle _killer;
    
    // Analyze killer type - simplified categories
    if (_killer isKindOf "Man") exitWith {"infantry"};
    
    if (_killerVehicle isKindOf "Tank") exitWith {"tank"};
    
    if (_killerVehicle isKindOf "Wheeled_APC_F" || _killerVehicle isKindOf "Tracked_APC_F") exitWith {"apc"};
    
    if (_killerVehicle isKindOf "Helicopter" || _killerVehicle isKindOf "Plane") exitWith {"air"};
    
    if (_killerVehicle isKindOf "Ship" || _killerVehicle isKindOf "Boat") exitWith {"naval"};
    
    "unknown"
};

// Function: Update threat assessment for tactical decisions
BATTLE_fnc_updateThreatAssessment = {
    private _killedBy = BATTLE_opforDeaths get "killedBy";
    private _totalDeaths = BATTLE_opforDeaths getOrDefault ["totalDeaths", 0];
    private _threats = BATTLE_opforDeaths get "threatAssessment";
    private _spawns = _threats get "recommended_spawns";
    
    if (_totalDeaths == 0) exitWith {};
    
    // Calculate threat percentages
    private _infantryKills = _killedBy getOrDefault ["infantry", 0];
    private _tankKills = _killedBy getOrDefault ["tank", 0];
    private _apcKills = _killedBy getOrDefault ["apc", 0];
    private _airKills = _killedBy getOrDefault ["air", 0];
    private _navalKills = _killedBy getOrDefault ["naval", 0];
    
    // Calculate threat levels (0-100 scale)
    _threats set ["infantry_threat", round((_infantryKills / _totalDeaths) * 100)];
    _threats set ["armor_threat", round(((_tankKills + _apcKills) / _totalDeaths) * 100)];
    _threats set ["air_threat", round((_airKills / _totalDeaths) * 100)];
    _threats set ["naval_threat", round((_navalKills / _totalDeaths) * 100)];
    
    // Calculate recommended spawn weights (0-10 scale)
    // Higher enemy activity = higher counter-spawn weight
    
    // Tanks: Good against armor and infantry
    private _tankWeight = 0;
    if (_tankKills > 2) then { _tankWeight = _tankWeight + 8; };     // High priority vs enemy tanks
    if (_apcKills > 3) then { _tankWeight = _tankWeight + 6; };      // Medium priority vs APCs
    if (_infantryKills > 10) then { _tankWeight = _tankWeight + 4; }; // Low priority vs infantry
    _spawns set ["tanks", (_tankWeight min 10)];
    
    // APCs: Good against infantry
    private _apcWeight = 0;
    if (_infantryKills > 5) then { _apcWeight = _apcWeight + 7; };    // High priority vs infantry
    if (_apcKills > 2) then { _apcWeight = _apcWeight + 3; };         // Support vs enemy APCs
    _spawns set ["apcs", (_apcWeight min 10)];
    
    // Anti-Tank Infantry: Good against armor
    private _atWeight = 0;
    if (_tankKills > 1) then { _atWeight = _atWeight + 9; };          // Critical vs tanks
    if (_apcKills > 2) then { _atWeight = _atWeight + 6; };           // High vs APCs
    _spawns set ["infantry_at", (_atWeight min 10)];
    
    // Attack Aircraft: Good against ground targets
    private _airAttackWeight = 0;
    if (_tankKills > 3) then { _airAttackWeight = _airAttackWeight + 8; };
    if (_apcKills > 4) then { _airAttackWeight = _airAttackWeight + 6; };
    if (_infantryKills > 15) then { _airAttackWeight = _airAttackWeight + 4; };
    _spawns set ["air_attack", (_airAttackWeight min 10)];
    
    // Anti-Air: Good against enemy aircraft
    private _aaWeight = 0;
    if (_airKills > 1) then { _aaWeight = _aaWeight + 10; };          // Critical vs air
    _spawns set ["air_aa", (_aaWeight min 10)];
    
    // Naval: Good against naval threats
    private _navalWeight = 0;
    if (_navalKills > 0) then { _navalWeight = 10; };                 // Any naval = max priority
    _spawns set ["naval", _navalWeight];
    
    // Determine primary threat and overall threat level
    private _maxThreat = 0;
    private _primaryThreat = "none";
    
    if (_threats get "infantry_threat" > _maxThreat) then {
        _maxThreat = _threats get "infantry_threat";
        _primaryThreat = "infantry";
    };
    if (_threats get "armor_threat" > _maxThreat) then {
        _maxThreat = _threats get "armor_threat";
        _primaryThreat = "armor";
    };
    if (_threats get "air_threat" > _maxThreat) then {
        _maxThreat = _threats get "air_threat";
        _primaryThreat = "air";
    };
    if (_threats get "naval_threat" > _maxThreat) then {
        _maxThreat = _threats get "naval_threat";
        _primaryThreat = "naval";
    };
    
    _threats set ["primary_threat", _primaryThreat];
    
    // Set overall threat level
    private _threatLevel = switch (true) do {
        case (_maxThreat >= 60): {"critical"};
        case (_maxThreat >= 40): {"high"};
        case (_maxThreat >= 20): {"medium"};
        default {"low"};
    };
    
    _threats set ["threat_level", _threatLevel];
};

// Function: Get tactical recommendations for spawn decisions
BATTLE_fnc_getTacticalRecommendations = {
    private _threats = BATTLE_opforDeaths get "threatAssessment";
    private _spawns = _threats get "recommended_spawns";
    
    // Return structured data for other scripts
    private _recommendations = createHashMap;
    _recommendations set ["primary_threat", _threats get "primary_threat"];
    _recommendations set ["threat_level", _threats get "threat_level"];
    _recommendations set ["spawn_weights", _spawns];
    
    // Add human-readable summary
    private _summary = format ["Primary Threat: %1 (%2 level)", 
        toUpper (_threats get "primary_threat"), 
        toUpper (_threats get "threat_level")];
    _recommendations set ["summary", _summary];
    
    _recommendations
};

// Function: Reset intelligence statistics for current relevance
BATTLE_fnc_resetIntelligence = {
    systemChat "[BATTLE] === INTELLIGENCE RESET ===";
    systemChat "[BATTLE] Clearing old threat data to focus on current battlefield conditions";
    
    // Store historical totals before reset
    private _oldTotal = BATTLE_opforDeaths getOrDefault ["totalDeaths", 0];
    private _historicalTotal = BATTLE_opforDeaths getOrDefault ["historicalDeaths", 0];
    BATTLE_opforDeaths set ["historicalDeaths", _historicalTotal + _oldTotal];
    
    // Reset current death counters
    private _killedBy = BATTLE_opforDeaths get "killedBy";
    _killedBy set ["infantry", 0];
    _killedBy set ["tank", 0];
    _killedBy set ["apc", 0];
    _killedBy set ["air", 0];
    _killedBy set ["naval", 0];
    _killedBy set ["unknown", 0];
    
    // Reset total deaths counter
    BATTLE_opforDeaths set ["totalDeaths", 0];
    
    // Reset threat assessment to baseline
    private _threats = BATTLE_opforDeaths get "threatAssessment";
    _threats set ["infantry_threat", 0];
    _threats set ["armor_threat", 0];
    _threats set ["air_threat", 0];
    _threats set ["naval_threat", 0];
    _threats set ["primary_threat", "none"];
    _threats set ["threat_level", "low"];
    
    // Reset spawn recommendations
    private _spawns = _threats get "recommended_spawns";
    _spawns set ["tanks", 0];
    _spawns set ["apcs", 0];
    _spawns set ["infantry_at", 0];
    _spawns set ["air_attack", 0];
    _spawns set ["air_aa", 0];
    _spawns set ["naval", 0];
    
    // Update reset time
    BATTLE_opforDeaths set ["lastResetTime", time];
    
    publicVariable "BATTLE_opforDeaths";
    
    systemChat format ["[BATTLE] Intelligence reset complete. Historical deaths: %1", 
        BATTLE_opforDeaths get "historicalDeaths"];
    systemChat "[BATTLE] Threat assessment now focuses on recent battlefield activity";
};

// Function: Track OPFOR death
BATTLE_fnc_trackOpforDeath = {
    params ["_unit", "_killer", "_instigator"];
    
    // Check multiple ways to determine if unit is OPFOR
    private _unitSide = side _unit;
    private _groupSide = side group _unit;
    private _isOpfor = (_unitSide == east || _groupSide == east);
    
    // Debug: Show what we received
    systemChat format ["[BATTLE Debug] Death: %1, unitSide: %2, groupSide: %3, isOPFOR: %4", 
        typeOf _unit, _unitSide, _groupSide, _isOpfor];
    
    // Only track OPFOR deaths
    if (!_isOpfor) exitWith {
        systemChat format ["[BATTLE Debug] Not OPFOR, skipping."];
    };
    
    systemChat "[BATTLE Debug] OPFOR death confirmed, processing...";
    
    // Analyze what killed the unit
    private _killerType = [_unit, _killer, _instigator] call BATTLE_fnc_analyzeKiller;
    
    systemChat format ["[BATTLE Debug] Killer type determined: %1", _killerType];
    
    // Update death counters
    private _killedBy = BATTLE_opforDeaths get "killedBy";
    private _currentCount = _killedBy getOrDefault [_killerType, 0];
    _killedBy set [_killerType, _currentCount + 1];
    
    // Update total deaths
    private _totalDeaths = BATTLE_opforDeaths getOrDefault ["totalDeaths", 0];
    BATTLE_opforDeaths set ["totalDeaths", _totalDeaths + 1];
    
    // Update threat assessment
    [] call BATTLE_fnc_updateThreatAssessment;
    
    // Simple announcement
    systemChat format ["[BATTLE] OPFOR killed by %1 (Total: %2)", 
        toUpper _killerType, _totalDeaths + 1];
    
    publicVariable "BATTLE_opforDeaths";
};

// Function: Get death statistics
BATTLE_fnc_getDeathStats = {
    params [["_category", ""]];
    
    if (_category == "") then {
        // Return all stats
        BATTLE_opforDeaths get "killedBy"
    } else {
        // Return specific category
        private _killedBy = BATTLE_opforDeaths get "killedBy";
        _killedBy getOrDefault [_category, 0]
    };
};

// Function: Generate death report
BATTLE_fnc_generateDeathReport = {
    private _killedBy = BATTLE_opforDeaths get "killedBy";
    private _totalDeaths = BATTLE_opforDeaths get "totalDeaths";
    private _threats = BATTLE_opforDeaths get "threatAssessment";
    private _spawns = _threats get "recommended_spawns";
    
    // Create dialog-style display using hint
    private _reportText = "<t size='1.5' color='#ff4040'>TACTICAL INTELLIGENCE</t><br/><br/>";
    _reportText = _reportText + format ["<t size='1.2'>Total OPFOR Deaths: %1</t><br/><br/>", _totalDeaths];
    
    // Casualties by type
    _reportText = _reportText + "<t size='1.1' color='#ffaa00'>KILLED BY:</t><br/>";
    
    private _categories = [["infantry", "Infantry"], ["tank", "Tank"], ["apc", "APC"], ["air", "Air"], ["naval", "Naval"], ["unknown", "Unknown"]];
    {
        private _category = _x select 0;
        private _displayName = _x select 1;
        private _count = _killedBy getOrDefault [_category, 0];
        if (_count > 0) then {
            private _percentage = if (_totalDeaths > 0) then {
                round((_count / _totalDeaths) * 100)
            } else {
                0
            };
            _reportText = _reportText + format ["<t color='#ffffff'>%1: %2 deaths (%3%%)</t><br/>", _displayName, _count, _percentage];
        } else {
            _reportText = _reportText + format ["<t color='#666666'>%1: 0 deaths</t><br/>", _displayName];
        };
    } forEach _categories;
    
    _reportText = _reportText + "<br/>";
    
    // Threat assessment
    _reportText = _reportText + format ["<t size='1.1' color='#ffaa00'>PRIMARY THREAT: %1</t><br/>", toUpper (_threats get "primary_threat")];
    _reportText = _reportText + format ["<t size='1.1' color='#ffaa00'>THREAT LEVEL: %1</t><br/><br/>", toUpper (_threats get "threat_level")];
    
    // Recommended spawns
    _reportText = _reportText + "<t size='1.1' color='#00ff00'>RECOMMENDED COUNTERS:</t><br/>";
    
    private _spawnCategories = [["tanks", "Tanks"], ["apcs", "APCs"], ["infantry_at", "AT Infantry"], ["air_attack", "Attack Aircraft"], ["air_aa", "Anti-Air"], ["naval", "Naval Assets"]];
    {
        private _spawnType = _x select 0;
        private _displayName = _x select 1;
        private _weight = _spawns getOrDefault [_spawnType, 0];
        if (_weight > 0) then {
            private _color = switch (true) do {
                case (_weight >= 8): {"#ff0000"}; // Red for high priority
                case (_weight >= 5): {"#ffaa00"}; // Orange for medium
                default {"#00ff00"}; // Green for low
            };
            _reportText = _reportText + format ["<t color='%1'>%2: Priority %3/10</t><br/>", _color, _displayName, _weight];
        } else {
            _reportText = _reportText + format ["<t color='#666666'>%1: Not needed</t><br/>", _displayName];
        };
    } forEach _spawnCategories;
    
    // Display the hint
    hint parseText _reportText;
    
    // Also show in system chat for reference
    systemChat "==============================";
    systemChat "[BATTLE] TACTICAL INTELLIGENCE REPORT DISPLAYED";
    systemChat "==============================";
};

// ============================================================================
// PERIODIC INTELLIGENCE RESET SYSTEM
// ============================================================================

// Intelligence reset loop for current relevance
[] spawn {
    while {BATTLE_opforDeaths getOrDefault ["resetEnabled", true]} do {
        private _resetInterval = BATTLE_opforDeaths getOrDefault ["resetInterval", 1800];
        
        systemChat format ["[BATTLE] Next intelligence reset in %1 minutes to maintain current relevance", 
            round(_resetInterval / 60)];
        
        sleep _resetInterval;
        
        [] call BATTLE_fnc_resetIntelligence;
    };
};

// ============================================================================
// EVENT HANDLERS
// ============================================================================

// Set up entity killed event handler
addMissionEventHandler ["EntityKilled", {
    params ["_unit", "_killer", "_instigator", "_useEffects"];
    
    // Debug: Show all deaths
    systemChat format ["[BATTLE Debug] EntityKilled fired: %1 killed by %2", 
        typeOf _unit, if (isNull _killer) then {"null"} else {typeOf _killer}];
    
    // Track OPFOR deaths
    [_unit, _killer, _instigator] call BATTLE_fnc_trackOpforDeath;
}];

// ============================================================================
// PUBLIC FUNCTIONS
// ============================================================================

// Make functions globally accessible
publicVariable "BATTLE_fnc_analyzeKiller";
publicVariable "BATTLE_fnc_trackOpforDeath";
publicVariable "BATTLE_fnc_updateThreatAssessment";
publicVariable "BATTLE_fnc_getTacticalRecommendations";
publicVariable "BATTLE_fnc_resetIntelligence";
publicVariable "BATTLE_fnc_getDeathStats";
publicVariable "BATTLE_fnc_generateDeathReport";

// ============================================================================
// INITIALIZATION COMPLETE
// ============================================================================

systemChat "[BATTLE] Tactical Intelligence System initialized!";
systemChat "[BATTLE] Tracking: Infantry | Tank | APC | Air | Naval";
systemChat "[BATTLE] Intelligence resets every 30 minutes for current relevance";
systemChat "[BATTLE] Command: [] call BATTLE_fnc_generateDeathReport";
systemChat "[BATTLE] Get recommendations: [] call BATTLE_fnc_getTacticalRecommendations";
systemChat "[BATTLE] Manual reset: [] call BATTLE_fnc_resetIntelligence";
systemChat "[BATTLE] Quick access: private _threats = BATTLE_opforDeaths get 'threatAssessment'";

diag_log "[BATTLE] OPFOR death monitoring system fully initialized";
