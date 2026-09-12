/*
 * recon_intelligence_opf.sqf
 *
 * OPFOR ground recon + communications simulation:
 * - OPFOR spotters visually detect BLUFOR squads
 * - Creates one map marker per spotted squad
 * - Marker text includes classification, size, health status, composition
 * - Marker direction follows squad travel vector
 * - Markers expire 20 seconds after last visual contact
 */

if (!isServer) exitWith {
	diag_log "[RECON] recon_intelligence_opf.sqf runs on server only";
};

if (isNil "RECON_OPF_enabled") then { RECON_OPF_enabled = true; };
if (isNil "RECON_OPF_running") then { RECON_OPF_running = false; };
if (isNil "RECON_OPF_scanInterval") then { RECON_OPF_scanInterval = 5; };
if (isNil "RECON_OPF_markerLifetime") then { RECON_OPF_markerLifetime = 20; };
if (isNil "RECON_OPF_spotRange") then { RECON_OPF_spotRange = 900; };
if (isNil "RECON_OPF_minKnowsAbout") then { RECON_OPF_minKnowsAbout = 1.5; };
if (isNil "RECON_OPF_markerPrefix") then { RECON_OPF_markerPrefix = "RECON_OPF_SPOT_"; };
if (isNil "RECON_OPF_markerCounter") then { RECON_OPF_markerCounter = 0; };
if (isNil "RECON_OPF_spottedTargets") then { RECON_OPF_spottedTargets = createHashMap; };
if (isNil "RECON_OPF_exportEnabled") then { RECON_OPF_exportEnabled = true; };
if (isNil "RECON_OPF_exportInterval") then { RECON_OPF_exportInterval = 10; };
if (isNil "RECON_OPF_lastExportTime") then { RECON_OPF_lastExportTime = -9999; };
if (isNil "RECON_OPF_allowedSpotterClasses") then {
	RECON_OPF_allowedSpotterClasses = [
		"O_recon_exp_F",
		"O_recon_JTAC_F",
		"O_recon_M_F",
		"O_recon_medic_F",
		"O_Pathfinder_F",
		"O_recon_F",
		"O_recon_LAT_F",
		"O_recon_TL_F",
		"O_T_Recon_Exp_F",
		"O_T_Recon_JTAC_F",
		"O_T_Recon_M_F",
		"O_T_Recon_Medic_F",
		"O_T_Recon_F",
		"O_T_Recon_LAT_F",
		"O_T_Recon_TL_F",
		"O_diver_F",
		"O_diver_exp_F",
		"O_diver_TL_F",
		"O_sniper_F",
		"O_ghillie_ard_F",
		"O_ghillie_lsh_F",
		"O_ghillie_sard_F",
		"O_spotter_F",
		"O_T_Diver_F",
		"O_T_Diver_Exp_F",
		"O_T_Diver_TL_F",
		"O_T_Sniper_F",
		"O_T_ghillie_tna_F",
		"O_T_Spotter_F",
		"O_V_Soldier_Medic_hex_F",
		"O_V_Soldier_Exp_hex_F",
		"O_V_Soldier_JTAC_hex_F",
		"O_V_Soldier_M_hex_F",
		"O_V_Soldier_hex_F",
		"O_V_Soldier_LAT_hex_F",
		"O_V_Soldier_TL_hex_F",
		"O_UAV_06_F",
		"O_UAV_06_medical_F",
		"O_UAV_01_F",
		"O_UGV_01_F",
		"O_UGV_01_rcws_F",
		"O_UAV_02_dynamicLoadout_F",
		"O_T_UAV_04_CAS_F",
		"O_T_UGV_01_ghex_F",
		"O_T_UGV_01_rcws_ghex_F",
		"O_Soldier_SL_F",
		"O_SoldierU_SL_F",
		"O_T_Soldier_SL_F",
		"O_soldier_UAV_F",
		"O_T_Soldier_UAV_F"
	];
};

// Optional export bridge: writes recon snapshot into INIDBI2 for external readers.
call compile preprocessFileLineNumbers "recon_export_inidbi2.sqf";

if (isNil "RECON_OPF_export_endMissionEH") then {
	RECON_OPF_export_endMissionEH = addMissionEventHandler ["Ended", {
		if (!isNil "RECON_OPF_fnc_exportClearOnScenarioEnd") then {
			[] call RECON_OPF_fnc_exportClearOnScenarioEnd;
		};
	}];
};

RECON_OPF_fnc_clearAllMarkers = {
	{
		if (_x find RECON_OPF_markerPrefix == 0) then {
			deleteMarker _x;
		};
	} forEach allMapMarkers;
};

RECON_OPF_fnc_getVectorDir = {
	params ["_target"];

	private _vel = velocity _target;
	private _vx = _vel select 0;
	private _vy = _vel select 1;
	private _speed2D = sqrt ((_vx * _vx) + (_vy * _vy));

	if (_speed2D < 1) exitWith {getDir _target};

	private _dir = _vy atan2 _vx;
	if (_dir < 0) then {_dir = _dir + 360; };
	_dir
};

RECON_OPF_fnc_isAllowedSpotter = {
	params ["_unit"];

	if (isNull _unit || {!alive _unit}) exitWith {false};
	if !(_unit isKindOf "Man" || {_unit isKindOf "LandVehicle"} || {_unit isKindOf "Air"}) exitWith {false};
	if !(side _unit == east || {side (group _unit) == east}) exitWith {false};

	(typeOf _unit) in RECON_OPF_allowedSpotterClasses
};

RECON_OPF_fnc_isBluforAsset = {
	params ["_target"];

	if (isNull _target || {!alive _target}) exitWith {false};

	if (_target isKindOf "Man") exitWith {
		(side _target == west || {side (group _target) == west})
	};

	if !(_target isKindOf "LandVehicle" || {_target isKindOf "Air"} || {_target isKindOf "Ship"} || {_target isKindOf "StaticWeapon"}) exitWith {false};

	private _crewAlive = (crew _target) select {alive _x};
	if (count _crewAlive == 0) exitWith {false};

	({side _x == west} count _crewAlive) > 0
};

RECON_OPF_fnc_getTargetGroup = {
	params ["_target"];

	if (_target isKindOf "Man") exitWith {group _target};

	private _crewAlive = (crew _target) select {alive _x && {side _x == west}};
	if (count _crewAlive == 0) exitWith {grpNull};

	group (_crewAlive select 0)
};

RECON_OPF_fnc_getGroupComposition = {
	params ["_group"];

	private _infantry = 0;
	private _static = 0;
	private _armour = 0;
	private _mech = 0;
	private _air = 0;
	private _naval = 0;
	private _anyInjured = false;

	private _aliveUnits = (units _group) select {alive _x};
	private _vehicles = [];

	{
		if ((damage _x) > 0.25) then { _anyInjured = true; };

		private _veh = vehicle _x;
		if (_veh == _x) then {
			_infantry = _infantry + 1;
		} else {
			_vehicles pushBackUnique _veh;
		};
	} forEach _aliveUnits;

	{
		if (_x isKindOf "StaticWeapon") then {
			_static = _static + 1;
		} else {
			if (_x isKindOf "Tank") then {
				_armour = _armour + 1;
			} else {
				if (_x isKindOf "Wheeled_APC_F" || {_x isKindOf "Tracked_APC_F"}) then {
					_mech = _mech + 1;
				} else {
					if (_x isKindOf "Air") then {
						_air = _air + 1;
					} else {
						if (_x isKindOf "Ship" || {_x isKindOf "Boat"}) then {
							_naval = _naval + 1;
						} else {
							_mech = _mech + 1;
						};
					};
				};
			};
		};
	} forEach _vehicles;

	private _status = if (_anyInjured) then {"injured"} else {"full health"};
	private _size = (count _aliveUnits) max 1;

	private _classification = "infantry";
	if (_armour > 0 && {_infantry > 0 || {_mech > 0}}) then {
		_classification = "combined arms";
	} else {
		if (_mech > 0 && {_infantry > 0}) then {
			_classification = "mech infantry";
		} else {
			if (_armour > 0 && {_mech > 0}) then {
				_classification = "armour-mech";
			} else {
				if (_air > 0 && {_infantry > 0 || {_armour > 0 || {_mech > 0}}}) then {
					_classification = "air assault";
				} else {
					if (_armour > 0) then {
						_classification = "armour";
					} else {
						if (_mech > 0) then {
							_classification = "mech";
						} else {
							if (_air > 0) then {
								_classification = "air";
							} else {
								if (_naval > 0) then {
									_classification = "naval";
								} else {
									if (_static > 0 && {_infantry > 0}) then {
										_classification = "static support";
									} else {
										if (_static > 0) then {
											_classification = "static";
										};
									};
								};
							};
						};
					};
				};
			};
		};
	};

	[
		_classification,
		_size,
		_status,
		_infantry,
		_static,
		_armour,
		_mech,
		_air,
		_naval
	]
};

RECON_OPF_fnc_hasVisualContact = {
	params ["_spotter", "_target"];

	if (isNull _spotter || {isNull _target}) exitWith {false};
	if (!alive _spotter || {!alive _target}) exitWith {false};
	if ((_spotter distance _target) > RECON_OPF_spotRange) exitWith {false};
	if ((_spotter knowsAbout _target) < RECON_OPF_minKnowsAbout) exitWith {false};

	private _from = eyePos _spotter;
	private _to = if (_target isKindOf "Man") then {eyePos _target} else {aimPos _target};
	private _hits = lineIntersectsSurfaces [_from, _to, _spotter, _target, true, 1, "GEOM", "NONE"];

	(count _hits) == 0
};

RECON_OPF_fnc_touchMarker = {
	params ["_group", "_seenTarget", "_now"];

	private _key = str _group;
	private _entry = RECON_OPF_spottedTargets getOrDefault [_key, []];
	private _markerName = "";

	if (count _entry > 0) then {
		_markerName = _entry select 1;
	} else {
		RECON_OPF_markerCounter = RECON_OPF_markerCounter + 1;
		_markerName = format ["%1%2", RECON_OPF_markerPrefix, RECON_OPF_markerCounter];
		createMarker [_markerName, getPosATL _seenTarget];
	};

	private _comp = [_group] call RECON_OPF_fnc_getGroupComposition;
	_comp params ["_classification", "_size", "_status", "_inf", "_sta", "_arm", "_mech", "_air", "_nav"];

	private _leader = leader _group;
	private _vectorSource = if (!isNull _leader) then {
		vehicle _leader
	} else {
		_seenTarget
	};
	private _dir = [_vectorSource] call RECON_OPF_fnc_getVectorDir;

	_markerName setMarkerType "mil_arrow2";
	_markerName setMarkerColor "ColorOrange";
	_markerName setMarkerSize [0.85, 0.85];
	_markerName setMarkerPos (getPosATL _seenTarget);
	_markerName setMarkerDir _dir;
	_markerName setMarkerText format ["BLUFOR %1 | size %2 | %3 | I:%4 S:%5 A:%6 M:%7 AIR:%8 N:%9",
		toUpper _classification,
		_size,
		_status,
		_inf,
		_sta,
		_arm,
		_mech,
		_air,
		_nav
	];

	RECON_OPF_spottedTargets set [_key, [_group, _markerName, _now]];
};

RECON_OPF_fnc_cleanupStaleMarkers = {
	params ["_now"];

	{
		private _key = _x;
		private _entry = RECON_OPF_spottedTargets get _key;

		if (!isNil "_entry" && {count _entry >= 3}) then {
			_entry params ["_group", "_markerName", "_lastSeen"];

			private _shouldDelete = false;
			if (isNull _group || {{alive _x} count (units _group) == 0}) then {
				_shouldDelete = true;
			} else {
				if ((_now - _lastSeen) > RECON_OPF_markerLifetime) then {
					_shouldDelete = true;
				};
			};

			if (_shouldDelete) then {
				deleteMarker _markerName;
				RECON_OPF_spottedTargets deleteAt _key;
			};
		};
	} forEach (keys RECON_OPF_spottedTargets);
};

RECON_OPF_fnc_scanAndUpdate = {
	private _now = time;
	private _seenGroups = createHashMap;

	private _spotters = allUnits select {
		[_x] call RECON_OPF_fnc_isAllowedSpotter &&
		{vehicle _x == _x}
	};

	// Also allow whitelisted OPFOR UAV/UGV vehicle entities to act as spotters.
	private _vehicleSpotters = vehicles select {
		[_x] call RECON_OPF_fnc_isAllowedSpotter
	};

	{
		if !(_x in _spotters) then {
			_spotters pushBack _x;
		};
	} forEach _vehicleSpotters;

	{
		private _spotter = _x;
		private _near = _spotter nearEntities [["Man", "LandVehicle", "Air", "Ship", "StaticWeapon"], RECON_OPF_spotRange];

		{
			private _target = _x;
			private _targetGroup = grpNull;
			private _groupKey = "";

			if (
				_target != _spotter &&
				{[_target] call RECON_OPF_fnc_isBluforAsset} &&
				{[_spotter, _target] call RECON_OPF_fnc_hasVisualContact}
			) then {
				_targetGroup = [_target] call RECON_OPF_fnc_getTargetGroup;
				if (!isNull _targetGroup && {side _targetGroup == west}) then {
					_groupKey = str _targetGroup;
					if !(_groupKey in (keys _seenGroups)) then {
						_seenGroups set [_groupKey, [_targetGroup, _target]];
					};
				};
			};
		} forEach _near;
	} forEach _spotters;

	{
		private _entry = _seenGroups get _x;
		if (!isNil "_entry" && {count _entry >= 2}) then {
			_entry params ["_grp", "_seenTarget"];
			[_grp, _seenTarget, _now] call RECON_OPF_fnc_touchMarker;
		};
	} forEach (keys _seenGroups);

	[_now] call RECON_OPF_fnc_cleanupStaleMarkers;
};

if (RECON_OPF_running) exitWith {
	diag_log "[RECON] OPFOR recon already running";
};

RECON_OPF_running = true;
publicVariable "RECON_OPF_running";

[] spawn {
	diag_log "[RECON] OPFOR recon intelligence started";
	systemChat "[RECON] OPFOR spotting intelligence online";

	while {RECON_OPF_enabled} do {
		[] call RECON_OPF_fnc_scanAndUpdate;

		if (RECON_OPF_exportEnabled && {!isNil "RECON_OPF_fnc_exportToIniDBI2"}) then {
			if ((time - RECON_OPF_lastExportTime) >= RECON_OPF_exportInterval) then {
				[] call RECON_OPF_fnc_exportToIniDBI2;
				RECON_OPF_lastExportTime = time;
			};
		};

		sleep RECON_OPF_scanInterval;
	};

	[] call RECON_OPF_fnc_clearAllMarkers;
	RECON_OPF_spottedTargets = createHashMap;
	if (!isNil "RECON_OPF_fnc_exportClearOnScenarioEnd") then {
		[] call RECON_OPF_fnc_exportClearOnScenarioEnd;
	};
	RECON_OPF_running = false;
	publicVariable "RECON_OPF_running";

	diag_log "[RECON] OPFOR recon intelligence stopped";
};

publicVariable "RECON_OPF_enabled";
publicVariable "RECON_OPF_scanInterval";
publicVariable "RECON_OPF_markerLifetime";
publicVariable "RECON_OPF_spotRange";
publicVariable "RECON_OPF_minKnowsAbout";
publicVariable "RECON_OPF_exportEnabled";
publicVariable "RECON_OPF_exportInterval";
publicVariable "RECON_OPF_allowedSpotterClasses";
publicVariable "RECON_OPF_spottedTargets";
publicVariable "RECON_OPF_fnc_isAllowedSpotter";
publicVariable "RECON_OPF_fnc_clearAllMarkers";
publicVariable "RECON_OPF_fnc_scanAndUpdate";
