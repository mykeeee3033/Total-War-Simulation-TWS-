if (isServer) then {
    // Define arrays of marker names and corresponding vehicle classes
	
	//I'm aware these are opfor markers, but I got lazy
    private _samMarkers = ["opf_rh_1", "opf_rh_2", "opf_rh_3"];
    private _radarMarkers = ["opf_rad_1", "opf_rad_2", "opf_rad_3"];
    private _aaMarkers = ["opf_pt_1", "opf_pt_2", "opf_pt_3"];
    
    private _vehicleClasses = [
        ["B_SAM_System_03_F", _samMarkers],
        ["B_Radar_System_01_F", _radarMarkers],
        ["B_AAA_System_01_F", _aaMarkers]
    ];
    
    // Iterate over each type of defense system
    {
        private _vehicleClass = _x select 0;        // Vehicle type
        private _markers = _x select 1;             // Markers array

        // For each marker in the current type array, create the vehicle and assign a gunner
        {
            // Get the position for the current marker
            private _pos = getMarkerPos _x;
            
            // Spawn the vehicle at the marker position
            private _vehicle = _vehicleClass createVehicle _pos;
            
            // Create a crew for the vehicle and place them inside
            private _crewGroup = createGroup west;
            private _gunner = _crewGroup createUnit ["B_crew_F", _pos, [], 0, "FORM"];
            
            // Assign the gunner to the vehicle
            _gunner moveInGunner _vehicle;
            
        } forEach _markers;
        
    } forEach _vehicleClasses;
};
