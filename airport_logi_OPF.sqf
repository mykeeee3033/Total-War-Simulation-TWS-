 _crew1 = [];
_airframe1 = [];
_cargo = [];

if (isServer) then {
	while {true} do {
		// Find random OPFOR airport to deliver to
		private _targetAirport = [];
		private _airportName = "Unknown";
		
		// Check if ALiVE and OPCOM are available
		if (!(isNil "ALiVE_sectorGrid") && !(isNil "OPCOM_instances") && count OPCOM_instances > 0) then {
			private _opforAirports = [];
			
			// Find OPFOR OPCOM airports
			{
				private _opcom = _x;
				private _opcomSide = [_opcom, "side", ""] call ALIVE_fnc_hashGet;
				
				if (_opcomSide == "EAST") then {
					private _objectives = [_opcom, "objectives", []] call ALIVE_fnc_hashGet;
					
					{
						private _objective = _x;
						private _objCenter = [_objective, "center", [0,0,0]] call ALIVE_fnc_hashGet;
						
						// Check if this objective has airport/airbase characteristics
						private _nearAirports = _objCenter nearEntities [["Land_Runway_PAPI", "Land_Runway_PAPI_2", "Land_Airport_Tower_F", "Land_Hangar_F", "Land_TentHangar_V1_F"], 1500];
						if (count _nearAirports > 0) then {
							_opforAirports pushBack _objCenter;
						};
					} forEach _objectives;
				};
			} forEach OPCOM_instances;
			
			// Select random airport or fallback to marker
			if (count _opforAirports > 0) then {
				_targetAirport = selectRandom _opforAirports;
				_airportName = format ["OPFOR Airport %1", mapGridPosition _targetAirport];
			} else {
				_targetAirport = getMarkerPos "military_2"; // Fallback
				_airportName = "Military Base 2";
			};
		} else {
			_targetAirport = getMarkerPos "military_2"; // Fallback if ALiVE not available
			_airportName = "Military Base 2";
		};
		
		systemChat format ["[OPFOR Logistics] Targeting airport: %1", _airportName];
		
		_crew1 = createGroup east; 
		_airframe1 = [getMarkerPos "airspawn_opf", 140, "O_T_VTOL_02_vehicle_dynamicLoadout_F", _crew1] call BIS_fnc_spawnVehicle;

		// Waypoint 1: Plane reaches destination and drops resources at the airport
		_wp1 = _crew1 addWaypoint [_targetAirport, 0];
		_wp1 setWaypointType "GETOUT";
		_wp1 setWaypointSpeed "FULL";

		_wp1 setWaypointStatements ["true", format ["
			private _landingPos = %1;
			private _crateAmount = 8;
			
			// Spawn CSAT supply boxes around the airport
			for '_i' from 1 to _crateAmount do {
				private _offset = [random 100 - 50, random 100 - 50, 0];
				private _cratePos = _landingPos vectorAdd _offset;
				private _crate = 'O_supplyCrate_F' createVehicle _cratePos;
				
				// Fill with supplies
				clearItemCargoGlobal _crate;
				clearWeaponCargoGlobal _crate;
				clearMagazineCargoGlobal _crate;
				
				_crate addItemCargoGlobal ['FirstAidKit', 10];
				_crate addWeaponCargoGlobal ['arifle_Katiba_F', 5];
				_crate addMagazineCargoGlobal ['30Rnd_65x39_caseless_green', 30];
				_crate addItemCargoGlobal ['HandGrenade', 8];
			};
			
			// Add manpower points to OPFOR using resource system
			if (!(isNil 'RES_fnc_modifyResource')) then {
				['OPFOR', 3, 200] call RES_fnc_modifyResource;
				systemChat '[OPFOR Logistics] +200 Manpower added to OPFOR resources';
			} else {
				systemChat '[OPFOR Logistics] Resource system not available - manpower not added';
			};
			
			hint format ['C130 resupply complete at %2: 8 CSAT crates + 200 manpower', '%1', '%3'];
		", str _targetAirport, _targetAirport, _airportName]];

		// Waypoint 2: Plane prepares for takeoff back to spawn
		_wp2 = _crew1 addWaypoint [_targetAirport, 0];
		_wp2 setWaypointType "GETIN NEAREST";
		_wp2 setWaypointSpeed "FULL";
		_wp2 setWaypointStatements ["true", "hint 'C130 departing: Next logistics flight in 30 minutes.';"];

		// Waypoint 3: Plane returns to spawn, then deletes itself
		_wp3 = _crew1 addWaypoint [(getMarkerPos "airspawn_opf"), 0];
		_wp3 setWaypointType "MOVE";
		_wp3 setWaypointSpeed "FULL";
		_wp3 setWaypointStatements ["true", "{deleteVehicle _x} forEach crew (vehicle this) + [vehicle this];"];

		// Delay before the next plane spawns (30 minutes)
		sleep 1800;
	};
};