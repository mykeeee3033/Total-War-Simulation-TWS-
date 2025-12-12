# TWS Enhanced Systems - Implementation Guide

## Overview
This document describes the comprehensive enhancements added to the Total War Simulation (TWS) system. All new features are designed to work seamlessly with existing TWS infrastructure and are focused primarily on OPFOR faction as requested.

## New Systems Implemented

### 1. Marker System (`markerSystem.sqf`)
**Purpose**: Provides visual feedback on strategic objects and events

**Features**:
- Persistent markers for factories, antennas, power stations, FOBs, HQ, radar sites
- Color-coded icons based on object type and faction
- Status updates (operational/destroyed) reflected in markers
- Fading event markers for temporary events

**Functions**:
- `TWS_fnc_createObjectMarker` - Create marker for strategic object
- `TWS_fnc_updateObjectMarker` - Update marker status
- `TWS_fnc_createAllObjectMarkers` - Create all markers at mission start
- `TWS_fnc_createEventMarker` - Create temporary event marker
- `TWS_fnc_createCombatMarker` - Create combat contact marker

### 2. Notification System (`notificationSystem.sqf`)
**Purpose**: Centralized event notification with visual feedback

**Features**:
- Notifications for training, resupply, orders, sector changes, production
- Optional markers for each event type
- Notification history tracking
- Configurable fade times for markers

**Event Types**:
- `training` - Training events (green)
- `resupply` - Resupply operations (yellow)
- `orders` - Order executions (blue)
- `sectorChange` - Sector status changes (orange)
- `production` - Production events (purple)
- `reinforcement` - Reinforcement deployments (red)
- `combat` - Combat events (red)
- `general` - General notifications (white)

**Functions**:
- `TWS_fnc_notify` - Send notification
- `TWS_fnc_notifyTraining` - Notify training event
- `TWS_fnc_notifyResupply` - Notify resupply
- `TWS_fnc_notifyOrderExecution` - Notify order execution
- `TWS_fnc_notifySectorChange` - Notify sector change
- `TWS_fnc_notifyProduction` - Notify production
- `TWS_fnc_notifyReinforcement` - Notify reinforcement
- `TWS_fnc_notifyCombat` - Notify combat event

### 3. Enhanced Combat Monitor (`enhancedCombatMonitor.sqf`)
**Purpose**: Detailed combat tracking with visual markers

**Features**:
- 2-minute casualty summaries
- Squad identification on contact markers
- Per-faction casualty tracking
- Combat position tracking
- Automatic manpower resupply triggering

**Configuration**:
```sqf
TWS_combat set ["summaryInterval", 120]; // 2 minutes between summaries
```

**Functions**:
- `TWS_fnc_trackCasualty` - Track unit casualty
- `TWS_fnc_generateCasualtySummary` - Generate summary report
- `TWS_fnc_getRecentCombat` - Get recent combat positions
- `TWS_fnc_getCasualtyStats` - Get casualty statistics

### 4. Sector Area System (`sectorAreaSystem.sqf`)
**Purpose**: Dynamic sector control with unit scanning

**Features**:
- Radius-based unit detection (200m default)
- 3-state system: OCCUPIED, CONTESTED, CAPTURED
- Per-minute status checks
- Ammo/supply scanning
- Resupply priority calculation

**Sector States**:
- `OCCUPIED` - Faction controls sector
- `CONTESTED` - Both factions present
- `CAPTURED` - Recently captured by enemy

**Configuration**:
```sqf
TWS_sectorAreas set ["scanRadius", 200]; // Unit scan radius
TWS_sectorAreas set ["scanInterval", 60]; // Check every 60 seconds
```

**Functions**:
- `TWS_fnc_registerSectorArea` - Register new sector
- `TWS_fnc_scanSectorArea` - Scan for units
- `TWS_fnc_scanSectorAmmo` - Scan ammo levels
- `TWS_fnc_calculateResupplyPriority` - Calculate priority
- `TWS_fnc_getSectorsNeedingResupply` - Get resupply queue
- `TWS_fnc_addSectorResources` - Deliver resources

### 5. Dynamic Resupply System (`dynamicResupply.sqf`)
**Purpose**: Automated ground resupply via trucks

**Features**:
- Priority-based resupply queue
- Truck spawning with drivers
- Waypoint-based delivery system
- Resource delivery on arrival
- Driver auto-despawn at base
- 5-minute execution cycle (configurable)

**Configuration**:
```sqf
TWS_resupply set ["interval", 300]; // 5 minutes
TWS_resupply set ["baseMarker", "opfor_spawn"]; // OPFOR base
TWS_resupply set ["resourcesPerDelivery", 50];
```

**Functions**:
- `TWS_fnc_spawnResupplyTruck` - Spawn resupply convoy
- `TWS_fnc_deliverResupply` - Deliver resources
- `TWS_fnc_processResupplyQueue` - Process queue
- `TWS_fnc_toggleResupply` - Enable/disable system

### 6. Manpower Resupply System (`manpowerResupply.sqf`)
**Purpose**: Automatic manpower reinforcement via aircraft

**Features**:
- Triggers every 100 casualties
- Aircraft spawning for delivery
- Airport landing logic
- 200 manpower points per delivery
- Based on airport_logi_opfor.sqf

**Configuration**:
```sqf
TWS_manpowerResupply set ["casualtyThreshold", 100];
TWS_manpowerResupply set ["manpowerPerDelivery", 200];
TWS_manpowerResupply set ["OPFOR_spawnMarker", "logi_spawn_opfor"];
TWS_manpowerResupply set ["OPFOR_airportMarker", "cargo_depot_o"];
```

**Functions**:
- `TWS_fnc_triggerManpowerResupply` - Trigger resupply
- `TWS_fnc_spawnManpowerAircraft` - Spawn aircraft
- `TWS_fnc_deliverManpower` - Deliver manpower
- `TWS_fnc_checkManpowerResupplyTrigger` - Check trigger

### 7. Enhanced Production System (`enhancedProduction.sqf`)
**Purpose**: Vehicle production based on combat losses

**Features**:
- Vehicle loss tracking
- Weighted production queue
- Factory-based spawning
- Driver spawning with waypoints
- Auto-despawn on delivery
- 10-minute production cycles

**Vehicle Types**:
- `transport` - Trucks
- `apc` - APCs/IFVs
- `armor` - Tanks/MBTs
- `aircraft` - Helicopters/Planes

**Configuration**:
```sqf
TWS_enhancedProduction set ["productionInterval", 600]; // 10 minutes
```

**Functions**:
- `TWS_fnc_trackVehicleLoss` - Track vehicle destroyed
- `TWS_fnc_calculateProductionNeeds` - Calculate needs
- `TWS_fnc_queueProductionFromLosses` - Queue production
- `TWS_fnc_spawnProducedVehicle` - Spawn vehicle with driver

### 8. Dynamic Reinforcements (`dynamicReinforcements.sqf`)
**Purpose**: Quick reaction reinforcement system

**Features**:
- Light/Medium/Heavy reinforcement levels
- FOB and main base spawning
- Manpower resource checks
- 3-minute cooldown between deployments
- Scales with threat level

**Reinforcement Levels**:
- `light` - 1 truck + squad (10 manpower)
- `medium` - 2 APCs + squads (30 manpower)
- `heavy` - Tanks, APCs, trucks, squads, heli (80 manpower)

**Configuration**:
```sqf
TWS_reinforcements set ["cooldown", 180]; // 3 minutes
TWS_reinforcements set ["light_cost", 10];
TWS_reinforcements set ["medium_cost", 30];
TWS_reinforcements set ["heavy_cost", 80];
```

**Functions**:
- `TWS_fnc_deployReinforcements` - Deploy reinforcements
- `TWS_fnc_hasEnoughManpower` - Check manpower
- `TWS_fnc_findNearestFOB` - Find FOB with resources
- `TWS_fnc_spawnLightReinforcement` - Spawn light
- `TWS_fnc_spawnMediumReinforcement` - Spawn medium
- `TWS_fnc_spawnHeavyReinforcement` - Spawn heavy

### 9. Enhanced Communication Grid (`communicationEnhanced.sqf`)
**Purpose**: Track communication/electrical infrastructure

**Features**:
- Tracks antennas, power stations, HQ nodes
- Calculates grid integrity (0.0-1.0)
- Performance penalty when damaged
- Reinforcement cooldown increases
- Per-minute status checks

**Configuration**:
```sqf
TWS_commGrid set ["checkInterval", 60]; // Check every minute
```

**Functions**:
- `TWS_fnc_updateCommGrid` - Update grid status
- `TWS_fnc_canOperateEffectively` - Check if can operate
- `TWS_fnc_applyPerformanceDegradation` - Apply penalties
- `TWS_fnc_getGridStatus` - Get status

### 10. Enhanced Radar System (`enhancedRadarSystem.sqf`)
**Purpose**: Advanced radar and air defense

**Features**:
- Airspace violation detection
- Automatic scramble orders
- Sortie tracking and management
- Communication grid integration
- 5km detection range default

**Configuration**:
```sqf
TWS_radarSystem set ["detectionRange", 5000]; // 5km
TWS_radarSystem set ["responseCoefficient", 2]; // 2:1 ratio
```

**Functions**:
- `TWS_fnc_registerRadarSite` - Register radar
- `TWS_fnc_detectAirspaceViolation` - Detect violations
- `TWS_fnc_scrambleInterceptors` - Scramble aircraft
- `TWS_fnc_getActiveSorties` - Get active sorties
- `TWS_fnc_getSortieStats` - Get statistics

## Initialization

### Order of Initialization
All systems are initialized via `TWS_initEnhanced.sqf` which is called from `TWS_init.sqf`:

1. Marker System
2. Notification System
3. Enhanced Combat Monitor
4. Sector Area System
5. Dynamic Resupply
6. Manpower Resupply
7. Enhanced Production
8. Dynamic Reinforcements
9. Communication Grid
10. Enhanced Radar System

### Manual Initialization
If needed, systems can be initialized individually:

```sqf
[] execVM "functions\markers\markerSystem.sqf";
[] execVM "functions\markers\notificationSystem.sqf";
// etc...
```

## Configuration

### Global Variables
All systems expose configuration hashmaps:
- `TWS_markers` - Marker system config
- `TWS_notifications` - Notification config
- `TWS_combat` - Combat monitor config
- `TWS_sectorAreas` - Sector system config
- `TWS_resupply` - Resupply config
- `TWS_manpowerResupply` - Manpower config
- `TWS_enhancedProduction` - Production config
- `TWS_reinforcements` - Reinforcement config
- `TWS_commGrid` - Communication grid config
- `TWS_radarSystem` - Radar system config

### Enabling/Disabling Systems
Most systems can be toggled:

```sqf
[true] call TWS_fnc_toggleNotifications; // Enable notifications
[false] call TWS_fnc_toggleResupply; // Disable resupply
[true] call TWS_fnc_toggleManpowerResupply; // Enable manpower resupply
```

## Integration Points

### With Existing Scripts
- **combat_monitor.sqf**: Enhanced by `enhancedCombatMonitor.sqf`
- **support_manager.sqf**: Logic used in `dynamicReinforcements.sqf`
- **s1.sqf, s2.sqf, s3.sqf**: Referenced for reinforcement spawning
- **airport_logi_opfor.sqf**: Logic used in `manpowerResupply.sqf`
- **radar_opf.sqf**: Enhanced by `enhancedRadarSystem.sqf`
- **radar_pool_detection.sqf**: Used by enhanced radar system

### With TWS Core
All enhanced systems integrate with:
- `TWS_worldState` - Global state tracking
- `TWS_objectRoles` - Object role assignment
- `TWS_sectors` - Sector management
- `TWS_productionQueues` - Production system
- `TWS_commanders` - Commander AI

## Debugging

### System Chat Messages
All systems provide real-time feedback via systemChat:
```
[TWS] Marker System initialized
[TWS] OPFOR resupply convoy dispatched to sector_1
[TWS] BLUFOR: 5 casualties (Total: 23)
[TWS] Sector sector_2: OCCUPIED (OPFOR) -> CONTESTED
```

### Diagnostic Logs
Detailed logs written to diag_log:
```
[TWS] Created marker tws_obj_munitionsFactory_123 for munitionsFactory at [1234,5678,0]
[TWS] Tracked vehicle loss: OPFOR apc (total: 3)
[TWS] Deployed OPFOR heavy reinforcements from [1000,2000,0] to [3000,4000,0]
```

### Query Functions
Get system status:
```sqf
// Get casualty stats
_stats = [] call TWS_fnc_getCasualtyStats;

// Get sectors needing resupply
_sectors = ["OPFOR"] call TWS_fnc_getSectorsNeedingResupply;

// Get active sorties
_sorties = [] call TWS_fnc_getActiveSorties;

// Get notification history
_history = ["combat", 10] call TWS_fnc_getNotificationHistory;

// Get grid status
_status = ["OPFOR"] call TWS_fnc_getGridStatus;
```

## Performance Considerations

### Update Intervals
Default intervals are balanced for performance:
- Sector scanning: 60 seconds
- Combat summaries: 120 seconds
- Resupply cycles: 300 seconds
- Production cycles: 600 seconds
- Grid checks: 60 seconds
- Radar checks: 5 seconds

### Optimizations
- Markers use efficient creation and deletion
- Sector scanning limited to configured radius
- Vehicle loss tracking is event-driven
- Sortie cleanup runs every 30 seconds
- History arrays capped at reasonable limits

## Troubleshooting

### Common Issues

**Markers not appearing**:
- Check `TWS_fnc_createAllObjectMarkers` was called
- Verify objects are registered in `TWS_objectRoles`

**Resupply not triggering**:
- Check sector ammo levels with `TWS_fnc_scanSectorAmmo`
- Verify sector ownership matches faction
- Check `TWS_resupply` enabled setting

**Reinforcements not deploying**:
- Check manpower resources
- Verify cooldown period has passed
- Check communication grid integrity

**Radar not scrambling**:
- Verify radar object is registered
- Check aircraft pool availability
- Verify communication grid operational

## Future Enhancements

Potential additions for future updates:
- Multi-faction sector ownership
- Advanced AI decision-making for production
- Dynamic resource distribution
- Weather effects on operations
- Supply line interdiction
- Electronic warfare systems
- Combined arms coordination

## Credits

Enhanced systems built on existing TWS framework by extending core functionality while maintaining compatibility with ALiVE and other mods.

All scripts designed for server-side execution with automatic client synchronization via publicVariable.
