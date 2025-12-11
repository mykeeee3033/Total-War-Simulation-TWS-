// test_npc_analyzer.sqf
// Test script for NPC analyzer

systemChat "=== Testing NPC Analyzer ===";

// Wait for analyzer to be loaded
sleep 1;

// Test immediate analysis
systemChat "Running immediate analysis...";
call npcAnalyzer_analyzeNow;

// Display stored data structure
systemChat "Checking stored data...";
systemChat format ["Data available: %1", !isNil "npcAnalysisData"];

// Test accessing specific faction data
private _data = npcAnalysisData;
private _factions = {if (_x select 0 == "factions") exitWith {_x select 1}} forEach _data;

systemChat "Faction data:";
{
    private _factionName = _x select 0;
    private _units = _x select 1;
    systemChat format ["  %1: %2 units", _factionName, count _units];
    
    // Show first unit as example if available
    if (count _units > 0) then {
        private _firstUnit = _units select 0;
        private _unitName = {if (_x select 0 == "name") exitWith {_x select 1}} forEach _firstUnit;
        private _unitPos = {if (_x select 0 == "position") exitWith {_x select 1}} forEach _firstUnit;
        private _unitHealth = {if (_x select 0 == "health") exitWith {_x select 1}} forEach _firstUnit;
        if (!isNil "_unitName" && !isNil "_unitPos" && !isNil "_unitHealth") then {
            systemChat format ["    Example: %1 at %2, Health: %.2f", _unitName, _unitPos, _unitHealth];
        };
    };
} forEach _factions;

systemChat "=== Test Complete ===";
