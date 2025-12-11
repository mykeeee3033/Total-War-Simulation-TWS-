# Total War Simulation (TWS) - Arma 3

An advanced autonomous world simulation system for Arma 3 that adds realistic logistics, resource management, AI commanders, and strategic decision-making layers. Designed to work with or without the ALiVE mod.

## What's New: ALiVE Integration System

This mission now includes a **complete autonomous world simulation** featuring:

✅ **Factory & Resource System** - Ammunition, fuel, vehicle, and aircraft production  
✅ **Dynamic Logistics** - Resources consumed during operations, affecting capability  
✅ **Operational Tempo** - Military effectiveness scales with resource availability  
✅ **Commander AI** - 6 personality types that adapt to strategic situation  
✅ **ALiVE Integration** - Seamlessly enhances ALiVE mod if present  
✅ **Radar Defense** - Resource-aware air scramble system  
✅ **Strategic Reporting** - 30-minute reports for analysis/AI integration  
✅ **Optional Systems** - Geopolitics and civilian economy (disabled by default)

## Quick Start

The system **auto-initializes** when the mission loads. You'll see:
```
[TWS] TOTAL WAR SIMULATION INITIALIZED
```

### Assign Your First Factory (30 seconds)

```sqf
// In debug console:
_building = nearestObjects [player, ["Building"], 100] select 0;
[_building, "munitionsFactory", "BLUFOR"] call TWS_fnc_assignObjectRole;
```

**That's it!** The factory will start producing ammunition every 5 minutes.

## Documentation

- **[Quick Start Guide](functions/QUICKSTART.md)** - Get started in 5 minutes
- **[System Overview](functions/SYSTEM_OVERVIEW.md)** - Architecture and features
- **[Full Documentation](functions/README_TWS.md)** - Complete reference
- **[Configuration Examples](functions/TWS_config_example.sqf)** - Customization guide

## Key Features

### Resource Management
- Ammunition, fuel, materials, vehicles, aircraft
- Production requires materials and fuel
- Destroyed factories = reduced capability

### Operational Tempo
- Scales from 0.3 (critical) to 1.5 (maximum)
- Affects AI aggressiveness and capability
- Auto-adjusts based on resource levels

### Commander Personalities
- **Cautious**: Defensive, preserve resources
- **Balanced**: Standard operations
- **Aggressive**: Offensive, high tempo
- **Recovery**: Rebuilding after losses
- **Logistics-First**: Supply priority
- **Blitz**: Maximum aggression

### Strategic Reports
Every 30 minutes:
- Resource levels
- Factory status
- Commander decisions
- Casualty counts
- OPCOM recommendations

### ALiVE Integration (Optional)
- Auto-detects ALiVE mod
- Modifies OPCOM behavior
- Requests supply convoys
- Integrates with virtual AI

## System Architecture

```
Grand Strategy (ChatGPT Integration)
         ↓
Operational Layer (Commander AI)
         ↓
ALiVE Integration (OPCOM Modifier)
         ↓
Tactical Systems (Logistics, Radar)
         ↓
Core Layer (Resources, Factories)
```

## File Structure

```
functions/
├── TWS_init.sqf                 # Auto-initializes on server
├── core/                        # Resource & state management
├── logistics/                   # Production & consumption
├── aliveHooks/                  # ALiVE mod integration
├── radarAir/                    # Enhanced radar system
├── commander/                   # AI personalities
└── reports/                     # Strategic reporting
```

## Compatibility

- ✅ Arma 3 (any version)
- ✅ Works with existing scripts
- ✅ ALiVE mod (optional, enhances if present)
- ✅ Multiplayer & dedicated server
- ✅ No required dependencies

## Performance

Lightweight design:
- Production: Every 5 minutes
- Consumption: Every 10 minutes
- Reports: Every 30 minutes
- **CPU Impact**: < 1%

## Customization

Everything is customizable:
- Production rates
- Resource thresholds
- Commander behaviors
- Timing intervals
- Optional systems

See `functions/TWS_config_example.sqf` for examples.

## Getting Help

```sqf
// Check if system initialized
hint str TWS_initialized;

// Check BLUFOR resources
hint str (["BLUFOR"] call TWS_fnc_getResources);

// Check operational tempo
hint str (["BLUFOR"] call TWS_fnc_getTempo);

// Check commander personality
hint str (TWS_commanders get "BLUFOR");
```

## Credits

Built for Arma 3 Total War Simulation project.  
Designed to complement ALiVE mod.  
Free to use and modify.
