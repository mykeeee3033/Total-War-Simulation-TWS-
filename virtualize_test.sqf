/*
	Targeted manual virtualization for ALiVE.

	Flow:
	- Look at AI unit/vehicle
	- Press Ctrl + Shift + V
	- Server manually creates entity/vehicle profile(s) like naval_simple.sqf
	- Original units are deleted so the profile takes over
*/

if (!isServer && !hasInterface) exitWith {};

if (isServer) then {
	missionNamespace setVariable ["TWS_fnc_virtualizeGroupServer", {
		params ["_target", ["_requester", objNull]];

		if (isNull _target) exitWith {
			if (!isNull _requester) then {
				["[ALiVE] No target under cursor."] remoteExec ["systemChat", owner _requester];
			};
		};

		if (isNil "ALIVE_profileHandler") exitWith {
			if (!isNull _requester) then {
				["[ALiVE] Waiting for ALiVE profile system."] remoteExec ["systemChat", owner _requester];
			};
		};

		private _anchor = objNull;
		if (_target isKindOf "CAManBase") then {
			_anchor = _target;
		} else {
			if (count crew _target > 0) then {
				_anchor = effectiveCommander _target;
				if (isNull _anchor) then {
					_anchor = crew _target select 0;
				};
			};
		};

		if (isNull _anchor) exitWith {
			if (!isNull _requester) then {
				["[ALiVE] Target is not a valid AI unit/crewed vehicle."] remoteExec ["systemChat", owner _requester];
			};
		};

		private _group = group _anchor;
		if (isNull _group || {side _group == sideLogic}) exitWith {
			if (!isNull _requester) then {
				["[ALiVE] Group is invalid for virtualization."] remoteExec ["systemChat", owner _requester];
			};
		};

		private _leader = leader _group;
		if (isNull _leader || {isPlayer _leader}) exitWith {
			if (!isNull _requester) then {
				["[ALiVE] Group leader invalid or player-led."] remoteExec ["systemChat", owner _requester];
			};
		};

		private _units = units _group;
		if ({isPlayer _x} count _units > 0) exitWith {
			if (!isNull _requester) then {
				["[ALiVE] Refusing to virtualize a player group."] remoteExec ["systemChat", owner _requester];
			};
		};

		if ((_leader getVariable ["profileID", ""]) != "" || (_leader getVariable ["agentID", ""]) != "") exitWith {
			if (!isNull _requester) then {
				["[ALiVE] Group is already profile-managed."] remoteExec ["systemChat", owner _requester];
			};
		};

		private _groupSide = str (side _group);
		private _sourceFaction = faction _leader;
		private _effectiveFaction = _sourceFaction;
		private _factionWasRemapped = false;
		private _matchingFactionOpcoms = [];
		private _matchingSideOpcoms = [];

		if (!isNil "OPCOM_INSTANCES") then {
			{
				private _opcom = _x;
				private _opcomSide = [_opcom, "side", ""] call ALIVE_fnc_hashGet;
				private _opcomFactions = [_opcom, "factions", []] call ALIVE_fnc_hashGet;

				if (_opcomSide == _groupSide) then {
					_matchingSideOpcoms pushBack _opcom;

					if (_sourceFaction in _opcomFactions) then {
						_matchingFactionOpcoms pushBack _opcom;
					};
				};
			} forEach OPCOM_INSTANCES;

			if (count _matchingFactionOpcoms == 0 && {count _matchingSideOpcoms > 0}) then {
				private _fallbackFactions = [_matchingSideOpcoms select 0, "factions", []] call ALIVE_fnc_hashGet;
				if (count _fallbackFactions > 0) then {
					_effectiveFaction = _fallbackFactions select 0;
					_factionWasRemapped = true;
				};
			};
		};

		private _position = getPosATL _leader;
		private _entityID = [ALIVE_profileHandler, "getNextInsertEntityID"] call ALIVE_fnc_profileHandler;

		private _unitClasses = [];
		private _positions = [];
		private _ranks = [];
		private _damages = [];

		{
			_unitClasses pushBack (typeOf _x);
			_positions pushBack (getPosATL _x);
			_ranks pushBack (rank _x);
			_damages pushBack (damage _x);
		} forEach _units;

		private _profileEntity = [nil, "create"] call ALIVE_fnc_profileEntity;
		[_profileEntity, "init"] call ALIVE_fnc_profileEntity;
		[_profileEntity, "profileID", _entityID] call ALIVE_fnc_profileEntity;
		[_profileEntity, "unitClasses", _unitClasses] call ALIVE_fnc_profileEntity;
		[_profileEntity, "position", _position] call ALIVE_fnc_profileEntity;
		[_profileEntity, "despawnPosition", _position] call ALIVE_fnc_profileEntity;
		[_profileEntity, "positions", _positions] call ALIVE_fnc_profileEntity;
		[_profileEntity, "damages", _damages] call ALIVE_fnc_profileEntity;
		[_profileEntity, "ranks", _ranks] call ALIVE_fnc_profileEntity;
		[_profileEntity, "side", _groupSide] call ALIVE_fnc_profileEntity;
		[_profileEntity, "faction", _effectiveFaction] call ALIVE_fnc_profileEntity;
		[_profileEntity, "isPlayer", false] call ALIVE_fnc_profileEntity;
		[_profileEntity, "objectType", "infantry"] call ALIVE_fnc_profileEntity;
		[_profileEntity, "aiBehaviour", "SAFE"] call ALIVE_fnc_profileEntity;

		private _waypoints = waypoints _group;
		if (currentWaypoint _group < count _waypoints) then {
			for "_i" from (currentWaypoint _group) to (count _waypoints - 1) do {
				private _profileWaypoint = [(_waypoints select _i)] call ALIVE_fnc_waypointToProfileWaypoint;
				[_profileEntity, "addWaypoint", _profileWaypoint] call ALIVE_fnc_profileEntity;
			};
		};

		[ALIVE_profileHandler, "registerProfile", _profileEntity] call ALIVE_fnc_profileHandler;

		private _groupVehicles = [];
		{
			private _veh = vehicle _x;
			if !(_veh isEqualTo _x) then {
				_groupVehicles pushBackUnique _veh;
			};
		} forEach _units;

		private _vehicleCount = 0;
		{
			private _vehicle = _x;
			if ((_vehicle getVariable ["profileID", ""]) == "") then {
				private _vehicleID = [ALIVE_profileHandler, "getNextInsertVehicleID"] call ALIVE_fnc_profileHandler;

				private _profileVehicle = [nil, "create"] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "init"] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "profileID", _vehicleID] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "vehicleClass", typeOf _vehicle] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "position", getPosATL _vehicle] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "despawnPosition", getPosATL _vehicle] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "direction", getDir _vehicle] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "damage", _vehicle call ALIVE_fnc_vehicleGetDamage] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "fuel", fuel _vehicle] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "ammo", _vehicle call ALIVE_fnc_vehicleGetAmmo] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "engineOn", isEngineOn _vehicle] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "canFire", canFire _vehicle] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "canMove", canMove _vehicle] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "needReload", needReload _vehicle] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "side", _groupSide] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "faction", _effectiveFaction] call ALIVE_fnc_profileVehicle;
				[_profileVehicle, "objectType", (typeOf _vehicle) call ALIVE_fnc_vehicleGetKindOf] call ALIVE_fnc_profileVehicle;

				[ALIVE_profileHandler, "registerProfile", _profileVehicle] call ALIVE_fnc_profileHandler;

				private _assignments = [_vehicle, _group] call ALIVE_fnc_vehicleAssignmentToProfileVehicleAssignment;
				private _vehicleAssignments = [_vehicleID, _entityID, _assignments];

				[_profileEntity, "addVehicleAssignment", _vehicleAssignments] call ALIVE_fnc_profileEntity;
				[_profileVehicle, "addVehicleAssignment", _vehicleAssignments] call ALIVE_fnc_profileVehicle;

				_vehicle setVariable ["profileID", _vehicleID];
				_vehicleCount = _vehicleCount + 1;
			};
		} forEach _groupVehicles;

		{
			deleteVehicle _x;
		} forEach _units;

		{
			deleteVehicle _x;
		} forEach _groupVehicles;

		_group call ALiVE_fnc_DeleteGroupRemote;

		private _opcomsToRefresh = [];
		if (count _matchingFactionOpcoms > 0) then {
			_opcomsToRefresh = _matchingFactionOpcoms;
		} else {
			_opcomsToRefresh = _matchingSideOpcoms;
		};

		{
			[_x, "scantroops"] call ALiVE_fnc_OPCOM;
		} forEach _opcomsToRefresh;

		if (!isNull _requester) then {
			[format ["[ALiVE] Virtualized group %1 (%2 units, %3 vehicles).", _entityID, count _units, _vehicleCount]] remoteExec ["systemChat", owner _requester];

			if (_factionWasRemapped) then {
				[format ["[ALiVE] Faction remapped for OPCOM visibility: %1 -> %2", _sourceFaction, _effectiveFaction]] remoteExec ["systemChat", owner _requester];
			};

			if (count _opcomsToRefresh > 0) then {
				[format ["[ALiVE] OPCOM refreshed (%1 handler(s)); group should appear in commander tablet now.", count _opcomsToRefresh]] remoteExec ["systemChat", owner _requester];
			} else {
				["[ALiVE] No matching OPCOM found for this side/faction."] remoteExec ["systemChat", owner _requester];
			};
		};
	}];

	publicVariable "TWS_fnc_virtualizeGroupServer";
};

if (hasInterface) then {
	waitUntil {sleep 0.2; !isNull player};

	missionNamespace setVariable ["TWS_fnc_requestVirtualizeCursor", {
		if (isNil "ALIVE_profileHandler") exitWith {
			systemChat "[ALiVE] Profile handler not initialized yet.";
		};

		private _target = cursorObject;
		if (isNull _target) exitWith {
			systemChat "[ALiVE] No target under cursor.";
		};

		[_target, player] remoteExec ["TWS_fnc_virtualizeGroupServer", 2];
	}];

	private _cbaKeybindFnName = format ["%1%2", "CBA", "_fnc_addKeybind"];
	private _cbaAddKeybind = missionNamespace getVariable [_cbaKeybindFnName, objNull];

	if (_cbaAddKeybind isEqualType {}) then {
		[
			"TWS",
			"TWS_VirtualizeCursorGroup",
			"Virtualize looked-at AI group into ALiVE",
			{ [] call (missionNamespace getVariable "TWS_fnc_requestVirtualizeCursor"); },
			{},
			[0x2F, [true, true, false]]
		] call _cbaAddKeybind;

		systemChat "[ALiVE] Virtualize keybind registered (Ctrl+Shift+V).";
	} else {
		waitUntil {!isNull findDisplay 46};

		if (isNil "TWS_virtualizeFallbackEH") then {
			TWS_virtualizeFallbackEH = (findDisplay 46) displayAddEventHandler ["KeyDown", {
				params ["_display", "_key", "_shift", "_ctrl", "_alt"];

				if (_key == 0x2F && _ctrl && _shift && !_alt) then {
					[] call (missionNamespace getVariable "TWS_fnc_requestVirtualizeCursor");
					true
				} else {
					false
				};
			}];

			systemChat "[ALiVE] Fallback keybind active (Ctrl+Shift+V).";
		};
	};
};
