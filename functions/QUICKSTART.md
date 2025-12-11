# TWS Quick Start Guide

## Getting Started in 5 Minutes

### Step 1: Verify Installation
The system should auto-initialize when the mission loads. Look for these messages:
```
[TWS] Initializing Total War Simulation system...
[TWS] ✓ World State loaded
[TWS] ✓ Object Roles loaded
[TWS] ✓ Custom Logistics loaded
...
[TWS] TOTAL WAR SIMULATION INITIALIZED
```

### Step 2: Assign Your First Factory
Open the debug console in-game and run:
```sqf
// Find a building near you
_buildings = nearestObjects [player, ["Building"], 100];
_factory = _buildings select 0;

// Assign it as a munitions factory for BLUFOR
[_factory, "munitionsFactory", "BLUFOR"] call TWS_fnc_assignObjectRole;
```

You should see: `[TWS] Assigned role munitionsFactory to...`

### Step 3: Check Resources
```sqf
// Check BLUFOR resources
_res = ["BLUFOR"] call TWS_fnc_getResources;
hint str _res;
```

You'll see ammunition, fuel, materials, vehicles, and aircraft counts.

### Step 4: Monitor Production
Wait 5 minutes (or speed up time) and check resources again. You should see ammunition increasing due to your factory!

### Step 5: Check Strategic Report
Wait 30 minutes (or check RPT log) for the first strategic report. It will show:
- Resource levels
- Factory status
- Commander personality
- Operational tempo
- And more!

---

## Common Tasks

### Add More Factories

```sqf
// BLUFOR munitions factory
[building1, "munitionsFactory", "BLUFOR"] call TWS_fnc_assignObjectRole;

// OPFOR fuel refinery
[building2, "fuelRefinery", "OPFOR"] call TWS_fnc_assignObjectRole;

// BLUFOR vehicle plant
[building3, "vehiclePlant", "BLUFOR"] call TWS_fnc_assignObjectRole;
```

### Give Resources

```sqf
// Give BLUFOR 1000 ammo
["BLUFOR", "ammunition", 1000] call TWS_fnc_modifyResource;

// Give OPFOR 500 fuel
["OPFOR", "fuel", 500] call TWS_fnc_modifyResource;
```

### Change Commander Personality

```sqf
// Make BLUFOR aggressive
["BLUFOR", "aggressive"] call TWS_fnc_setCommanderPersonality;

// Make OPFOR cautious
["OPFOR", "cautious"] call TWS_fnc_setCommanderPersonality;
```

Available personalities:
- `"cautious"` - Defensive
- `"balanced"` - Standard
- `"aggressive"` - Offensive
- `"recovery"` - Rebuilding
- `"logisticsFirst"` - Supply focus
- `"blitz"` - Maximum aggression

### Check Operational Tempo

```sqf
_tempo = ["BLUFOR"] call TWS_fnc_getTempo;
hint format ["BLUFOR Tempo: %1", _tempo];
```

Tempo affects how aggressively the AI operates:
- < 0.5 = Very defensive
- 0.5-0.8 = Defensive
- 0.8-1.2 = Normal
- 1.2-1.5 = Aggressive
- > 1.5 = Very aggressive

### Simulate Supply Delivery

```sqf
// Simulate a convoy delivering 500 ammo to BLUFOR
["BLUFOR", "ammunition", 500] call TWS_fnc_onSupplyDelivered;
```

### Enable Optional Systems

```sqf
// Enable geopolitical events
[true] call TWS_fnc_toggleGeopolitics;

// Enable civilian economy
[true] call TWS_fnc_toggleCivilianEconomy;
```

---

## Monitoring Dashboard Commands

Run these in debug console for real-time info:

### Full Status Display
```sqf
[] spawn {
    private _text = "";
    
    {
        private _faction = _x;
        _text = _text + format ["========== %1 ==========\n", _faction];
        
        private _res = [_faction] call TWS_fnc_getResources;
        _text = _text + format ["Ammo: %1\n", _res get "ammunition"];
        _text = _text + format ["Fuel: %1\n", _res get "fuel"];
        _text = _text + format ["Vehicles: %1\n", _res get "vehicles"];
        
        private _tempo = [_faction] call TWS_fnc_getTempo;
        _text = _text + format ["Tempo: %1\n", _tempo];
        
        private _commander = TWS_commanders get _faction;
        _text = _text + format ["Personality: %1\n", _commander get "personality"];
        
        _text = _text + "\n";
    } forEach ["BLUFOR", "OPFOR"];
    
    hint _text;
};
```

### Factory Status
```sqf
private _factories = TWS_worldState get "factories";
private _text = format ["Total Factories: %1\n\n", count _factories];

{
    private _data = _y;
    if (_data get "operational") then {
        _text = _text + format ["%1 - %2 (%3)\n",
            _data get "faction",
            _data get "type",
            _data get "currentProductionRate"];
    };
} forEach _factories;

hint _text;
```

---

## Troubleshooting

### "Nothing is happening"
1. Check if system initialized: `hint str TWS_initialized;`
2. Check if factories registered: `hint str (count (TWS_worldState get "factories"));`
3. Wait 5 minutes for first production cycle

### "Tempo stuck at 1.0"
- Resources are probably in normal range (2000-10000)
- Try draining resources: `["BLUFOR", "ammunition", -5000] call TWS_fnc_modifyResource;`
- Check again after 10 minutes (consumption cycle)

### "No factories producing"
- Verify factories assigned: `hint str (TWS_worldState get "factories");`
- Check if they have materials: `_res = ["BLUFOR"] call TWS_fnc_getResources; hint str (_res get "materials");`

### "Strategic reports not appearing"
- Reports go to RPT log file, not in-game
- Check: `%LOCALAPPDATA%\Arma 3\` (look for latest .rpt file)
- Search for `[TWS]` in the log

---

## Advanced: Integration with ALiVE

If you're using ALiVE mod:

### 1. Let System Detect ALiVE
The system automatically detects ALiVE on initialization.

### 2. Register Your OPCOM Modules
```sqf
// In your mission init or after ALiVE loads
["BLUFOR", opcom_blufor_module] call TWS_fnc_registerOPCOM;
["OPFOR", opcom_opfor_module] call TWS_fnc_registerOPCOM;
```

### 3. Monitor Integration
```sqf
// Check if ALiVE detected
hint str (TWS_aliveConfig get "aliveDetected");
```

The system will automatically:
- Adjust OPCOM aggressiveness based on resources
- Request supply convoys when resources low
- Pause operations if resources critical

---

## Performance Tips

The system is designed to be lightweight:
- Production: Every 5 minutes
- Consumption: Every 10 minutes
- Reports: Every 30 minutes
- Optional systems: Disabled by default

To reduce overhead further:
```sqf
// Slower production cycles (10 minutes)
TWS_logisticsConfig set ["productionInterval", 600];

// Less frequent reports (60 minutes)
TWS_chatGPTConfig set ["reportInterval", 3600];
```

---

## Next Steps

1. ✅ Assign factories to key buildings
2. ✅ Set initial commander personalities
3. ✅ Adjust starting resources
4. ✅ Enable optional systems if desired
5. ✅ Create custom configuration file
6. ✅ Monitor first strategic report
7. ✅ Integrate with existing scripts
8. ✅ Test with ALiVE (if using)

---

## Getting Help

Check the full documentation: `functions/README_TWS.md`

Debug commands:
```sqf
// Full world state
hint str TWS_worldState;

// All commanders
hint str TWS_commanders;

// All factories
hint str (TWS_worldState get "factories");

// Logistics config
hint str TWS_logisticsConfig;
```

---

## Example Mission Setup

```sqf
// After TWS initializes...

// Assign BLUFOR installations
[blufor_factory1, "munitionsFactory", "BLUFOR"] call TWS_fnc_assignObjectRole;
[blufor_factory2, "fuelRefinery", "BLUFOR"] call TWS_fnc_assignObjectRole;
[blufor_factory3, "vehiclePlant", "BLUFOR"] call TWS_fnc_assignObjectRole;
[radar_2, "radarSite", "BLUFOR"] call TWS_fnc_assignObjectRole;

// Assign OPFOR installations
[opfor_factory1, "munitionsFactory", "OPFOR"] call TWS_fnc_assignObjectRole;
[opfor_factory2, "fuelRefinery", "OPFOR"] call TWS_fnc_assignObjectRole;
[opfor_factory3, "vehiclePlant", "OPFOR"] call TWS_fnc_assignObjectRole;

// Set initial resources (balanced)
["BLUFOR", "ammunition", 5000] call TWS_fnc_modifyResource;
["BLUFOR", "fuel", 3000] call TWS_fnc_modifyResource;
["OPFOR", "ammunition", 5000] call TWS_fnc_modifyResource;
["OPFOR", "fuel", 3000] call TWS_fnc_modifyResource;

// Set personalities
["BLUFOR", "balanced"] call TWS_fnc_setCommanderPersonality;
["OPFOR", "aggressive"] call TWS_fnc_setCommanderPersonality;

// Enable geopolitics for dynamic events
[true] call TWS_fnc_toggleGeopolitics;

// Done!
systemChat "[TWS] Mission setup complete!";
```

---

**You're ready to go! The autonomous world simulation is now running.**
