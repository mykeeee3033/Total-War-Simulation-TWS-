# Total War Simulation (TWS) - ALiVE Integration System

## Overview

This is a comprehensive autonomous world simulation system for Arma 3 that extends the ALiVE mod with realistic logistics, resource management, AI commanders, and strategic decision-making layers.

## System Architecture

The TWS system is built in phases, each extending ALiVE's capabilities without replacing them:

### Core Philosophy
- **ALiVE handles**: Unit spawning, mission generation, persistence, virtual AI, combat support
- **TWS adds**: Logistics economy, resource constraints, radar-driven air defense, strategic AI, grand strategy layer

---

## Phase 1: Core Strategic Layer

### World State Management (`worldState_custom.sqf`)
Tracks everything ALiVE doesn't handle:
- Factory production output
- Resource stockpiles (ammunition, fuel, materials, vehicles, aircraft)
- Radar site operational status
- Command center status
- Geopolitical parameters
- Operational tempo per faction

**Key Functions:**
- `TWS_fnc_getResources` - Get faction resources
- `TWS_fnc_modifyResource` - Add/subtract resources
- `TWS_fnc_consumeResource` - Consume resources with validation
- `TWS_fnc_getTempo` - Get operational tempo
- `TWS_fnc_setTempo` - Set operational tempo
- `TWS_fnc_registerFactory` - Register a production facility
- `TWS_fnc_registerRadar` - Register a radar site
- `TWS_fnc_registerCommandCenter` - Register a command center

### Object Roles (`objectRoles.sqf`)
Assigns economic roles to buildings:
- **Munitions Factory**: Produces ammunition
- **Fuel Refinery**: Produces fuel
- **Vehicle Plant**: Fabricates vehicles
- **Aircraft Plant**: Produces/repairs aircraft
- **Power Station**: Powers other facilities
- **Radar Site**: Air detection and defense
- **HQ Node**: Command and control
- **Logistics Hub**: Supply distribution

**Key Functions:**
- `TWS_fnc_assignObjectRole` - Assign a role to an object
- `TWS_fnc_setObjectOperational` - Enable/disable object
- `TWS_fnc_getOperationalObjects` - Get operational objects by role
- `TWS_fnc_autoAssignRoles` - Auto-detect and assign roles

### Custom Logistics (`customLogistics.sqf`)
Production and consumption system:
- Factories produce resources every 5 minutes
- Passive consumption every 10 minutes
- Production requires materials and fuel
- Resource levels affect operational tempo

**Resource Thresholds:**
- **Critical** (< 500): Tempo = 0.3
- **Low** (< 2000): Tempo = 0.6
- **Normal** (5000): Tempo = 1.0
- **Abundant** (> 10000): Tempo = 1.5

**Key Functions:**
- `TWS_fnc_processProduction` - Process factory production
- `TWS_fnc_processConsumption` - Process resource consumption
- `TWS_fnc_updateTempo` - Update tempo based on resources
- `TWS_fnc_getLogisticsStatus` - Get logistics summary

---

## Phase 2: ALiVE Integration

### ALiVE Hooks (`aliveIntegration.sqf`)
Connects custom systems to ALiVE:
- Detects if ALiVE mod is loaded
- Requests ALiVE logistics support based on resource needs
- Modifies OPCOM aggressiveness based on tempo
- Pauses operations when resources critical

**Key Functions:**
- `TWS_fnc_detectALiVE` - Check if ALiVE is present
- `TWS_fnc_requestALiVESupply` - Request supply convoy
- `TWS_fnc_modifyOPCOM` - Adjust OPCOM behavior
- `TWS_fnc_registerOPCOM` - Register OPCOM for faction
- `TWS_fnc_onSupplyDelivered` - Handle supply delivery

---

## Phase 3: Radar & Air Defense

### Enhanced Radar Defense (`radarDefense_custom.sqf`)
Resource-aware air scramble system:
- Checks resources before scrambling aircraft
- Consumes fuel and ammunition per scramble
- Minimum tempo required for operations
- Integrates with ALiVE virtual air system

**Key Functions:**
- `TWS_fnc_radarScramble` - Resource-aware scramble decision
- `TWS_fnc_assignScramblePilot` - Spawn and assign pilot
- `TWS_fnc_enhanceRadarScript` - Enhance existing radar
- `TWS_fnc_getAirDefenseReadiness` - Get readiness status

---

## Phase 4: Commander AI

### Commander Personality (`commanderPersonality.sqf`)
Strategic personality layer above OPCOM:

**Personalities:**
1. **Cautious**: Defensive, preserves resources (Aggro: 0.2)
2. **Balanced**: Standard operations (Aggro: 0.5)
3. **Aggressive**: Offensive, high tempo (Aggro: 0.8)
4. **Recovery**: After heavy losses (Aggro: 0.1)
5. **Logistics-First**: Prioritize supply build-up (Aggro: 0.3)
6. **Blitz**: Maximum aggression (Aggro: 1.0)

**Auto-Adjustment Rules:**
- Resources critical → Recovery mode
- Resources low + aggressive → Switch to Cautious
- Resources abundant + high tempo → Blitz mode
- Resources normal + recovering → Back to Balanced

**Key Functions:**
- `TWS_fnc_setCommanderPersonality` - Set personality
- `TWS_fnc_autoAdjustPersonality` - Auto-adjust based on situation
- `TWS_fnc_getCommanderDecision` - Get decision for operation type
- `TWS_fnc_getOPCOMRecommendations` - Get OPCOM settings

---

## Phase 5: Strategic Reporting

### ChatGPT Integration (`chatGPTIntegration.sqf`)
Grand strategy layer above Commander AI:
- Compiles strategic reports every 30 minutes
- Exports battlefield state to RPT log
- Provides format for external AI analysis
- Can apply recommendations to commanders

**Report Contents:**
- Resource levels per faction
- Operational tempo
- Factory status
- Commander personality
- Air defense readiness
- Casualty counts
- OPCOM recommendations

**Key Functions:**
- `TWS_fnc_compileStrategicReport` - Generate report
- `TWS_fnc_formatReportText` - Format as text
- `TWS_fnc_exportReport` - Export to log
- `TWS_fnc_applyRecommendations` - Apply strategic changes

---

## Phase 6: Optional Systems

### Geopolitics (`geopolitics.sqf`)
**DISABLED BY DEFAULT** - Enable with: `[true] call TWS_fnc_toggleGeopolitics`

Simulates external factors:
- Foreign military aid
- Economic sanctions
- Foreign support changes
- Regional crises
- Peace negotiations
- Conflict escalation
- Resource discoveries

Events occur randomly every 15 minutes (30% chance).

### Civilian Economy (`civilianEconomy.sqf`)
**DISABLED BY DEFAULT** - Enable with: `[true] call TWS_fnc_toggleCivilianEconomy`

Simulates civilian systems:
- Power grid status
- Fuel availability
- Civilian morale
- Infrastructure damage

Low morale reduces factory production by 20%.

---

## Installation

1. Copy the `functions/` folder to your mission directory
2. The system auto-initializes from `initServer.sqf`
3. Existing scripts continue to work normally

## Configuration

### Adjusting Production Rates
Edit `functions/core/objectRoles.sqf`:
```sqf
_munitionsFactory set ["productionRate", 100]; // Change this value
```

### Adjusting Resource Thresholds
Edit `functions/logistics/customLogistics.sqf`:
```sqf
TWS_resourceThresholds set ["critical", 500]; // Change thresholds
TWS_resourceThresholds set ["low", 2000];
TWS_resourceThresholds set ["normal", 5000];
```

### Adjusting Report Frequency
Edit `functions/reports/chatGPTIntegration.sqf`:
```sqf
TWS_chatGPTConfig set ["reportInterval", 1800]; // Seconds (30 min)
```

### Enabling Optional Systems
In-game console or script:
```sqf
[true] call TWS_fnc_toggleGeopolitics;        // Enable geopolitics
[true] call TWS_fnc_toggleCivilianEconomy;    // Enable civilian economy
```

---

## Manual Object Assignment

To manually assign roles to specific objects:

```sqf
// Assign a munitions factory
[building1, "munitionsFactory", "BLUFOR"] call TWS_fnc_assignObjectRole;

// Assign a fuel refinery
[building2, "fuelRefinery", "OPFOR"] call TWS_fnc_assignObjectRole;

// Assign a vehicle plant
[building3, "vehiclePlant", "BLUFOR"] call TWS_fnc_assignObjectRole;

// Assign a radar site
[radar_object, "radarSite", "BLUFOR"] call TWS_fnc_assignObjectRole;

// Assign a command center
[hq_building, "hqNode", "OPFOR"] call TWS_fnc_assignObjectRole;
```

---

## Monitoring and Debugging

### Check Resource Levels
```sqf
private _bluforRes = ["BLUFOR"] call TWS_fnc_getResources;
hint str _bluforRes;
```

### Check Operational Tempo
```sqf
private _tempo = ["BLUFOR"] call TWS_fnc_getTempo;
hint format ["BLUFOR Tempo: %1", _tempo];
```

### Get Logistics Status
```sqf
private _status = ["BLUFOR"] call TWS_fnc_getLogisticsStatus;
hint str _status;
```

### Get Commander Info
```sqf
private _commander = TWS_commanders get "BLUFOR";
hint str _commander;
```

### Get Air Defense Readiness
```sqf
private _readiness = ["BLUFOR"] call TWS_fnc_getAirDefenseReadiness;
hint str _readiness;
```

### View Strategic Report
Strategic reports are automatically generated every 30 minutes and logged to the RPT file. Check your Arma 3 logs folder.

---

## Integration with Existing Scripts

The TWS system is designed to work alongside your existing scripts:

### Existing Radar Scripts
The system automatically enhances existing radar objects (e.g., `radar_2`). Your existing radar scripts continue to work, but now they also check resources before scrambling.

### Existing Logistics Scripts
Your existing C-130 resupply and helicopter logistics continue to work. You can integrate them with TWS by calling:
```sqf
["BLUFOR", "ammunition", 500] call TWS_fnc_onSupplyDelivered;
```

### Combat Monitor
The system integrates with your existing `combat_monitor.sqf` to include casualty data in strategic reports.

---

## Performance Considerations

- **Production loop**: Runs every 5 minutes (low impact)
- **Consumption loop**: Runs every 10 minutes (low impact)
- **ALiVE integration**: Checks every 10 minutes (low impact)
- **Commander AI**: Checks every 10 minutes (low impact)
- **Strategic reports**: Generated every 30 minutes (low impact)
- **Optional systems**: Disabled by default

Total overhead: Minimal - designed for multiplayer performance.

---

## Troubleshooting

### System not initializing
Check RPT log for `[TWS]` messages. Ensure `functions/TWS_init.sqf` is being executed.

### Resources not changing
Verify factories are registered:
```sqf
hint str (TWS_worldState get "factories");
```

### Tempo stuck at 1.0
Resources may be in normal range. Check resource levels with:
```sqf
hint str (["BLUFOR"] call TWS_fnc_getResources);
```

### No strategic reports
Reports are logged to RPT file every 30 minutes. Check your Arma 3 logs folder for the latest RPT file.

---

## Future Enhancements

Possible additions:
- Integration with Zeus modules for live control
- Graphical UI for monitoring
- Persistent storage between missions
- More geopolitical events
- Weather effects on logistics
- Supply line simulation
- Advanced diplomacy system

---

## Credits

- Built for Arma 3
- Designed to complement ALiVE mod
- Compatible with existing mission scripts

---

## License

This is a mission enhancement system. Use freely in your Arma 3 missions.
