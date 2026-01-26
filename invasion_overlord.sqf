/*
    Invasion Overlord - Master Control Script
    Author: GitHub Copilot
    Date: 2026-01-25
    
    Description: Master script that orchestrates the entire amphibious invasion operation.
    This script controls all phases of the invasion including land, sea, and air components.
*/

systemChat "=== INVASION OVERLORD INITIALIZING ===";

// Marker Setup - Ensure consistent marker usage across all invasion components
systemChat "[OVERLORD] Setting up invasion markers...";

// Define primary beach landing zone
INVASION_primaryBeach = "beach_0";
private _beachPos = getMarkerPos INVASION_primaryBeach;

// Create beach_0 marker if it doesn't exist (use player position as default)
if (_beachPos isEqualTo [0,0,0]) then {
    private _playerPos = getPos player;
    private _beachMarker = createMarker [INVASION_primaryBeach, _playerPos];
    _beachMarker setMarkerShape "ELLIPSE";
    _beachMarker setMarkerSize [400, 400];
    _beachMarker setMarkerColor "ColorRed";
    _beachMarker setMarkerBrush "Border";
    _beachMarker setMarkerText "INVASION BEACH";
    systemChat format ["[OVERLORD] Created %1 marker at player position: %2", INVASION_primaryBeach, _playerPos];
} else {
    systemChat format ["[OVERLORD] Using existing %1 marker at: %2", INVASION_primaryBeach, _beachPos];
};

// Set global marker variables for other scripts to use
INVASION_beachMarkers = [INVASION_primaryBeach];
systemChat "[OVERLORD] Marker setup complete - all invasion scripts will use consistent markers";

// Phase 1: Amphibious Landing Operations - 4 Waves
systemChat "[OVERLORD] Initiating amphibious landing operations - 4 waves incoming...";

// Wave 1: Immediate
systemChat "[OVERLORD] Wave 1/4 launching immediately...";
execVM "invasion_landing.sqf";

// Wave 2: 60 seconds
[] spawn {
    sleep 60;
    systemChat "[OVERLORD] Wave 2/4 launching NOW!";
    execVM "invasion_landing.sqf";
};

// Wave 3: 120 seconds  
[] spawn {
    sleep 120;
    systemChat "[OVERLORD] Wave 3/4 launching NOW!";
    execVM "invasion_landing.sqf";
};

// Wave 4: 180 seconds
[] spawn {
    sleep 180;
    systemChat "[OVERLORD] Wave 4/4 - Final wave launching NOW!";
    execVM "invasion_landing.sqf";
};

// Phase 2: Air Component
systemChat "[OVERLORD] Air support phase will begin in 25 seconds...";
[] spawn {
    sleep 25; // Wait 25 seconds after landing phase starts
    systemChat "[OVERLORD] Initiating air support phase NOW!";
    execVM "invasion_air.sqf";
};

// Phase 3: Additional phases can be added here
// systemChat "[OVERLORD] Initiating follow-up reinforcement phase...";
// execVM "invasion_reinforcements.sqf";

systemChat "[OVERLORD] All invasion phases initiated!";
systemChat "=== INVASION OVERLORD ACTIVE ===";
