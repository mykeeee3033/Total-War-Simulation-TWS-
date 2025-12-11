# NPC Analyzer

## Overview
The NPC Analyzer is a comprehensive monitoring system for Arma 3 missions that tracks and analyzes all units (NPCs) on the map in real-time. It provides detailed information about unit health, ammunition, status, and position organized by faction.

## Features

### Data Collection
- **Health**: Tracks unit health as percentage (1.0 = full health, 0.0 = dead)
- **Ammo**: Counts magazines available to each unit
- **Status**: Monitors unit state including:
  - Alive/Dead
  - Incapacitated
  - In Vehicle (with vehicle type)
  - In Combat
  - Current Weapon
- **Position**: Records 3D coordinates of each unit
- **Faction**: Organizes units by BLUFOR, OPFOR, INDEPENDENT, and CIVILIAN

### Statistics
For each faction, the analyzer calculates:
- Total units
- Alive units
- Dead units
- Average health
- Average ammunition count
- Units in combat

## Usage

### Automatic Monitoring
The NPC Analyzer automatically starts when the mission begins and runs in the background, performing analysis at regular intervals (default: 60 seconds).

### Manual Analysis
To perform an immediate analysis:
```sqf
call npcAnalyzer_analyzeNow;
```

### Configuration
You can configure the analyzer before it starts:

```sqf
// Change the analysis interval (seconds)
npcAnalyzerInterval = 120; // Analyze every 2 minutes

// Disable automatic monitoring
npcAnalyzerEnabled = false;
```

### Accessing Data
The analysis data is stored in the global variable `npcAnalysisData` and can be accessed programmatically:

```sqf
// Get the latest analysis data
private _data = npcAnalysisData;

// Extract specific information
private _timestamp = {if (_x select 0 == "timestamp") exitWith {_x select 1}} forEach _data;
private _totalUnits = {if (_x select 0 == "total_units") exitWith {_x select 1}} forEach _data;
private _statistics = {if (_x select 0 == "statistics") exitWith {_x select 1}} forEach _data;
private _factions = {if (_x select 0 == "factions") exitWith {_x select 1}} forEach _data;
```

## Output Methods

### System Chat
Analysis results are automatically displayed in system chat with summary statistics for each faction.

### Diary Entry
Results are also written to the player's diary for persistent reference. Open the map and check the "Diary" tab to view historical analysis reports.

### Programmatic Access
The `npcAnalysisData` variable contains the complete analysis data structure for use by other scripts:

```sqf
Data Structure:
[
  ["timestamp", <number>],
  ["total_units", <number>],
  ["statistics", [
    [
      ["faction", <string>],
      ["total", <number>],
      ["alive", <number>],
      ["dead", <number>],
      ["avg_health", <number>],
      ["avg_ammo", <number>],
      ["in_combat", <number>]
    ],
    ...
  ]],
  ["factions", [
    [<faction_name>, [
      [
        ["id", <string>],
        ["name", <string>],
        ["type", <string>],
        ["position", [x, y, z]],
        ["health", <number>],
        ["damage", <number>],
        ["ammo_count", <number>],
        ["status", [<string>, ...]],
        ["group", <string>],
        ["faction", <string>]
      ],
      ...
    ]],
    ...
  ]]
]
```

## Integration

The NPC Analyzer is automatically loaded by `init.sqf`:
```sqf
[] execVM "npc_analyzer.sqf";
```

## Testing

A test script is provided to verify functionality:
```sqf
[] execVM "test_npc_analyzer.sqf";
```

## Examples

### Example 1: Find units with low ammo
```sqf
private _data = npcAnalysisData;
private _factions = {if (_x select 0 == "factions") exitWith {_x select 1}} forEach _data;

{
    private _factionName = _x select 0;
    private _units = _x select 1;
    
    {
        private _unitData = _x;
        private _ammo = {if (_x select 0 == "ammo_count") exitWith {_x select 1}} forEach _unitData;
        private _name = {if (_x select 0 == "name") exitWith {_x select 1}} forEach _unitData;
        
        if (_ammo < 3) then {
            systemChat format ["%1 has low ammo: %2 magazines", _name, _ammo];
        };
    } forEach _units;
} forEach _factions;
```

### Example 2: Count BLUFOR units in combat
```sqf
private _data = npcAnalysisData;
private _stats = {if (_x select 0 == "statistics") exitWith {_x select 1}} forEach _data;

{
    private _faction = {if (_x select 0 == "faction") exitWith {_x select 1}} forEach _x;
    private _inCombat = {if (_x select 0 == "in_combat") exitWith {_x select 1}} forEach _x;
    
    if (_faction == "BLUFOR") then {
        systemChat format ["BLUFOR units in combat: %1", _inCombat];
    };
} forEach _stats;
```

### Example 3: Find wounded units
```sqf
private _data = npcAnalysisData;
private _factions = {if (_x select 0 == "factions") exitWith {_x select 1}} forEach _data;

{
    private _units = _x select 1;
    
    {
        private _unitData = _x;
        private _health = {if (_x select 0 == "health") exitWith {_x select 1}} forEach _unitData;
        private _status = {if (_x select 0 == "status") exitWith {_x select 1}} forEach _unitData;
        private _name = {if (_x select 0 == "name") exitWith {_x select 1}} forEach _unitData;
        
        if ("ALIVE" in _status && _health < 0.5) then {
            systemChat format ["%1 is wounded (Health: %.1f%%)", _name, _health * 100];
        };
    } forEach _units;
} forEach _factions;
```

## Performance Considerations

- The analyzer processes all units on the map, which can be resource-intensive in large missions
- Adjust `npcAnalyzerInterval` to balance between data freshness and performance
- For missions with 100+ units, consider intervals of 120 seconds or more
- The data structure is optimized for read access but includes all unit details

## Compatibility

- Requires Arma 3
- Compatible with all factions and unit types
- Works in multiplayer (server-side execution recommended)
- No external dependencies required
