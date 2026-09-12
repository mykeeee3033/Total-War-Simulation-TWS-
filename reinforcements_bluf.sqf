/*
 * reinforcements_bluf.sqf
 *
 * Players can request NATO reinforcements directly from scroll wheel actions.
 *
 * Requests (scroll wheel addAction):
 * 1) Ground reinforcements (helicopter insertion)
 * 2) Mechanized reinforcements (2 Badger APC + 2 fireteams)
 * 3) Armour reinforcements (tank platoon + 1 AA)
 */

if (isNil "PRR_initialized") then {
	PRR_initialized = true;
	PRR_requestCooldown = 120; // per-player cooldown in seconds
	PRR_requestCooldownByUID = createHashMap;
	PRR_resourceIndex = 3; // Manpower in basicResources: 0=Fuel,1=Supplies,2=Fabrication,3=Manpower,4=Electricity
	PRR_costGround = 20;
	PRR_costMech = 40;
	PRR_costArmour = 80;
};

PRR_fnc_notifyPlayer = {
	params ["_msg", ["_target", objNull]];
	if (isNull _target) exitWith { systemChat _msg; };
	[_msg] remoteExecCall ["systemChat", _target];
};

PRR_fnc_getGroupConfig = {
	params ["_candidates"];

	private _cfg = configNull;
	{
		if (isClass _x) exitWith { _cfg = _x; };
	} forEach _candidates;

	_cfg
};

PRR_fnc_spawnVehicleCrewed = {
	params ["_pos", "_dir", "_vehicleClass"];
	[_pos, _dir, _vehicleClass, west] call BIS_fnc_spawnVehicle
};

PRR_fnc_getSafeSpawnPos = {
	params ["_targetPos", "_min", "_max", ["_fallbackOffset", [0, 0, 0]]];

	private _spawnPos = [_targetPos, _min, _max, 8, 0, 0.3, 0, [], [_targetPos, _targetPos]] call BIS_fnc_findSafePos;
	if (_spawnPos distance2D [0, 0, 0] <= 0) then {
		_spawnPos = [
			(_targetPos select 0) + (_fallbackOffset select 0),
			(_targetPos select 1) + (_fallbackOffset select 1),
			0
		];
	};

	_spawnPos
};

PRR_fnc_checkAndSetCooldown = {
	params ["_requester"];

	private _uid = getPlayerUID _requester;
	if (_uid == "") exitWith {false};

	private _now = time;
	private _last = PRR_requestCooldownByUID getOrDefault [_uid, -9999];

	if ((_now - _last) < PRR_requestCooldown) exitWith {
		private _remain = ceil (PRR_requestCooldown - (_now - _last));
		[format ["[Reinforce] Cooldown active: %1s remaining", _remain], _requester] call PRR_fnc_notifyPlayer;
		false
	};

	PRR_requestCooldownByUID set [_uid, _now];
	true
};

PRR_fnc_getRequestCost = {
	params ["_requestType"];

	switch (_requestType) do {
		case "ground": { PRR_costGround };
		case "mech": { PRR_costMech };
		case "armour": { PRR_costArmour };
		default { -1 };
	};
};

PRR_fnc_checkAndConsumeResources = {
	params ["_requester", "_requestType"];

	private _cost = [_requestType] call PRR_fnc_getRequestCost;
	if (_cost < 0) exitWith {
		["[Reinforce] Unknown request type for resource check", _requester] call PRR_fnc_notifyPlayer;
		false
	};

	if (isNil "RES_fnc_getResources" || isNil "RES_fnc_modifyResource") exitWith {
		["[Reinforce] Resource system unavailable - request denied", _requester] call PRR_fnc_notifyPlayer;
		false
	};

	private _bluResources = ["BLUFOR"] call RES_fnc_getResources;
	if (count _bluResources <= PRR_resourceIndex) exitWith {
		["[Reinforce] Resource data invalid - request denied", _requester] call PRR_fnc_notifyPlayer;
		false
	};

	private _currentPoints = _bluResources select PRR_resourceIndex;
	if (_currentPoints < _cost) exitWith {
		[format ["[Reinforce] Not enough manpower: need %1, have %2", _cost, _currentPoints], _requester] call PRR_fnc_notifyPlayer;
		false
	};

	["BLUFOR", PRR_resourceIndex, -_cost] call RES_fnc_modifyResource;
	[format ["[Reinforce] %1 manpower spent (%2 remaining)", _cost, (_currentPoints - _cost) max 0], _requester] call PRR_fnc_notifyPlayer;
	true
};

PRR_fnc_spawnGroundReinforcements = {
	params ["_requester"];

	private _targetPos = getPosATL _requester;
	private _spawnPos = [_targetPos, 1200, 1800, [0, 1500, 0]] call PRR_fnc_getSafeSpawnPos;
	private _lz = [_targetPos, 40, 120, [20, 20, 0]] call PRR_fnc_getSafeSpawnPos;

	private _heliData = [_spawnPos, random 360, "B_Heli_Transport_01_F"] call PRR_fnc_spawnVehicleCrewed;
	_heliData params ["_heli", "_heliCrew", "_heliGroup"];

	private _squadCfg = [[
		configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfSquad"
	]] call PRR_fnc_getGroupConfig;

	if (isNull _squadCfg) exitWith {
		["[Reinforce] No valid group config for ground reinforcements", _requester] call PRR_fnc_notifyPlayer;
		{ deleteVehicle _x; } forEach _heliCrew;
		deleteVehicle _heli;
		deleteGroup _heliGroup;
	};

	private _infGroup = [_spawnPos, west, _squadCfg] call BIS_fnc_spawnGroup;
	{
		_x assignAsCargo _heli;
		_x moveInCargo _heli;
	} forEach (units _infGroup);

	private _wpMove = _heliGroup addWaypoint [_lz, 0];
	_wpMove setWaypointType "MOVE";
	_wpMove setWaypointSpeed "FULL";

	private _wpUnload = _heliGroup addWaypoint [_lz, 0];
	_wpUnload setWaypointType "TR UNLOAD";

	private _wpRTB = _heliGroup addWaypoint [_spawnPos, 0];
	_wpRTB setWaypointType "MOVE";

	private _wpInf = _infGroup addWaypoint [_targetPos, 0];
	_wpInf setWaypointType "MOVE";
	_wpInf setWaypointBehaviour "AWARE";

	[_heli, _heliCrew, _heliGroup] spawn {
		params ["_h", "_crew", "_grp"];
		sleep 420;
		{ if (!isNull _x) then { deleteVehicle _x; }; } forEach _crew;
		if (!isNull _h) then { deleteVehicle _h; };
		if (!isNull _grp) then { deleteGroup _grp; };
	};

	["[Reinforce] Ground reinforcements inbound by helicopter", _requester] call PRR_fnc_notifyPlayer;
};

PRR_fnc_spawnMechanizedReinforcements = {
	params ["_requester"];

	private _targetPos = getPosATL _requester;
	private _baseSpawn = [_targetPos, 900, 1400, [300, 1100, 0]] call PRR_fnc_getSafeSpawnPos;

	private _fireteamCfg = [[
		configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfTeam"
	]] call PRR_fnc_getGroupConfig;

	if (isNull _fireteamCfg) exitWith {
		["[Reinforce] No valid group config for mechanized fireteams", _requester] call PRR_fnc_notifyPlayer;
	};

	for "_i" from 0 to 1 do {
		private _spawnPos = [
			(_baseSpawn select 0) + (_i * 18),
			(_baseSpawn select 1) + (_i * 14),
			0
		];

		private _apcData = [_spawnPos, random 360, "B_APC_Wheeled_01_cannon_F"] call PRR_fnc_spawnVehicleCrewed;
		_apcData params ["_apc", "_apcCrew", "_apcGroup"];

		private _infGroup = [_spawnPos, west, _fireteamCfg] call BIS_fnc_spawnGroup;
		{
			_x assignAsCargo _apc;
			_x moveInCargo _apc;
		} forEach (units _infGroup);

		private _unloadPos = [_targetPos, 25, 70, [15, 15, 0]] call PRR_fnc_getSafeSpawnPos;

		private _wpMove = _apcGroup addWaypoint [_unloadPos, 0];
		_wpMove setWaypointType "MOVE";
		_wpMove setWaypointSpeed "FULL";

		private _wpUnload = _apcGroup addWaypoint [_unloadPos, 0];
		_wpUnload setWaypointType "TR UNLOAD";

		private _wpInf = _infGroup addWaypoint [_targetPos, 0];
		_wpInf setWaypointType "MOVE";
		_wpInf setWaypointBehaviour "AWARE";

		private _wpGuard = _infGroup addWaypoint [_targetPos, 15];
		_wpGuard setWaypointType "GUARD";
	};

	["[Reinforce] Mechanized reinforcements inbound (2 Badger APC + fireteams)", _requester] call PRR_fnc_notifyPlayer;
};

PRR_fnc_spawnArmourReinforcements = {
	params ["_requester"];

	private _targetPos = getPosATL _requester;
	private _baseSpawn = [_targetPos, 1100, 1800, [500, 1300, 0]] call PRR_fnc_getSafeSpawnPos;

	private _vehicles = [
		"B_MBT_01_cannon_F",
		"B_MBT_01_cannon_F",
		"B_MBT_01_cannon_F",
		"B_APC_Tracked_01_AA_F"
	];

	{
		private _vehClass = _x;
		private _spawnPos = [
			(_baseSpawn select 0) + ((_forEachIndex % 2) * 22),
			(_baseSpawn select 1) + (floor (_forEachIndex / 2) * 24),
			0
		];

		private _vehData = [_spawnPos, random 360, _vehClass] call PRR_fnc_spawnVehicleCrewed;
		_vehData params ["_veh", "_crew", "_group"];

		private _wpAssault = _group addWaypoint [_targetPos, 0];
		_wpAssault setWaypointType "SAD";
		_wpAssault setWaypointBehaviour "COMBAT";
		_wpAssault setWaypointSpeed "FULL";
	} forEach _vehicles;

	["[Reinforce] Armour reinforcements inbound (tank platoon + AA)", _requester] call PRR_fnc_notifyPlayer;
};

PRR_fnc_handleRequest = {
	params ["_requester", "_requestType"];
	if (!isServer) exitWith {};
	if (isNull _requester || {!alive _requester}) exitWith {};

	if !([_requester] call PRR_fnc_checkAndSetCooldown) exitWith {};
	if !([_requester, _requestType] call PRR_fnc_checkAndConsumeResources) exitWith {};

	switch (_requestType) do {
		case "ground": { [_requester] call PRR_fnc_spawnGroundReinforcements; };
		case "mech": { [_requester] call PRR_fnc_spawnMechanizedReinforcements; };
		case "armour": { [_requester] call PRR_fnc_spawnArmourReinforcements; };
		default {
			["[Reinforce] Unknown reinforcement request", _requester] call PRR_fnc_notifyPlayer;
		};
	};
};

PRR_fnc_registerPlayerActions = {
	params ["_unit"];
	if (isNull _unit) exitWith {};

	private _existingIds = _unit getVariable ["PRR_actionIDs", []];
	{
		_unit removeAction _x;
	} forEach _existingIds;

	private _ids = [];

	_ids pushBack (_unit addAction [
		"Call Ground Reinforcements",
		{
			params ["_target", "_caller"];
			[_caller, "ground"] remoteExecCall ["PRR_fnc_handleRequest", 2];
		},
		nil,
		1.5,
		true,
		true,
		"",
		"alive _target",
		5,
		false
	]);

	_ids pushBack (_unit addAction [
		"Call Mechanized Reinforcements",
		{
			params ["_target", "_caller"];
			[_caller, "mech"] remoteExecCall ["PRR_fnc_handleRequest", 2];
		},
		nil,
		1.5,
		true,
		true,
		"",
		"alive _target",
		5,
		false
	]);

	_ids pushBack (_unit addAction [
		"Call Armour Reinforcements",
		{
			params ["_target", "_caller"];
			[_caller, "armour"] remoteExecCall ["PRR_fnc_handleRequest", 2];
		},
		nil,
		1.5,
		true,
		true,
		"",
		"alive _target",
		5,
		false
	]);

	_unit setVariable ["PRR_actionIDs", _ids];
};

if (hasInterface) then {
	[] spawn {
		waitUntil {!isNull player};
		sleep 1;
		[player] call PRR_fnc_registerPlayerActions;

		player addEventHandler ["Respawn", {
			params ["_newUnit", "_oldUnit"];
			[_newUnit] call PRR_fnc_registerPlayerActions;
		}];
	};
};
