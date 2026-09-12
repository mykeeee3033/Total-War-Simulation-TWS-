/*
 * Custom A3DJS Commands - External Registration
 * Hooks into existing A3DJS system without modifying the PBO
 * Usage: [] execVM "customA3DJSCommands.sqf"
 */

if (!isServer) exitWith {};

// Wait for A3DJS to initialize
waitUntil {!isNil "A3DJS_commandTypes"};

systemChat "[CustomA3DJS] A3DJS detected, adding custom commands...";

// Define your hello world function
CUSTOM_fnc_helloWorld = {
    params["_target", "_sender", "_RequestId", ["_action", "execute"]];
    
    // Debug output (like A3DJS style)
    diag_log format ["[CustomA3DJS] Hello World called: %1", _this];
    
    // Execute the hello world script
    [] execVM "helloWorld.sqf";
    
    // Send success response to Discord (using A3DJS response system)
    [_RequestId, format["✅ Hello World executed by %1!", _sender]] call A3DJS_fnc_respondCall;
    
    // Also show in game chat
    [format["[Discord] Hello World executed by %1!", _sender]] remoteExecCall ["systemChat", 0];
    
    true;
};

// Register your command with A3DJS system
["hello-world", CUSTOM_fnc_helloWorld] call A3DJS_fnc_addCommandType;

// Define squad spawn function  
CUSTOM_fnc_spawnSquad = {
    params["_playerName", "_sender", "_RequestId", ["_squadType", "nato_rifle"]];
    
    diag_log format ["[CustomA3DJS] Spawn Squad called: %1", _this];
    
    // Find the target player
    private _player = objNull;
    {
        if (name _x == _playerName) exitWith { _player = _x; };
    } forEach allPlayers;
    
    if (isNull _player) exitWith {
        [_RequestId, format["❌ Player '%1' not found!", _playerName]] call A3DJS_fnc_respondCall;
    };
    
    // Squad templates
    private _squadUnits = [];
    switch (_squadType) do {
        case "nato_rifle": { 
            _squadUnits = [
                "B_Soldier_SL_F", "B_Soldier_AR_F", "B_Soldier_GL_F", "B_soldier_M_F",
                "B_Soldier_LAT_F", "B_medic_F", "B_Soldier_F", "B_Soldier_F"
            ];
        };
        case "nato_heavy": {
            _squadUnits = [
                "B_Soldier_SL_F", "B_HeavyGunner_F", "B_soldier_AT_F", 
                "B_soldier_AA_F", "B_medic_F", "B_engineer_F"
            ];
        };
        default { _squadUnits = ["B_Soldier_SL_F", "B_Soldier_F", "B_Soldier_F"]; };
    };
    
    // Get spawn position near player
    private _playerPos = getPos _player;
    private _spawnPos = [_playerPos, 50, 100, 5, 0, 0.3, 0] call BIS_fnc_findSafePos;
    
    // Create group and spawn units
    private _group = createGroup west;
    private _spawnedUnits = [];
    
    {
        private _unit = _group createUnit [_x, _spawnPos, [], 8, "NONE"];
        if (_forEachIndex == 0) then { 
            _unit setRank "SERGEANT";
            _group selectLeader _unit;
        };
        _spawnedUnits pushBack _unit;
    } forEach _squadUnits;
    
    // Set group behavior  
    _group setBehaviour "AWARE";
    _group setCombatMode "YELLOW";
    private _wp = _group addWaypoint [_playerPos, 0];
    
    // Send success response
    private _squadName = "NATO Rifle Squad";
    if (_squadType == "nato_heavy") then { _squadName = "NATO Heavy Squad"; };
    
    [_RequestId, format["✅ %1 spawned near %2! (%3 units)", _squadName, _playerName, count _spawnedUnits]] call A3DJS_fnc_respondCall;
    
    // Notify all players
    [format["[Discord] %1 spawned %2 near %3!", _sender, _squadName, _playerName]] remoteExecCall ["systemChat", 0];
    
    // Hint the target player
    [_player, format["Squad backup incoming! %1 units deployed.", count _spawnedUnits]] remoteExecCall ["hint", _player];
    
    true;
};

// Register squad spawn command
["spawn-squad", CUSTOM_fnc_spawnSquad] call A3DJS_fnc_addCommandType;

// Define resource status function
CUSTOM_fnc_resourceStatus = {
    params["_target", "_sender", "_RequestId", ["_faction", "all"]];
    
    diag_log format ["[CustomA3DJS] Resource Status called: %1", _this];
    
    // Wait for resource system to be available
    if (isNil "RES_factionResources" || isNil "RES_fnc_getResources") exitWith {
        [_RequestId, "❌ Resource system not loaded yet!"] call A3DJS_fnc_respondCall;
    };
    
    // Get resource data
    private _bluResources = ["BLUFOR"] call RES_fnc_getResources;
    private _opfResources = ["OPFOR"] call RES_fnc_getResources;
    private _resourceNames = ["Fuel", "Supplies", "Fabrication", "Manpower", "Electricity"];
    
    // Build response message
    private _response = "📊 **FACTION RESOURCE STATUS**\n";
    
    // BLUFOR Resources
    _response = _response + "\n🔵 **BLUFOR RESOURCES**\n";
    {
        private _resourceName = _resourceNames select _forEachIndex;
        private _amount = _x;
        private _status = if (_amount < 100) then {"⚠️"} else {"✅"};
        _response = _response + format ["%1 %2: **%3**\n", _status, _resourceName, _amount];
    } forEach _bluResources;
    
    // OPFOR Resources  
    _response = _response + "\n🔴 **OPFOR RESOURCES**\n";
    {
        private _resourceName = _resourceNames select _forEachIndex;
        private _amount = _x;
        private _status = if (_amount < 100) then {"⚠️"} else {"✅"};
        _response = _response + format ["%1 %2: **%3**\n", _status, _resourceName, _amount];
    } forEach _opfResources;
    
    // Add totals and advantage
    private _bluTotal = 0;
    private _opfTotal = 0;
    {_bluTotal = _bluTotal + _x} forEach _bluResources;
    {_opfTotal = _opfTotal + _x} forEach _opfResources;
    
    _response = _response + format ["\n📈 **TOTALS**\n🔵 BLUFOR: **%1**\n🔴 OPFOR: **%2**\n", _bluTotal, _opfTotal];
    
    // Show advantage
    if (_bluTotal > _opfTotal) then {
        _response = _response + "\n🏆 **BLUFOR has resource advantage!**";
    } else {
        if (_opfTotal > _bluTotal) then {
            _response = _response + "\n🏆 **OPFOR has resource advantage!**";
        } else {
            _response = _response + "\n⚖️ **Equal resources - balanced fight!**";
        };
    };
    
    // Send response to Discord
    [_RequestId, _response] call A3DJS_fnc_respondCall;
    
    // Also show in game
    [format["[Discord] %1 checked resource status", _sender]] remoteExecCall ["systemChat", 0];
    
    true;
};

// Register resource status command
["resource-status", CUSTOM_fnc_resourceStatus] call A3DJS_fnc_addCommandType;

systemChat "[CustomA3DJS] Custom commands registered - hello-world, spawn-squad & resource-status available!";

// NOTE: Make sure to add to your mission's initServer.sqf:
// [] execVM "deathCounter.sqf";
// [] execVM "opforDeathCounter.sqf";

// You can add more commands here easily:
/*
CUSTOM_fnc_anotherCommand = {
    params["_target", "_sender", "_RequestId"];
    // Your code here
    [_RequestId, "Another command works!"] call A3DJS_fnc_respondCall;
};
["another-command", CUSTOM_fnc_anotherCommand] call A3DJS_fnc_addCommandType;
*/

diag_log "[CustomA3DJS] Custom command system initialized";