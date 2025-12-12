/*
 * TWS_intervals.sqf
 * Configurable Update Intervals for TWS System
 * 
 * This file allows easy adjustment of all timing intervals in the system
 * Modify these values to speed up or slow down various operations
 */

if (isServer) then {
    // Create intervals configuration
    TWS_intervals = createHashMap;
    
    // ============================================================
    // CORE SYSTEM INTERVALS
    // ============================================================
    
    // Commander AI update interval (seconds)
    // How often the commander AI evaluates situation and adjusts personality
    TWS_intervals set ["CommanderUpdateInterval", 120]; // 2 minutes
    
    // Economy/Logistics tick interval (seconds)
    // How often production and consumption cycles run
    TWS_intervals set ["EconomyTickInterval", 300]; // 5 minutes
    
    // Consumption cycle interval (seconds)
    // How often resources are consumed
    TWS_intervals set ["ConsumptionInterval", 600]; // 10 minutes
    
    // Strategic report generation interval (seconds)
    // How often battlefield reports are generated
    TWS_intervals set ["StrategyReportInterval", 1800]; // 30 minutes
    
    // ============================================================
    // COMBAT & REINFORCEMENT INTERVALS
    // ============================================================
    
    // Reinforcement check interval (seconds)
    // How often system checks if reinforcements are needed
    TWS_intervals set ["ReinforcementCheckInterval", 90]; // 1.5 minutes
    
    // Combat monitoring interval (seconds)
    // How often combat situations are evaluated
    TWS_intervals set ["CombatMonitorInterval", 60]; // 1 minute
    
    // Troops in contact response time (seconds)
    // Delay before responding to troops in contact
    TWS_intervals set ["TroopsInContactResponseTime", 30]; // 30 seconds
    
    // ============================================================
    // PRODUCTION & LOGISTICS INTERVALS
    // ============================================================
    
    // Production queue processing interval (seconds)
    // How often production queues are processed
    TWS_intervals set ["ProductionQueueInterval", 180]; // 3 minutes
    
    // Factory check interval (seconds)
    // How often factory status is checked
    TWS_intervals set ["FactoryCheckInterval", 300]; // 5 minutes
    
    // Supply convoy spawn interval (seconds)
    // Minimum time between supply convoy spawns
    TWS_intervals set ["SupplyConvoyInterval", 900]; // 15 minutes
    
    // Logistics resupply check interval (seconds)
    // How often system checks if locations need resupply
    TWS_intervals set ["LogisticsCheckInterval", 600]; // 10 minutes
    
    // ============================================================
    // SECTOR & BASE MANAGEMENT INTERVALS
    // ============================================================
    
    // Sector evaluation interval (seconds)
    // How often sectors are evaluated for priority
    TWS_intervals set ["SectorEvaluationInterval", 240]; // 4 minutes
    
    // Base building check interval (seconds)
    // How often system checks if bases need building
    TWS_intervals set ["BaseBuildingInterval", 300]; // 5 minutes
    
    // Defensive position spawn interval (seconds)
    // How often defensive positions are evaluated for spawning
    TWS_intervals set ["DefensivePositionInterval", 180]; // 3 minutes
    
    // FOB/POI status update interval (seconds)
    // How often FOB and POI status is updated
    TWS_intervals set ["FOBStatusInterval", 120]; // 2 minutes
    
    // ============================================================
    // INTELLIGENCE & MONITORING INTERVALS
    // ============================================================
    
    // Debug update interval (seconds)
    // How often debug information is displayed
    TWS_intervals set ["DebugUpdateInterval", 120]; // 2 minutes
    
    // Battlefield intelligence update (seconds)
    // How often intelligence data is compiled
    TWS_intervals set ["IntelligenceUpdateInterval", 180]; // 3 minutes
    
    // Radar system scan interval (seconds)
    // How often radar systems scan for threats
    TWS_intervals set ["RadarScanInterval", 10]; // 10 seconds
    
    // RND research tick interval (seconds)
    // How often RND buildings provide intelligence
    TWS_intervals set ["RNDTickInterval", 600]; // 10 minutes
    
    // ============================================================
    // MORALE & TRAINING INTERVALS
    // ============================================================
    
    // Morale calculation interval (seconds)
    // How often morale is recalculated
    TWS_intervals set ["MoraleUpdateInterval", 300]; // 5 minutes
    
    // Training cycle duration (seconds)
    // How long a training cycle takes
    TWS_intervals set ["TrainingCycleDuration", 600]; // 10 minutes
    
    // Training check interval (seconds)
    // How often system checks if training should start
    TWS_intervals set ["TrainingCheckInterval", 180]; // 3 minutes
    
    // ============================================================
    // REPAIR & CONSTRUCTION INTERVALS
    // ============================================================
    
    // Construction/repair check interval (seconds)
    // How often damaged facilities are checked for repair
    TWS_intervals set ["ConstructionCheckInterval", 240]; // 4 minutes
    
    // Repair completion time base (seconds)
    // Base time to repair a facility (modified by damage level)
    TWS_intervals set ["RepairCompletionTimeBase", 300]; // 5 minutes
    
    // ============================================================
    // COMMUNICATION & SUPPORT INTERVALS
    // ============================================================
    
    // Communication grid check interval (seconds)
    // How often antenna coverage is evaluated
    TWS_intervals set ["CommunicationCheckInterval", 120]; // 2 minutes
    
    // Electricity grid update interval (seconds)
    // How often power grid status is updated
    TWS_intervals set ["ElectricityUpdateInterval", 180]; // 3 minutes
    
    // Air support response time (seconds)
    // Time it takes to scramble air support
    TWS_intervals set ["AirSupportResponseTime", 45]; // 45 seconds
    
    // ============================================================
    // ALiVE INTEGRATION INTERVALS
    // ============================================================
    
    // ALiVE OPCOM sync interval (seconds)
    // How often TWS syncs with ALiVE OPCOM
    TWS_intervals set ["ALiVEOPCOMSyncInterval", 600]; // 10 minutes
    
    // ALiVE supply request interval (seconds)
    // How often TWS can request ALiVE supply convoys
    TWS_intervals set ["ALiVESupplyRequestInterval", 900]; // 15 minutes
    
    // ============================================================
    // HELPER FUNCTIONS
    // ============================================================
    
    // Function to get an interval value
    TWS_fnc_getInterval = {
        params ["_intervalName"];
        TWS_intervals getOrDefault [_intervalName, 120] // Default 2 minutes
    };
    
    // Function to set an interval value
    TWS_fnc_setInterval = {
        params ["_intervalName", "_value"];
        TWS_intervals set [_intervalName, _value max 1]; // Minimum 1 second
        diag_log format ["[TWS] Interval '%1' set to %2 seconds", _intervalName, _value];
    };
    
    // Function to get all intervals
    TWS_fnc_getAllIntervals = {
        TWS_intervals
    };
    
    // Function to apply interval multiplier (for testing)
    TWS_fnc_applyIntervalMultiplier = {
        params ["_multiplier"];
        {
            private _key = _x;
            private _value = _y;
            TWS_intervals set [_key, (_value * _multiplier) max 1];
        } forEach TWS_intervals;
        systemChat format ["[TWS] All intervals multiplied by %1", _multiplier];
        diag_log format ["[TWS] All intervals multiplied by %1", _multiplier];
    };
    
    // Make functions public
    publicVariable "TWS_intervals";
    publicVariable "TWS_fnc_getInterval";
    publicVariable "TWS_fnc_setInterval";
    publicVariable "TWS_fnc_getAllIntervals";
    publicVariable "TWS_fnc_applyIntervalMultiplier";
    
    diag_log "[TWS] Intervals configuration loaded";
    diag_log format ["[TWS] Commander Update: %1s", TWS_intervals get "CommanderUpdateInterval"];
    diag_log format ["[TWS] Economy Tick: %1s", TWS_intervals get "EconomyTickInterval"];
    diag_log format ["[TWS] Debug Update: %1s", TWS_intervals get "DebugUpdateInterval"];
    
    systemChat "[TWS] Intervals configuration loaded";
    systemChat format ["[TWS] Use 'TWS_intervals' to view all intervals"];
    systemChat format ["[TWS] Use '[""IntervalName"", newValue] call TWS_fnc_setInterval' to modify"];
};
