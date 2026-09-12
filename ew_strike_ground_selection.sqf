/*
    EW strike ground selection

    Purpose:
    - Provide randomized ground assault tier data for EW strike
    - Support both OPFOR and BLUFOR attacker variants
    - Do not spawn anything here; only return selection/configuration data

    Usage:
    [] execVM "ew_strike_ground_selection.sqf";
    private _config = ["OPFOR"] call EW_STRIKE_fnc_getGroundAssaultConfig;
*/

if (isNil "EW_STRIKE_fnc_getGroundAssaultConfig") then {
    EW_STRIKE_fnc_getGroundAssaultConfig = {
        params [["_attackerFaction", "OPFOR"]];

        private _tier = selectRandom [1, 2, 3];
        private _tierDesc = "";
        private _side = east;
        private _vehicleClasses = [];
        private _infSquadCount = 1;
        private _infantryGroupConfig = configNull;

        switch (_attackerFaction) do {
            case "BLUFOR": {
                _side = west;
                _infantryGroupConfig = configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfSquad";

                switch (_tier) do {
                    case 1: {
                        _vehicleClasses = [
                            "B_MBT_01_cannon_F",
                            "B_MBT_01_cannon_F",
                            "B_MBT_01_cannon_F",
                            "B_APC_Tracked_01_rcws_F",
                            "B_APC_Wheeled_01_cannon_F",
                            "B_Truck_01_covered_F"
                        ];
                        _infSquadCount = 3;
                        _tierDesc = "Tier 1 (Hardest)";
                    };
                    case 2: {
                        _vehicleClasses = [
                            "B_MBT_01_cannon_F",
                            "B_APC_Tracked_01_rcws_F",
                            "B_APC_Wheeled_01_cannon_F",
                            "B_Truck_01_covered_F"
                        ];
                        _infSquadCount = 2;
                        _tierDesc = "Tier 2 (Medium)";
                    };
                    default {
                        _vehicleClasses = [
                            "B_APC_Wheeled_01_cannon_F",
                            "B_Truck_01_transport_F"
                        ];

                        if (random 1 < 0.20) then {
                            _vehicleClasses pushBack "B_MBT_01_cannon_F";
                        };

                        _infSquadCount = 1;
                        _tierDesc = "Tier 3 (Easiest)";
                    };
                };
            };
            default {
                _side = east;
                _infantryGroupConfig = configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad";

                switch (_tier) do {
                    case 1: {
                        _vehicleClasses = [
                            "O_MBT_02_cannon_F",
                            "O_MBT_02_cannon_F",
                            "O_MBT_02_cannon_F",
                            "O_APC_Tracked_02_cannon_F",
                            "O_APC_Wheeled_02_rcws_v2_F",
                            "O_Truck_03_covered_F"
                        ];
                        _infSquadCount = 3;
                        _tierDesc = "Tier 1 (Hardest)";
                    };
                    case 2: {
                        _vehicleClasses = [
                            "O_MBT_02_cannon_F",
                            "O_APC_Tracked_02_cannon_F",
                            "O_APC_Wheeled_02_rcws_v2_F",
                            "O_Truck_03_covered_F"
                        ];
                        _infSquadCount = 2;
                        _tierDesc = "Tier 2 (Medium)";
                    };
                    default {
                        _vehicleClasses = [
                            "O_APC_Wheeled_02_rcws_v2_F",
                            "O_Truck_03_transport_F"
                        ];

                        if (random 1 < 0.20) then {
                            _vehicleClasses pushBack "O_MBT_02_cannon_F";
                        };

                        _infSquadCount = 1;
                        _tierDesc = "Tier 3 (Easiest)";
                    };
                };
            };
        };

        [_tier, _tierDesc, _side, _vehicleClasses, _infSquadCount, _infantryGroupConfig]
    };
};