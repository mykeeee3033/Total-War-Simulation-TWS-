addMissionEventHandler ["EntityKilled", { 
	params ["_unit", "_killer", "_instigator", "_useEffects"]; 
	_side = side group _unit;
	if (local _unit) then {
		[_side, -1] call BIS_fnc_respawnTickets; 
	};
}];