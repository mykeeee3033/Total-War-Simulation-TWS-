// Initialize Total War Simulation - ALiVE Integration System
[] execVM "functions\TWS_init.sqf";

// Initialize Basic Resource System (ground zero version)
[] execVM "basicResources.sqf";

//init self fileExists
//[] execVM "support_manager.sqf";
//[] execVM "radar_system.sqf"; //holy shit that took forever to make
//[] execVM "radar_pool_detection.sqf";
//[] execVM "radar_blu.sqf";
//[] execVM "radar_opf.sqf";

addMissionEventHandler ["EntityCreated", {
  params ["_entity"];
  _validEntity = _entity isKindOf "CAManBase" || _entity in vehicles;
  if(!dynamicSimulationEnabled _entity && _validEntity)then
  {
	if(!isNull (group _entity))then{_entity = group _entity};
	_entity enableDynamicSimulation true;
  };
}];

[[1,1,2,0,0,0,false],"RCO\RCOPersist\RCOcrateFiller.sqf"] remoteExec["execVM",0];

