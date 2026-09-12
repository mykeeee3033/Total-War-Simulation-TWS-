/*
    AA/SAM engagement balance controller

    Uses AA/SAM classes from static_defenses.sqf exclusion list
    and limits when those assets can actively target players.
*/

if (!isServer) exitWith {};

private _debug = false;
private _activeInterval = 2;
private _idleInterval = 10;
private _defaultMaxRange = 4500;
private _assetRefreshInterval = 60;

private _rangeByClass = createHashMapFromArray [
    ["B_AAA_System_01_F", 4500],
    ["O_AAA_System_01_F", 4500],
    ["B_SAM_System_01_F", 6500],
    ["B_SAM_System_02_F", 6500],
    ["O_SAM_System_01_F", 6500],
    ["O_SAM_System_02_F", 6500],
    ["O_SAM_System_04_F", 7000]
];

waitUntil {
    sleep 2;
    !(isNil { missionNamespace getVariable "STATIC_excludedAASAMClasses" })
};

private _managedClasses = missionNamespace getVariable ["STATIC_excludedAASAMClasses", []];
if (_debug) then {
    diag_log format ["[AASAM-Balance] Managing classes from static_defenses exclusions: %1", _managedClasses];
};

private _managedAssets = [];
private _lastAssetRefresh = -_assetRefreshInterval;
private _cachedAllPlayers = [];
private _lastPlayerCacheTime = -30;

while {true} do {
    // Cache allPlayers to avoid repeated expensive calls
    if ((time - _lastPlayerCacheTime) >= 30) then {
        _cachedAllPlayers = allPlayers;
        _lastPlayerCacheTime = time;
    };
    
    private _airPlayers = _cachedAllPlayers select {
        alive _x && {vehicle _x isKindOf "Air"}
    };

    if ((time - _lastAssetRefresh) >= _assetRefreshInterval || {count _managedAssets == 0}) then {
        _managedAssets = vehicles select {
            alive _x && ((typeOf _x) in _managedClasses)
        };
        _lastAssetRefresh = time;
    } else {
        _managedAssets = _managedAssets select { !isNull _x && alive _x };
    };

    if ((count _airPlayers) == 0) then {
        {
            private _asset = _x;
            private _gunner = gunner _asset;
            if (isNull _gunner) then { _gunner = effectiveCommander _asset; };

            if (!isNull _gunner) then {
                if (isNil {_asset getVariable "AASAM_netMuted"}) then {
                    _asset setVehicleReportRemoteTargets false;
                    _asset setVehicleReceiveRemoteTargets false;
                    _asset setVehicleReportOwnPosition false;
                    _asset setVariable ["AASAM_netMuted", true, false];
                };
                _gunner disableAI "TARGET";
                _gunner disableAI "AUTOTARGET";
            };
        } forEach _managedAssets;

        sleep _idleInterval;
        continue;
    };

    {
        private _asset = _x;
        private _gunner = gunner _asset;

        if (isNull _gunner) then {
            _gunner = effectiveCommander _asset;
        };

        if (!isNull _gunner) then {
            if (isNil {_asset getVariable "AASAM_netMuted"}) then {
                _asset setVehicleReportRemoteTargets false;
                _asset setVehicleReceiveRemoteTargets false;
                _asset setVehicleReportOwnPosition false;
                _asset setVariable ["AASAM_netMuted", true, false];
            };

            private _maxRange = _rangeByClass getOrDefault [typeOf _asset, _defaultMaxRange];
            private _inRange = (_airPlayers findIf { (_asset distance2D (vehicle _x)) <= _maxRange }) > -1;

            if (_inRange) then {
                _gunner enableAI "TARGET";
                _gunner enableAI "AUTOTARGET";
            } else {
                _gunner disableAI "TARGET";
                _gunner disableAI "AUTOTARGET";
                {
                    _gunner forgetTarget (vehicle _x);
                } forEach _airPlayers;
            };
        };
    } forEach _managedAssets;

    sleep _activeInterval;
};
