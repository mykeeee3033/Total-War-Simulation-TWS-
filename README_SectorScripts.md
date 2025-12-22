# ALiVE Sector Information Scripts

This collection of scripts provides detailed information about ALiVE sectors in Arma 3. These scripts help you understand sector control, ownership, terrain, infrastructure, and strategic value.

## Recent Updates

**Fixed Ownership Detection:** Both scripts now properly detect sector control using ALiVE's profile-based system. The scripts now check `entitiesBySide` and `vehiclesBySide` data in addition to OPCOM objectives, which provides accurate real-time sector ownership information. This fixes the issue where ownership was always showing as "Neutral" despite visible faction presence.

## Scripts Included

### 1. getSectorInfo.sqf - Basic Sector Information
**Purpose**: Get comprehensive information about the sector you're currently in.

**Usage**:
```sqf
execVM "getSectorInfo.sqf"
```

**Features**:
- Basic sector identification (ID, center, dimensions)
- Terrain type analysis
- Infrastructure detection (military and civilian)
- Road network information
- Unit presence by side
- OPCOM objective detection and ownership
- Distance calculations

### 2. sectorMonitor.sqf - Advanced Sector Monitor
**Purpose**: Enhanced sector monitoring with visual markers and continuous updates.

**Usage**:
```sqf
// Single use with markers
[] execVM "sectorMonitor.sqf"

// Continuous monitoring every 5 seconds
[true] execVM "sectorMonitor.sqf"

// Continuous monitoring every 10 seconds with markers
[true, true, 10] execVM "sectorMonitor.sqf"

// Single use without markers
[false, false] execVM "sectorMonitor.sqf"
```

**Parameters**:
- `_continuous` (boolean): Enable continuous monitoring (default: false)
- `_showMarkers` (boolean): Show visual markers on map (default: true)
- `_updateInterval` (number): Update interval in seconds for continuous mode (default: 5)

**Features**:
- Visual sector boundary markers
- Objective markers with color-coded sides
- Strategic value assessment
- Installation type breakdown
- Continuous monitoring option
- Auto-cleanup of markers

**To Stop Continuous Monitoring**:
```sqf
missionNamespace setVariable ['SECTOR_MONITOR_STOP', true];
```

### 3. quickSectorInfo.sqf - Quick Reference
**Purpose**: Lightweight sector info for quick reference.

**Usage**:
```sqf
// Direct execution
[] execVM "quickSectorInfo.sqf"

// Add as player action
player addAction ["Get Sector Info", {execVM "quickSectorInfo.sqf";}];

// Add to radio trigger
[] execVM "quickSectorInfo.sqf"
```

**Features**:
- Quick sector identification
- Control status
- Basic infrastructure info
- Compact hint display
- Chat message for reference

## ALiVE Functions Used

These scripts utilize several key ALiVE functions:

### Sector Grid Functions
- `ALiVE_sectorGrid` - Global sector grid variable
- `ALIVE_fnc_sectorGrid` with "positionToSector" - Get sector from position
- `ALIVE_fnc_sector` - Work with sector objects

### Data Access Functions
- `ALIVE_fnc_hashGet` - Get data from sector hash tables
- Sector data includes: terrain, clustersMil, clustersCiv, roads, units, elevation

### OPCOM Integration
- `OPCOM_instances` - Global array of OPCOM instances
- Objective data: center, opcom_state, objectiveType, size, objectiveID

## Sector Data Structure

ALiVE sectors contain rich data:

### Basic Properties
- `id` - Sector identifier (e.g., "0_1")
- `center` - Center position [x, y, z]
- `bounds` - Array of corner positions
- `dimensions` - [width/2, height/2] in meters

### Sector Data Hash
- `terrain` - "LAND", "SEA", or mixed
- `clustersMil` - Military installation data
- `clustersCiv` - Civilian settlement data  
- `roads` - Road network segments
- `units` - Unit presence by side (EAST, WEST, GUER, CIV)
- `elevation` - Height data points
- `active` - Active player data

### OPCOM Objective States
- `defend`/`defending` - Actively defended
- `reserve`/`reserving` - Held in reserve
- `attack`/`attacking` - Under attack
- `idle` - No active orders
- `unassigned` - Not assigned to any OPCOM

## Installation

1. Copy the script files to your mission folder
2. Ensure ALiVE is properly loaded and initialized
3. Execute the scripts during gameplay

## Requirements

- ALiVE mod loaded and running
- ALiVE sector grid initialized (`ALiVE_sectorGrid` exists)
- OPCOM modules for ownership information (optional but recommended)

## Troubleshooting

### "ALiVE Sector Grid not found!"
- Ensure ALiVE is loaded
- Check that sector grid has been initialized
- Wait for mission start and ALiVE initialization

### "No valid sector found!"
- You may be outside the mapped area
- ALiVE sector grid may not cover your current position
- Try moving to a different location

### No OPCOM Information
- OPCOM modules may not be placed
- OPCOM may not have initialized yet
- Check if `OPCOM_instances` exists

## Tips for Best Results

1. **Wait for Initialization**: Run scripts after ALiVE has fully loaded (usually 30+ seconds after mission start)

2. **Continuous Monitoring**: Use for dynamic situations where sector control changes frequently

3. **Markers**: Enable markers to visualize sector boundaries and objectives on the map

4. **Strategic Planning**: Use infrastructure and terrain data for tactical decision-making

5. **Performance**: For continuous monitoring, use longer intervals (10+ seconds) to reduce performance impact

## Example Output

```
=== ALIVE SECTOR MONITOR ===
Sector ID: 15_12
Grid Position: 123456
Sector Center: 124455 ([12445, 5432, 0])
Sector Size: 1000m x 1000m
Distance to Center: 234m

=== SECTOR ANALYSIS ===
Terrain Type: LAND
Military Infrastructure: 2 installations
Installation Types: MilOffices, MilComm
Civilian Infrastructure: 1 settlements
Road Network: 15 segments
Unit Presence: EAST:3 | WEST:1
Strategic Value: High

=== OPCOM CONTROL ANALYSIS ===
Objective AirBase_1: MilOffices (defending)
  Controlled by: EAST (OPF_F)
  Size: 200m | Distance: 156m

=== SECTOR SUMMARY ===
Control: EAST Controlled
Terrain: LAND
Objectives: 1
Forces: EAST:3 | WEST:1
```

This information helps you understand:
- Who controls the area
- What strategic assets are present
- Force disposition
- Terrain characteristics
- Tactical opportunities

Happy sector analysis!