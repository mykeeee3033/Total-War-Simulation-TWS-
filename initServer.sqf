
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