// Initialize Total War Simulation - ALiVE Integration System
//[] execVM "functions\TWS_init.sqf";

// Initialize Basic Resource System (ground zero version)
[] execVM "basicResources.sqf";

//init self fileExists
//[] execVM "battlefield_intelligenceOPF.sqf"; //soon to be outdated
//[] execVM "s_opfor_resuply_heli_SIMPLE.sqf";
//[] execVM "vehicle_fabrication.sqf";
//[] execVM "support_manager.sqf";
//[] spawn { sleep 60; [] execVM "radar_system.sqf"; }; //holy shit that took forever to make - delayed 1 min
//[] spawn { sleep 45; [] execVM "monitor_supplies_testbed.sqf"; };
//[] execVM "radar_pool_detection.sqf";
//[] execVM "radar_blu.sqf";
//[] execVM "radar_opf.sqf";
//[] execVM "simple_airbase_detection.sqf";
//[] execVM "static_defenses.sqf";

//for server and website
[] execVM "customA3DJSCommands.sqf";
[] execVM "deathCounter.sqf";
[] execVM "opforDeathCounter.sqf";
[] execVM "bluforDeathCounter.sqf";
[] execVM "opforDeathStats.sqf";
[] execVM "bluforDeathStats.sqf";
[] spawn { sleep 15; [] execVM "infantrySimple.sqf"; };






// Delay RCO persist auto detailed load by 2 minutes
//[] spawn { sleep 120; "RCOP\RCOPersist\fn_RCOPcrateFiller.sqf" remoteExec["execVM",0]; };


// Dynamic simulation disabled for better Zeus gameplay
// addMissionEventHandler ["EntityCreated", {
//   params ["_entity"];
//   _validEntity = _entity isKindOf "CAManBase" || _entity in vehicles;
//   if(!dynamicSimulationEnabled _entity && _validEntity)then
//   {
// 	if(!isNull (group _entity))then{_entity = group _entity};
// 	_entity enableDynamicSimulation true;
//   };
// }];

// Delay RCO persist auto detailed load by 2 minutes
//[] spawn { sleep 120; [[1,1,2,0,0,0,false],"RCO\RCOPersist\RCOcrateFiller.sqf"] remoteExec["execVM",0]; };

