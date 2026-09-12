//Must do for basic resources to persist. Will load RES persist init first before initializing RES + updated persisted information
if (isServer) then {
    call compile preprocessFileLineNumbers "initPersistentResources.sqf";
    [] execVM "basicResources.sqf";
    };

//init self fileExists
[] execVM "battlefield_intelligenceOPF.sqf"; // gives stats on opfor deaths, gives recommendations, battlefield sitrep eval
//[] spawn { sleep 90; [] execVM "s_opfor_resuply_heli_SIMPLE.sqf";}; //a part of the opf intel supply chain that scans FOBS (communication hub) which the AI commander will issue a supply missions once the cargo net crate at that fob drops below 50% capacity
[] execVM "vehicle_fabrication.sqf"; //depends on battlefield_intelOPF to spawn recommended vehicles to counter bluf attacks/occupation
//[] execVM "support_manager.sqf"; // opfor support system that requires manpower to spawn
[] spawn { sleep 60; [] execVM "radar_system.sqf"; }; //holy shit that took forever to make - delayed 1 min
[] execVM "static_defenses.sqf"; //virtualizes all statics map wide (empty and occupied)
[] execVM "combat_monitor.sqf"; //monitors global entities and places Troops in contact markers
[] execVM "auto_unit_FOB_resupply.sqf"; // global 3 minute call for units within 50 of cargo nets (FOB MARKERS) to resupply at that cargo net

//[] execVM "monitor_ammo.sqf"; //blufor ammo resupply dispatch with nearby ammo trucks near bluf_HQ obj
[] execVM "game_time_export_inidbi2.sqf"; //dedicated INIDBI2 game-time clock for external countdown sync
[] execVM "hub_supply_export_inidbi2.sqf"; //3-minute export of communication hub cargo-net supply levels to INIDBI2 to TWS_logisticsIntel.ini
[] execVM "recon_intelligence_opf.sqf"; //OPFOR visual recon marks spotted BLUFOR assets with type/size/status/vector
[] execVM "opfor_AI_commander_main.sqf";
[] spawn { sleep 120; [] execVM "global_virtualize.sqf"; };// auto-virtualize Zeus-placed AI groups only (ignores scripted spawns)
[] execVM "virtualize_test.sqf";
//Electronic Warfare scripts
[] execVM "emp_blackout.sqf"; //2km  -1000 electricity cost EMP where it disables the ability for the AI to use vehicles
[] execVM "radar_jamming.sqf"; //Script that allows the selection of Tier 1/2 to jam Radar systems and disable sortie responses
[] execVM "aa_sam_balance.sqf"; // makes the AA not annoying
[] execVM "ew_strike.sqf"; //listens for ALiVE OCA(the alive air component commander) requests and launches combined air + ground strikes

//Comms scripts
[] execVM "comm_network.sqf"; //Tracks friendly comms coverage and draws network markers





// Outdated scripts
//[] execVM "radar_pool_detection.sqf"; //dependency of radar_blu/opf
//[] execVM "radar_blu.sqf"; //depracated
//[] execVM "radar_opf.sqf";//depracated
//[] execVM "simple_airbase_detection.sqf"; //testing if it is a dependency of radar_system (disabled)
//[] spawn { sleep 35; [] execVM "monitor_supplies_testbed.sqf"; }; //only used for debug purposes and gives data on supply crates at opcom objs (found in functions folder - so wrong exe path)


//for server and website
//[] execVM "customA3DJSCommands.sqf";
//[] execVM "deathCounter.sqf";
//[] execVM "opforDeathCounter.sqf";
//[] execVM "bluforDeathCounter.sqf"; //just tracks death counts, thats all
//[] execVM "opforDeathStats.sqf"; //tracks unit death types (killedBy_type), stores data, gives death statistics
//[] execVM "bluforDeathStats.sqf"; 
//[] spawn { sleep 15; [] execVM "infantrySimple.sqf"; }; //scans all infantry groups and gives information on their sitrep






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

