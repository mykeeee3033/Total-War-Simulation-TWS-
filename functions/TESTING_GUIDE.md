# TWS Testing & Validation Guide

## Pre-Flight Checklist

Before testing in Arma 3, verify these files exist:

```
✓ initServer.sqf (modified to load TWS)
✓ functions/TWS_init.sqf
✓ functions/core/worldState_custom.sqf
✓ functions/core/objectRoles.sqf
✓ functions/logistics/customLogistics.sqf
✓ functions/aliveHooks/aliveIntegration.sqf
✓ functions/radarAir/radarDefense_custom.sqf
✓ functions/commander/commanderPersonality.sqf
✓ functions/reports/chatGPTIntegration.sqf
✓ functions/core/geopolitics.sqf
✓ functions/core/civilianEconomy.sqf
```

## Testing Phases

### Phase 1: System Initialization (5 minutes)

**Load the mission in Arma 3 Editor**

1. Open the mission in Eden Editor
2. Click "Preview" to start mission
3. Watch for initialization messages in system chat:

Expected output:
```
[TWS] Initializing Total War Simulation system...
[TWS] ✓ World State loaded
[TWS] ✓ Object Roles loaded
[TWS] ✓ Custom Logistics loaded
[TWS] ✓ ALiVE Integration loaded
[TWS] ✓ Radar Defense loaded
[TWS] ✓ Commander Personality loaded
[TWS] ✓ ChatGPT Integration loaded
[TWS] ✓ Optional systems loaded (disabled)
========================================
[TWS] TOTAL WAR SIMULATION INITIALIZED
========================================
```

**✓ Pass Criteria**: All systems load without errors

**Debug if failed**:
```sqf
// Check initialization flag
hint str TWS_initialized;

// Check world state
hint str TWS_worldState;

// Check RPT log for errors
```

---

### Phase 2: Resource Management (10 minutes)

**Test resource tracking**

1. Open debug console (Esc → Debug Console)
2. Run test commands:

```sqf
// Test 1: Check initial resources
_blufor = ["BLUFOR"] call TWS_fnc_getResources;
hint str _blufor;
// Expected: HashMap with ammunition, fuel, materials, vehicles, aircraft

// Test 2: Add resources
["BLUFOR", "ammunition", 1000] call TWS_fnc_modifyResource;
_newAmmo = (["BLUFOR"] call TWS_fnc_getResources) get "ammunition";
hint format ["New ammo: %1", _newAmmo];
// Expected: Previous amount + 1000

// Test 3: Consume resources
_success = ["BLUFOR", "fuel", 500] call TWS_fnc_consumeResource;
hint format ["Consumed fuel: %1", _success];
// Expected: true

// Test 4: Try to consume more than available
_fail = ["BLUFOR", "fuel", 99999] call TWS_fnc_consumeResource;
hint format ["Should fail: %1", _fail];
// Expected: false
```

**✓ Pass Criteria**: All resource operations work correctly

---

### Phase 3: Factory System (15 minutes)

**Test factory assignment and production**

```sqf
// Test 1: Find a building
_buildings = nearestObjects [player, ["Building"], 200];
if (count _buildings > 0) then {
    _building = _buildings select 0;
    
    // Test 2: Assign factory role
    [_building, "munitionsFactory", "BLUFOR"] call TWS_fnc_assignObjectRole;
    hint "Factory assigned!";
    
    // Test 3: Check registration
    _factories = TWS_worldState get "factories";
    hint format ["Total factories: %1", count _factories];
    
    // Test 4: Check factory data
    _factoryData = _factories get (str _building);
    hint str _factoryData;
};

// Test 5: Wait and check production (after 5 minutes)
sleep 300;
_status = ["BLUFOR"] call TWS_fnc_getLogisticsStatus;
hint str _status;
```

**✓ Pass Criteria**: 
- Factory registers successfully
- Production occurs after 5 minutes
- Resources increase appropriately

---

### Phase 4: Operational Tempo (10 minutes)

**Test tempo calculation**

```sqf
// Test 1: Check initial tempo
_tempo = ["BLUFOR"] call TWS_fnc_getTempo;
hint format ["Initial tempo: %1", _tempo];
// Expected: 1.0 (or close)

// Test 2: Drain resources to trigger low tempo
["BLUFOR", "ammunition", -8000] call TWS_fnc_modifyResource;
["BLUFOR", "fuel", -4000] call TWS_fnc_modifyResource;

// Test 3: Wait for consumption cycle (10 minutes or force update)
["BLUFOR"] call TWS_fnc_updateTempo;
_newTempo = ["BLUFOR"] call TWS_fnc_getTempo;
hint format ["New tempo (should be low): %1", _newTempo];
// Expected: < 0.7

// Test 4: Restore resources
["BLUFOR", "ammunition", 15000] call TWS_fnc_modifyResource;
["BLUFOR", "fuel", 8000] call TWS_fnc_modifyResource;
["BLUFOR"] call TWS_fnc_updateTempo;
_highTempo = ["BLUFOR"] call TWS_fnc_getTempo;
hint format ["New tempo (should be high): %1", _highTempo];
// Expected: > 1.2
```

**✓ Pass Criteria**: Tempo adjusts based on resource levels

---

### Phase 5: Commander AI (10 minutes)

**Test commander personalities**

```sqf
// Test 1: Check initial personality
_commander = TWS_commanders get "BLUFOR";
hint str _commander;

// Test 2: Change personality
["BLUFOR", "aggressive"] call TWS_fnc_setCommanderPersonality;
_newCommander = TWS_commanders get "BLUFOR";
hint format ["Personality: %1", _newCommander get "personality"];
// Expected: "aggressive"

// Test 3: Test auto-adjustment
["BLUFOR", "ammunition", -9000] call TWS_fnc_modifyResource;
["BLUFOR"] call TWS_fnc_updateTempo;
["BLUFOR"] call TWS_fnc_autoAdjustPersonality;
_adjusted = TWS_commanders get "BLUFOR";
hint format ["Auto-adjusted to: %1", _adjusted get "personality"];
// Expected: "recovery" or "cautious"

// Test 4: Get OPCOM recommendations
_rec = ["BLUFOR"] call TWS_fnc_getOPCOMRecommendations;
hint str _rec;
```

**✓ Pass Criteria**: Personalities change appropriately

---

### Phase 6: Radar Defense (15 minutes)

**Test radar integration**

```sqf
// Test 1: Check if existing radar enhanced
if (!isNil "radar_2") then {
    [radar_2, "BLUFOR"] call TWS_fnc_enhanceRadarScript;
    hint "Radar enhanced!";
};

// Test 2: Check air defense readiness
_readiness = ["BLUFOR"] call TWS_fnc_getAirDefenseReadiness;
hint str _readiness;

// Test 3: Simulate scramble decision
_planes = []; // Empty pool for testing
_enemies = []; // No enemies
_result = [radar_2, "BLUFOR", _enemies, _planes] call TWS_fnc_radarScramble;
hint format ["Scramble result: %1", count _result];

// Test 4: Check resource consumption after scramble
// (If scramble occurred, check fuel/ammo decreased)
```

**✓ Pass Criteria**: Radar system integrates without errors

---

### Phase 7: Strategic Reports (30+ minutes)

**Test reporting system**

```sqf
// Test 1: Force immediate report generation
_report = [] call TWS_fnc_compileStrategicReport;
hint "Report generated!";

// Test 2: Format and export report
_text = [_report] call TWS_fnc_formatReportText;
[_report] call TWS_fnc_exportReport;
hint "Check RPT log for report";

// Test 3: Check report contents
hint str _report;
```

**Then wait 30 minutes for automatic report**

Check RPT log file for:
```
========== STRATEGIC REPORT START ==========
STRATEGIC SITUATION REPORT
...
========== STRATEGIC REPORT END ==========
```

**✓ Pass Criteria**: Reports generate with complete data

---

### Phase 8: Optional Systems (10 minutes)

**Test geopolitics**

```sqf
// Enable geopolitics
[true] call TWS_fnc_toggleGeopolitics;
hint "Geopolitics enabled";

// Manually trigger event
[] call TWS_fnc_triggerGeopoliticalEvent;
hint "Check for event message";

// Disable
[false] call TWS_fnc_toggleGeopolitics;
```

**Test civilian economy**

```sqf
// Enable civilian economy
[true] call TWS_fnc_toggleCivilianEconomy;
hint "Civilian economy enabled";

// Check status
_civStatus = ["BLUFOR"] call TWS_fnc_getCivilianEconomyStatus;
hint str _civStatus;

// Disable
[false] call TWS_fnc_toggleCivilianEconomy;
```

**✓ Pass Criteria**: Optional systems toggle without errors

---

### Phase 9: ALiVE Integration (If ALiVE present)

**Test ALiVE detection and integration**

```sqf
// Check ALiVE detection
_detected = TWS_aliveConfig get "aliveDetected";
hint format ["ALiVE detected: %1", _detected];

// If ALiVE present, check integration
if (_detected) then {
    // Verify OPCOM recommendations being applied
    _rec = ["BLUFOR"] call TWS_fnc_getOPCOMRecommendations;
    hint str _rec;
    
    // Check supply request system
    ["BLUFOR", "", "ammunition", 2] call TWS_fnc_requestALiVESupply;
    hint "Supply request sent (check logs)";
};
```

**✓ Pass Criteria**: ALiVE detected if present, integration functions work

---

### Phase 10: Long-term Test (1+ hours)

**Let the mission run**

1. Start mission
2. Assign several factories (3-5 per faction)
3. Set initial resources to moderate levels
4. Let mission run for 1+ hours (can use time acceleration)

**Monitor for:**
- Production cycles completing successfully
- Consumption cycles completing successfully
- Resources changing over time
- Tempo adjusting automatically
- Commander personalities adapting
- Strategic reports generating every 30 minutes
- No script errors in RPT log

**Check RPT log periodically**:
```
%LOCALAPPDATA%\Arma 3\
```

Look for `[TWS]` messages and any errors.

**✓ Pass Criteria**: System runs stable for extended period

---

## Common Issues & Solutions

### Issue: System doesn't initialize
**Solution**: Check initServer.sqf has the TWS_init.sqf call

### Issue: No production occurring
**Solution**: 
- Verify factories assigned: `hint str (TWS_worldState get "factories");`
- Check materials available: `hint str (["BLUFOR"] call TWS_fnc_getResources);`
- Wait full 5 minutes

### Issue: Tempo stuck at 1.0
**Solution**: Resources likely in normal range, drain some to test

### Issue: No reports in RPT
**Solution**: 
- Wait full 30 minutes
- Check RPT file location
- Verify chatGPTIntegration loaded

### Issue: Script errors in RPT
**Solution**: 
- Note the specific error
- Check which script is failing
- Verify all dependencies loaded in correct order

---

## Performance Monitoring

**Check FPS impact**

```sqf
// Before TWS
_fpsBefore = diag_fps;

// After 30 minutes of TWS running
_fpsAfter = diag_fps;

// Calculate impact
_impact = _fpsBefore - _fpsAfter;
hint format ["FPS impact: %1", _impact];
// Expected: < 5 FPS impact
```

**Check script execution time**

Look in RPT log for:
```
[TWS] Production cycle completed in X ms
[TWS] Consumption cycle completed in X ms
```

Expected: < 10ms per cycle

---

## Success Criteria

The system is working correctly if:

✓ All 7 phases initialize without errors  
✓ Resources can be added, modified, and consumed  
✓ Factories register and produce resources  
✓ Operational tempo adjusts based on resources  
✓ Commander personalities adapt to situation  
✓ Radar system integrates successfully  
✓ Strategic reports generate every 30 minutes  
✓ Optional systems can be toggled  
✓ No script errors in RPT log  
✓ FPS impact < 5  
✓ System stable for 1+ hours  

---

## Reporting Issues

If issues found:

1. Note the specific test that failed
2. Copy relevant RPT log entries
3. Note mission conditions (mods loaded, multiplayer/SP, etc.)
4. Save debug console output
5. Document steps to reproduce

---

**Testing complete when all phases pass!**
