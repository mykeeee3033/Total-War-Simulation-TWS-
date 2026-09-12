import configparser
import ast
import json
import os
import time
import tkinter as tk
from tkinter import filedialog, messagebox, ttk


APP_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(APP_DIR, "config.json")
DEFAULT_CONFIG = {
    "inidbi_file": "D:/Arma 3/@inidbi2/db/TWS_BattleIntel.ini",
    "battle_inidbi_file": "D:/Arma 3/@inidbi2/db/TWS_BattleIntel.ini",
    "logistics_inidbi_file": "D:/Arma 3/@inidbi2/db/TWS_LogisticsIntel.ini",
    "commander_inidbi_file": "D:/Arma 3/@inidbi2/db/TWS_CommanderIntel.ini",
    "clock_inidbi_file": "D:/Arma 3/@inidbi2/db/TWS_GameClock.ini",
    "refresh_seconds": 1.0,
    "window_title": "TWS Recon Live Viewer",
}

BATTLE_INI_FALLBACKS = [
    "D:/Arma 3/@inidbi2/db/TWS_BattleIntel.ini",
    "X:/Steam/steamapps/common/Arma 3/!Workshop/@INIDBI2 - Official extension/db/TWS_BattleIntel.ini",
    "X:/Steam/steamapps/common/Arma 3/@inidbi2/db/TWS_BattleIntel.ini",
]

LOGISTICS_INI_FALLBACKS = [
    "D:/Arma 3/@inidbi2/db/TWS_LogisticsIntel.ini",
    "X:/Steam/steamapps/common/Arma 3/!Workshop/@INIDBI2 - Official extension/db/TWS_LogisticsIntel.ini",
    "X:/Steam/steamapps/common/Arma 3/@inidbi2/db/TWS_LogisticsIntel.ini",
]

COMMANDER_INI_FALLBACKS = [
    "D:/Arma 3/@inidbi2/db/TWS_CommanderIntel.ini",
    "X:/Steam/steamapps/common/Arma 3/!Workshop/@INIDBI2 - Official extension/db/TWS_CommanderIntel.ini",
    "X:/Steam/steamapps/common/Arma 3/@inidbi2/db/TWS_CommanderIntel.ini",
]

CLOCK_INI_FALLBACKS = [
    "D:/Arma 3/@inidbi2/db/TWS_GameClock.ini",
    "X:/Steam/steamapps/common/Arma 3/!Workshop/@INIDBI2 - Official extension/db/TWS_GameClock.ini",
    "X:/Steam/steamapps/common/Arma 3/@inidbi2/db/TWS_GameClock.ini",
]

COMMANDER_COLUMNS = [
    ("LOGISTICS", "Logistics"),
    ("SUPPORT", "Support"),
    ("MOBILIZATION", "Mobilization"),
    ("MOVEMENTS", "Movements"),
    ("OFFENSIVE", "Offensive"),
    ("DEFENSIVE", "Defensive"),
    ("STRATEGIC", "Strategic"),
    ("RECOVERY", "Recovery"),
    ("RESERVES", "Reserves"),
    ("NO_ACTION", "No Action"),
]

FIELDS = [
    "SquadSizeAlive",
    "SquadSizeTotal",
    "SquadCasualties",
    "SquadType",
    "SquadHealthStatus",
    "SquadWoundedAlive",
    "SquadAvgHealthPct",
    "SquadStrengthPct",
    "SquadStrengthLabel",
    "InfantryCount",
    "StaticCount",
    "ArmourCount",
    "MechCount",
    "AirCount",
    "NavalCount",
    "LastSeen",
]

MAX_ACTIVITY_LOG_ROWS = 250


def normalize_value(value):
    if value is None:
        return ""
    value = str(value).strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1]
    return value


def _unwrap_outer_quotes(value):
    text = str(value).strip()
    # INIDBI may emit values like ""[1,2,3]""; unwrap repeatedly.
    while len(text) >= 2 and text[0] == '"' and text[-1] == '"':
        text = text[1:-1].strip()
    return text


def parse_sqf_array_string(value):
    text = _unwrap_outer_quotes(normalize_value(value))

    # Try literal parsing up to 2 passes in case first pass returns a quoted string.
    candidate = text
    for _ in range(2):
        try:
            parsed = ast.literal_eval(candidate)
        except Exception:
            break

        if isinstance(parsed, list):
            return parsed
        if isinstance(parsed, str):
            candidate = _unwrap_outer_quotes(parsed)
            continue
        break

    try:
        parsed = ast.literal_eval(text)
        if isinstance(parsed, list):
            return parsed
    except Exception:
        pass

    # Fallback for simple comma-separated bracket content.
    if text.startswith("[") and text.endswith("]"):
        inner = text[1:-1].strip()
        if inner == "":
            return []
        return [x.strip().strip('"') for x in inner.split(",")]

    return []


def infer_type_from_marker_text(marker_text):
    text = normalize_value(marker_text).lower()
    if text.startswith("blufor ") and " |" in text:
        token = text[len("blufor "): text.find(" |")].strip()
        if token:
            return token

    # Fallback for any older or malformed marker formats.
    if "combined arms" in text:
        return "combined arms"
    if "air assault" in text:
        return "air assault"
    if "mech infantry" in text:
        return "mech infantry"
    if "armour-mech" in text:
        return "armour-mech"
    if "static support" in text:
        return "static support"
    if "armour" in text:
        return "armour"
    if "mech" in text:
        return "mech"
    if "naval" in text:
        return "naval"
    if "static" in text:
        return "static"
    if "infantry" in text:
        return "infantry"
    return "unknown"


def type_danger_weight(squad_type):
    normalized = normalize_value(squad_type).lower()
    weights = {
        "combined arms": 900,
        "air assault": 850,
        "armour-mech": 800,
        "armour": 750,
        "air": 700,
        "mech infantry": 650,
        "mech": 600,
        "naval": 550,
        "static support": 450,
        "static": 400,
        "infantry": 300,
        "unknown": 100,
    }
    return weights.get(normalized, 100)


def infer_type_from_composition(row):
    try:
        infantry = int(float(normalize_value(row.get("InfantryCount", 0)) or 0))
        static = int(float(normalize_value(row.get("StaticCount", 0)) or 0))
        armour = int(float(normalize_value(row.get("ArmourCount", 0)) or 0))
        mech = int(float(normalize_value(row.get("MechCount", 0)) or 0))
        air = int(float(normalize_value(row.get("AirCount", 0)) or 0))
        naval = int(float(normalize_value(row.get("NavalCount", 0)) or 0))
    except ValueError:
        return "unknown"

    if armour > 0 and (infantry > 0 or mech > 0):
        return "combined arms"
    if mech > 0 and infantry > 0:
        return "mech infantry"
    if armour > 0 and mech > 0:
        return "armour-mech"
    if air > 0 and (infantry > 0 or armour > 0 or mech > 0):
        return "air assault"
    if armour > 0:
        return "armour"
    if mech > 0:
        return "mech"
    if air > 0:
        return "air"
    if naval > 0:
        return "naval"
    if static > 0 and infantry > 0:
        return "static support"
    if static > 0:
        return "static"
    if infantry > 0:
        return "infantry"
    return "unknown"


def danger_sort_key(row):
    comp_type = infer_type_from_composition(row)
    marker_type = infer_type_from_marker_text(row.get("MarkerText", ""))
    squad_type = comp_type if comp_type != "unknown" else marker_type if marker_type != "unknown" else row.get("SquadType", "unknown")

    try:
        alive = int(float(normalize_value(row.get("SquadSizeAlive", 0)) or 0))
    except ValueError:
        alive = 0

    try:
        total = int(float(normalize_value(row.get("SquadSizeTotal", 0)) or 0))
    except ValueError:
        total = alive

    try:
        casualties = int(float(normalize_value(row.get("SquadCasualties", 0)) or 0))
    except ValueError:
        casualties = max(total - alive, 0)

    try:
        strength_pct = int(float(normalize_value(row.get("SquadStrengthPct", 0)) or 0))
    except ValueError:
        strength_pct = 0

    try:
        avg_health_pct = int(float(normalize_value(row.get("SquadAvgHealthPct", 0)) or 0))
    except ValueError:
        avg_health_pct = 0

    return (
        type_danger_weight(squad_type),
        total,
        alive,
        casualties,
        strength_pct,
        avg_health_pct,
    )


def load_config():
    if not os.path.exists(CONFIG_PATH):
        save_config(DEFAULT_CONFIG)
        return dict(DEFAULT_CONFIG)

    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            loaded = json.load(f)
    except Exception:
        loaded = {}

    config = dict(DEFAULT_CONFIG)
    config.update(loaded if isinstance(loaded, dict) else {})

    # Backward compatibility with older single-file config.
    legacy_path = config.get("inidbi_file", "")
    if not config.get("battle_inidbi_file"):
        config["battle_inidbi_file"] = legacy_path or DEFAULT_CONFIG["battle_inidbi_file"]
    if not config.get("logistics_inidbi_file"):
        config["logistics_inidbi_file"] = DEFAULT_CONFIG["logistics_inidbi_file"]
    if not config.get("commander_inidbi_file"):
        config["commander_inidbi_file"] = DEFAULT_CONFIG["commander_inidbi_file"]

    return config


def save_config(config):
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)


def parse_target_stats(section_items):
    grouped = {}
    field_map = {field.lower(): field for field in FIELDS}

    for key, raw_value in section_items:
        value = normalize_value(raw_value)
        key_l = key.lower()

        matched_field = None
        matched_prefix = None
        for lower_field, canonical_field in field_map.items():
            suffix = "_" + lower_field
            if key_l.endswith(suffix):
                matched_field = canonical_field
                matched_prefix = key[: -len(suffix)]
                break

        if matched_field is None or not matched_prefix:
            continue

        if matched_prefix not in grouped:
            grouped[matched_prefix] = {}

        grouped[matched_prefix][matched_field] = value

    return grouped


def get_section_name_case_insensitive(parser, wanted_name):
    wanted = wanted_name.lower()
    for sec in parser.sections():
        if sec.lower() == wanted:
            return sec
    return None


def parse_targets_fallback(section_items):
    rows = {}

    for key, raw_value in section_items:
        value = normalize_value(raw_value)

        # Targets values are exported as an SQF-like array string that is
        # compatible with Python list literals, so literal_eval is reliable here.
        rec = parse_sqf_array_string(value)

        if not isinstance(rec, list) or len(rec) < 11:
            continue

        group_name = str(rec[0]) if rec[0] is not None else str(key)
        alive_size = str(rec[6]) if rec[6] is not None else "0"
        squad_type = str(rec[7]) if rec[7] is not None else "unknown"
        marker_text = str(rec[4]) if rec[4] is not None else ""
        if normalize_value(squad_type).lower() in ["", "unknown"]:
            squad_type = infer_type_from_marker_text(marker_text)
        health_status = str(rec[8]) if rec[8] is not None else "unknown"
        comp = rec[9] if isinstance(rec[9], list) and len(rec[9]) >= 6 else [0, 0, 0, 0, 0, 0]
        last_seen = str(rec[5]) if rec[5] is not None else "n/a"

        rows[group_name] = {
            "SquadSizeAlive": alive_size,
            "SquadType": squad_type,
            "MarkerText": marker_text,
            "SquadHealthStatus": health_status,
            "InfantryCount": str(comp[0]),
            "StaticCount": str(comp[1]),
            "ArmourCount": str(comp[2]),
            "MechCount": str(comp[3]),
            "AirCount": str(comp[4]),
            "NavalCount": str(comp[5]),
            "LastSeen": last_seen,
        }

    return rows


def merge_rows(primary_rows, fallback_rows):
    merged = {k: dict(v) for k, v in primary_rows.items()}

    for group_name, fallback_data in fallback_rows.items():
        if group_name not in merged:
            merged[group_name] = dict(fallback_data)
            continue

        target = merged[group_name]
        for field, value in fallback_data.items():
            cur = normalize_value(target.get(field, ""))
            if cur in ["", "unknown", "n/a", "0"]:
                target[field] = value

        inferred_type = infer_type_from_composition(target)
        if inferred_type != "unknown":
            target["SquadType"] = inferred_type

    return merged


def parse_active_group_keys(meta_active_group_keys):
    keys = parse_sqf_array_string(meta_active_group_keys)
    return [str(x) for x in keys if str(x).strip()]


def infer_support_tier(text):
    normalized = normalize_value(text).upper()
    if "HEAVY" in normalized:
        return "HEAVY"
    if "MEDIUM" in normalized:
        return "MEDIUM"
    if "LIGHT" in normalized:
        return "LIGHT"
    return ""


def parse_hub_supply_rows(section_items):
    rows = []
    for key, raw_value in section_items:
        rec = parse_sqf_array_string(raw_value)
        if not isinstance(rec, list) or len(rec) < 8:
            continue

        hub_grid = str(rec[0])
        total = int(float(rec[1])) if str(rec[1]).strip() not in ["", "None"] else 0
        pct = int(float(rec[2])) if str(rec[2]).strip() not in ["", "None"] else 0
        raw_pct = int(float(rec[3])) if str(rec[3]).strip() not in ["", "None"] else 0
        status = normalize_value(rec[4]).upper() if rec[4] is not None else "RED"
        control = normalize_value(rec[5]).upper() if rec[5] is not None else "NONE"
        has_net = bool(rec[6]) if rec[6] is not None else False

        # Status color should reflect raw fill level, not threshold-normalized pct.
        if raw_pct >= 70:
            status = "GREEN"
        elif raw_pct >= 50:
            status = "YELLOW"
        else:
            status = "RED"

        rows.append({
            "hub_id": str(key),
            "hub_grid": hub_grid,
            "total": total,
            "pct": pct,
            "raw_pct": raw_pct,
            "status": status,
            "control": control,
            "has_net": has_net,
        })

    rows.sort(key=lambda r: (r["pct"], r["hub_grid"]))
    return rows


def parse_resource_rows(section_items):
    rows = []
    for key, raw_value in section_items:
        rec = parse_sqf_array_string(raw_value)
        if not isinstance(rec, list) or len(rec) < 5:
            continue

        fuel = int(float(rec[0])) if str(rec[0]).strip() not in ["", "None"] else 0
        supplies = int(float(rec[1])) if str(rec[1]).strip() not in ["", "None"] else 0
        fabrication = int(float(rec[2])) if str(rec[2]).strip() not in ["", "None"] else 0
        manpower = int(float(rec[3])) if str(rec[3]).strip() not in ["", "None"] else 0
        electricity = int(float(rec[4])) if str(rec[4]).strip() not in ["", "None"] else 0
        last_update = float(rec[5]) if len(rec) > 5 and str(rec[5]).strip() not in ["", "None"] else -1

        rows.append({
            "faction": str(key),
            "fuel": fuel,
            "supplies": supplies,
            "fabrication": fabrication,
            "manpower": manpower,
            "electricity": electricity,
            "last_update": last_update,
        })

    rows.sort(key=lambda r: r["faction"])
    return rows


def parse_resource_delta_vector(raw_value):
    rec = parse_sqf_array_string(raw_value)
    if not isinstance(rec, list):
        rec = []

    while len(rec) < 5:
        rec.append(0)

    return {
        "fuel": int(float(rec[0])) if str(rec[0]).strip() not in ["", "None"] else 0,
        "supplies": int(float(rec[1])) if str(rec[1]).strip() not in ["", "None"] else 0,
        "fabrication": int(float(rec[2])) if str(rec[2]).strip() not in ["", "None"] else 0,
        "manpower": int(float(rec[3])) if str(rec[3]).strip() not in ["", "None"] else 0,
        "electricity": int(float(rec[4])) if str(rec[4]).strip() not in ["", "None"] else 0,
    }


def parse_resource_event_rows(section_items):
    rows = []
    for key, raw_value in section_items:
        rec = parse_sqf_array_string(raw_value)
        if not isinstance(rec, list) or len(rec) < 8:
            continue

        event_type = normalize_value(rec[0]).upper() if rec[0] is not None else "UNKNOWN"
        faction = normalize_value(rec[1]).upper() if rec[1] is not None else "NONE"
        resource = normalize_value(rec[2]).upper() if rec[2] is not None else "UNKNOWN"
        delta = int(float(rec[3])) if str(rec[3]).strip() not in ["", "None"] else 0
        object_type = normalize_value(rec[4]) if rec[4] is not None else "unknown_object"
        grid = normalize_value(rec[5]) if rec[5] is not None else "n/a"
        marker = normalize_value(rec[6]) if rec[6] is not None else "n/a"
        event_time = float(rec[7]) if str(rec[7]).strip() not in ["", "None"] else -1.0

        rows.append({
            "event_id": str(key),
            "event_type": event_type,
            "faction": faction,
            "resource": resource,
            "delta": delta,
            "object_type": object_type,
            "grid": grid,
            "marker": marker,
            "event_time": event_time,
        })

    rows.sort(key=lambda r: (r["event_time"], r["event_id"]))
    return rows


def resolve_existing_path(primary_path, fallback_paths):
    primary = (primary_path or "").strip()
    if primary and os.path.exists(primary):
        return primary
    for path in fallback_paths:
        if os.path.exists(path):
            return path
    return primary


class ReconViewerApp:
    def __init__(self, root):
        self.root = root
        self.config = load_config()
        self.file_mtime = None
        self.last_refresh_epoch = None
        self.commander_cycle_index = 0
        self.commander_loop_interval = 0.0
        self.commander_last_cycle_game_time = None
        self.current_game_time = None
        self.commander_logistics_event_game_time = None
        self.commander_logistics_state = "NONE"
        self.commander_support_event_game_time = None
        self.commander_support_cooldown_seconds = 20.0
        self.commander_support_state = "NONE"
        self.commander_support_tier = ""
        self.commander_actions = {key: "NONE" for key, _ in COMMANDER_COLUMNS}
        self.hub_supply_rows = []
        self.resource_rows = []
        self.resource_last_update = "n/a"
        self.resource_panel_prev_state = None
        self.resource_deltas = {}
        self.resource_cycle_object_delta = {
            "OPFOR": {"fuel": 0, "supplies": 0, "fabrication": 0, "manpower": 0, "electricity": 0},
            "BLUFOR": {"fuel": 0, "supplies": 0, "fabrication": 0, "manpower": 0, "electricity": 0},
        }
        self.resource_cycle_resource_delta = {
            "OPFOR": {"fuel": 0, "supplies": 0, "fabrication": 0, "manpower": 0, "electricity": 0},
            "BLUFOR": {"fuel": 0, "supplies": 0, "fabrication": 0, "manpower": 0, "electricity": 0},
        }
        self.resource_events = []
        self.prev_resource_event_ids = set()
        self.resource_opfor_total = 0
        self.resource_blufor_total = 0
        self.resource_opfor_total_delta = 0
        self.resource_blufor_total_delta = 0
        self.resource_advantage_text = "EVEN"
        self.resource_advantage_delta = 0
        self.activity_rows = []
        self._last_activity_signature = ""
        self.prev_recon_target_count = None
        self.prev_commander_actions = None
        self.prev_hub_state = None
        self.prev_resource_state = None

        self.root.title(self.config.get("window_title", "TWS Recon Live Viewer"))
        self.root.geometry("1200x650")

        self.path_var = tk.StringVar(value=self.config.get("battle_inidbi_file", self.config.get("inidbi_file", "")))
        self.logistics_path_var = tk.StringVar(value=self.config.get("logistics_inidbi_file", ""))
        self.commander_path_var = tk.StringVar(value=self.config.get("commander_inidbi_file", ""))
        self.refresh_var = tk.StringVar(value=str(self.config.get("refresh_seconds", 1.0)))
        self.status_var = tk.StringVar(value="Waiting for file...")
        self.meta_var = tk.StringVar(value="Meta: n/a")
        self.update_var = tk.StringVar(value="Last UI refresh: n/a")
        self.commander_var = tk.StringVar(value="Cycle: n/a")
        self.resource_meta_var = tk.StringVar(value="Resources: n/a")

        self._build_ui()
        self._schedule_refresh(immediate=True)

    def _refresh_current_game_time_from_clock_file(self):
        self.current_game_time = None
        clock_path = resolve_existing_path(
            self.config.get("clock_inidbi_file", ""),
            CLOCK_INI_FALLBACKS,
        )
        if not clock_path or not os.path.exists(clock_path):
            return

        parser = configparser.ConfigParser(interpolation=None)
        parser.optionxform = str

        try:
            with open(clock_path, "r", encoding="utf-8", errors="ignore") as f:
                parser.read_file(f)
        except Exception:
            return

        clock_section = get_section_name_case_insensitive(parser, "Clock")
        if clock_section is None:
            return

        game_time_raw = normalize_value(parser.get(clock_section, "GameTime", fallback=""))
        try:
            self.current_game_time = float(game_time_raw)
        except ValueError:
            pass

    def _load_ini_parser(self, ini_path):
        if not ini_path or not os.path.exists(ini_path):
            return None

        parser = configparser.ConfigParser(interpolation=None)
        parser.optionxform = str
        try:
            with open(ini_path, "r", encoding="utf-8", errors="ignore") as f:
                parser.read_file(f)
        except Exception:
            return None
        return parser

    def _build_ui(self):
        top = ttk.Frame(self.root, padding=10)
        top.pack(fill="x")

        ttk.Label(top, text="Battle INI:").grid(row=0, column=0, sticky="w")
        ttk.Entry(top, textvariable=self.path_var, width=95).grid(row=0, column=1, padx=6, sticky="we")
        ttk.Button(top, text="Browse", command=lambda: self.browse_file_for_var(self.path_var, "Select TWS_BattleIntel.ini")).grid(row=0, column=2, padx=4)

        ttk.Label(top, text="Logistics INI:").grid(row=1, column=0, sticky="w", pady=(6, 0))
        ttk.Entry(top, textvariable=self.logistics_path_var, width=95).grid(row=1, column=1, padx=6, sticky="we", pady=(6, 0))
        ttk.Button(top, text="Browse", command=lambda: self.browse_file_for_var(self.logistics_path_var, "Select TWS_LogisticsIntel.ini")).grid(row=1, column=2, padx=4, pady=(6, 0))

        ttk.Label(top, text="Commander INI:").grid(row=2, column=0, sticky="w", pady=(6, 0))
        ttk.Entry(top, textvariable=self.commander_path_var, width=95).grid(row=2, column=1, padx=6, sticky="we", pady=(6, 0))
        ttk.Button(top, text="Browse", command=lambda: self.browse_file_for_var(self.commander_path_var, "Select TWS_CommanderIntel.ini")).grid(row=2, column=2, padx=4, pady=(6, 0))

        ttk.Label(top, text="Refresh (s):").grid(row=3, column=0, sticky="w", pady=(8, 0))
        ttk.Entry(top, textvariable=self.refresh_var, width=12).grid(row=3, column=1, sticky="w", pady=(8, 0))
        ttk.Button(top, text="Save Config", command=self.save_current_config).grid(row=3, column=2, padx=4, pady=(8, 0))
        ttk.Button(top, text="Refresh Now", command=self.refresh_once).grid(row=3, column=3, padx=4, pady=(8, 0))
        ttk.Button(top, text="Clear INI Data", command=self.clear_ini_data).grid(row=3, column=4, padx=4, pady=(8, 0))

        top.columnconfigure(1, weight=1)

        status = ttk.Frame(self.root, padding=(10, 0, 10, 8))
        status.pack(fill="x")
        ttk.Label(status, textvariable=self.status_var).pack(anchor="w")
        ttk.Label(status, textvariable=self.meta_var).pack(anchor="w")
        ttk.Label(status, textvariable=self.resource_meta_var).pack(anchor="w")
        ttk.Label(status, textvariable=self.update_var).pack(anchor="w")

        cols = (
            "Group",
            "Alive",
            "Total",
            "Casualties",
            "Type",
            "Strength%",
            "Strength Label",
            "Avg Health%",
            "Last Seen",
        )

        table_row_frame = ttk.Frame(self.root, padding=(10, 0, 10, 10))
        table_row_frame.pack(fill="both", expand=True)
        table_row_frame.columnconfigure(0, weight=3)
        table_row_frame.columnconfigure(1, weight=2)
        table_row_frame.rowconfigure(0, weight=1)

        table_frame = ttk.LabelFrame(table_row_frame, text="Recon Intel Sightings", padding=(8, 8, 8, 8))
        table_frame.grid(row=0, column=0, sticky="nsew", padx=(0, 8))

        self.tree = ttk.Treeview(table_frame, columns=cols, show="headings")

        widths = {
            "Group": 170,
            "Alive": 55,
            "Total": 55,
            "Casualties": 75,
            "Type": 110,
            "Strength%": 75,
            "Strength Label": 120,
            "Avg Health%": 90,
            "Last Seen": 95,
        }

        for col in cols:
            self.tree.heading(col, text=col)
            self.tree.column(col, width=widths[col], anchor="center")

        yscroll = ttk.Scrollbar(table_frame, orient="vertical", command=self.tree.yview)
        xscroll = ttk.Scrollbar(table_frame, orient="horizontal", command=self.tree.xview)
        self.tree.configure(yscrollcommand=yscroll.set, xscrollcommand=xscroll.set)

        self.tree.grid(row=0, column=0, sticky="nsew")
        yscroll.grid(row=0, column=1, sticky="ns")
        xscroll.grid(row=1, column=0, sticky="ew")

        table_frame.rowconfigure(0, weight=1)
        table_frame.columnconfigure(0, weight=1)

        activity_frame = ttk.LabelFrame(table_row_frame, text="Activity Log", padding=(8, 8, 8, 8))
        activity_frame.grid(row=0, column=1, sticky="nsew")

        activity_cols = ("Time", "Category", "Message")
        self.activity_tree = ttk.Treeview(activity_frame, columns=activity_cols, show="headings")

        self.activity_tree.heading("Time", text="Time")
        self.activity_tree.heading("Category", text="Category")
        self.activity_tree.heading("Message", text="Message")
        self.activity_tree.column("Time", width=110, anchor="center")
        self.activity_tree.column("Category", width=95, anchor="center")
        self.activity_tree.column("Message", width=420, anchor="w")

        activity_yscroll = ttk.Scrollbar(activity_frame, orient="vertical", command=self.activity_tree.yview)
        activity_xscroll = ttk.Scrollbar(activity_frame, orient="horizontal", command=self.activity_tree.xview)
        self.activity_tree.configure(yscrollcommand=activity_yscroll.set, xscrollcommand=activity_xscroll.set)

        self.activity_tree.grid(row=0, column=0, sticky="nsew")
        activity_yscroll.grid(row=0, column=1, sticky="ns")
        activity_xscroll.grid(row=1, column=0, sticky="ew")
        activity_frame.rowconfigure(0, weight=1)
        activity_frame.columnconfigure(0, weight=1)

        ops_frame = ttk.Frame(self.root, padding=(10, 0, 10, 10))
        ops_frame.pack(fill="both", expand=True)
        ops_frame.columnconfigure(0, weight=2)
        ops_frame.columnconfigure(1, weight=2)
        ops_frame.columnconfigure(2, weight=2)
        ops_frame.rowconfigure(0, weight=1)

        commander_frame = ttk.LabelFrame(ops_frame, text="AI Commander", padding=(10, 8, 10, 10))
        commander_frame.grid(row=0, column=0, sticky="nsew", padx=(0, 8))

        commander_header = ttk.Frame(commander_frame)
        commander_header.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        ttk.Label(commander_header, text="Commander Cycle").pack(side="left")
        ttk.Label(commander_header, textvariable=self.commander_var).pack(side="left", padx=(12, 0))

        commander_cols = ("Category", "Action")
        self.commander_tree = ttk.Treeview(commander_frame, columns=commander_cols, show="headings", height=len(COMMANDER_COLUMNS))

        self.commander_tree.heading("Category", text="Category")
        self.commander_tree.heading("Action", text="Action")
        self.commander_tree.column("Category", width=120, anchor="center")
        self.commander_tree.column("Action", width=420, anchor="w")

        commander_xscroll = ttk.Scrollbar(commander_frame, orient="horizontal", command=self.commander_tree.xview)
        self.commander_tree.configure(xscrollcommand=commander_xscroll.set)

        self.commander_tree.grid(row=1, column=0, sticky="ew")
        commander_xscroll.grid(row=2, column=0, sticky="ew")
        commander_frame.columnconfigure(0, weight=1)

        hub_frame = ttk.LabelFrame(ops_frame, text="Hub Supplies", padding=(10, 8, 10, 10))
        hub_frame.grid(row=0, column=1, sticky="nsew", padx=(0, 8))
        hub_cols = ("Hub Grid", "Supply %", "Raw %", "Supplies", "Status", "Control")
        self.hub_tree = ttk.Treeview(hub_frame, columns=hub_cols, show="headings", height=len(COMMANDER_COLUMNS))

        for col in hub_cols:
            self.hub_tree.heading(col, text=col)

        self.hub_tree.column("Hub Grid", width=110, anchor="center")
        self.hub_tree.column("Supply %", width=70, anchor="center")
        self.hub_tree.column("Raw %", width=70, anchor="center")
        self.hub_tree.column("Supplies", width=80, anchor="center")
        self.hub_tree.column("Status", width=80, anchor="center")
        self.hub_tree.column("Control", width=80, anchor="center")

        self.hub_tree.tag_configure("GREEN", background="#d7f5df")
        self.hub_tree.tag_configure("YELLOW", background="#fff4c4")
        self.hub_tree.tag_configure("RED", background="#ffd4d4")

        hub_scroll = ttk.Scrollbar(hub_frame, orient="vertical", command=self.hub_tree.yview)
        self.hub_tree.configure(yscrollcommand=hub_scroll.set)
        self.hub_tree.grid(row=0, column=0, sticky="nsew")
        hub_scroll.grid(row=0, column=1, sticky="ns")
        hub_frame.rowconfigure(0, weight=1)
        hub_frame.columnconfigure(0, weight=1)

        resource_frame = ttk.LabelFrame(ops_frame, text="Resources", padding=(10, 8, 10, 10))
        resource_frame.grid(row=0, column=2, sticky="nsew")

        resource_cols = ("Item", "Current", "Gains/Losses")
        self.resource_tree = ttk.Treeview(resource_frame, columns=resource_cols, show="headings", height=len(COMMANDER_COLUMNS))

        self.resource_tree.heading("Item", text="Item")
        self.resource_tree.heading("Current", text="Current")
        self.resource_tree.heading("Gains/Losses", text="Gains/Losses")
        self.resource_tree.column("Item", width=120, anchor="w")
        self.resource_tree.column("Current", width=110, anchor="center")
        self.resource_tree.column("Gains/Losses", width=190, anchor="w")

        self.resource_tree.tag_configure("POS", foreground="#198754")
        self.resource_tree.tag_configure("NEG", foreground="#d12d2d")
        self.resource_tree.tag_configure("NEU", foreground="#666666")

        resource_xscroll = ttk.Scrollbar(resource_frame, orient="horizontal", command=self.resource_tree.xview)
        self.resource_tree.configure(xscrollcommand=resource_xscroll.set)
        self.resource_tree.grid(row=0, column=0, sticky="nsew")
        resource_xscroll.grid(row=1, column=0, sticky="ew")
        resource_frame.rowconfigure(0, weight=1)
        resource_frame.columnconfigure(0, weight=1)

    def browse_file_for_var(self, target_var, title):
        selected = filedialog.askopenfilename(
            title=title,
            filetypes=[("INI files", "*.ini"), ("All files", "*.*")],
        )
        if selected:
            target_var.set(selected)
            self.file_mtime = None
            self.refresh_once()

    def save_current_config(self):
        refresh_s = self._parse_refresh_seconds()
        self.config["battle_inidbi_file"] = self.path_var.get().strip()
        self.config["logistics_inidbi_file"] = self.logistics_path_var.get().strip()
        self.config["commander_inidbi_file"] = self.commander_path_var.get().strip()
        self.config["inidbi_file"] = self.path_var.get().strip()
        self.config["refresh_seconds"] = refresh_s
        save_config(self.config)
        self.status_var.set("Config saved")

    def _parse_refresh_seconds(self):
        try:
            value = float(self.refresh_var.get())
            if value <= 0:
                raise ValueError
            return value
        except ValueError:
            self.refresh_var.set(str(DEFAULT_CONFIG["refresh_seconds"]))
            return DEFAULT_CONFIG["refresh_seconds"]

    def _schedule_refresh(self, immediate=False):
        delay_ms = 50 if immediate else int(self._parse_refresh_seconds() * 1000)
        self.root.after(delay_ms, self._periodic_refresh)

    def _periodic_refresh(self):
        self.refresh_once()
        self._schedule_refresh(immediate=False)

    def clear_ini_data(self):
        battle_path = self.path_var.get().strip()
        logistics_path = self.logistics_path_var.get().strip()
        commander_path = self.commander_path_var.get().strip()

        if not battle_path and not logistics_path and not commander_path:
            self.status_var.set("No INI paths set")
            return

        confirm = messagebox.askyesno(
            "Clear INIDBI2 Data",
            "This will clear battle/logistics/commander data in configured INI files. Continue?",
        )
        if not confirm:
            return

        battle_content = "\n".join([
            "[Meta]",
            "LastExportTime=-1",
            "TargetCount=0",
            "ActiveGroupKeys=[]",
            "ExportCycle=-1",
            "ScenarioClosed=1",
            "",
            "[Targets]",
            "",
            "[TargetStats]",
            "",
        ])

        commander_content = "\n".join([
            "[CommanderMeta]",
            "CycleIndex=0",
            "LoopInterval=0",
            "SightingsCount=0",
            "LastCycleGameTime=-1",
            "LastCycleSystemTimeUTC=[]",
            "CycleAnchorSystemTimeUTC=[]",
            "CycleEndSystemTimeUTC=[]",
            "LastLogisticsEventGameTime=-1",
            "SupportState=NONE",
            "ScenarioClosed=1",
            "",
            "[CommanderActions]",
            "LOGISTICS=NONE",
            "SUPPORT=NONE",
            "MOBILIZATION=NONE",
            "MOVEMENTS=NONE",
            "OFFENSIVE=NONE",
            "DEFENSIVE=NONE",
            "STRATEGIC=NONE",
            "RECOVERY=NONE",
            "RESERVES=NONE",
            "NO_ACTION=NONE",
            "",
        ])

        logistics_content = "\n".join([
            "[HubSupplyMeta]",
            "LastScanGameTime=-1",
            "ScanInterval=180",
            "HubCount=0",
            "ActiveHubKeys=[]",
            "ScenarioClosed=1",
            "",
            "[HubSupplies]",
            "",
            "[ResourceMeta]",
            "LastExportTime=-1",
            "UpdateInterval=300",
            "FactionCount=0",
            "ActiveFactions=[]",
            "ExportCycle=0",
            "LastCycleObjectDelta_OPFOR=[0,0,0,0,0]",
            "LastCycleObjectDelta_BLUFOR=[0,0,0,0,0]",
            "LastCycleResourceDelta_OPFOR=[0,0,0,0,0]",
            "LastCycleResourceDelta_BLUFOR=[0,0,0,0,0]",
            "ActiveResourceObjectKeys=[]",
            "ActiveResourceEventKeys=[]",
            "ScenarioClosed=1",
            "",
            "[Resources]",
            "",
            "[ResourceObjects]",
            "",
            "[ResourceEvents]",
            "",
        ])

        try:
            if battle_path:
                with open(battle_path, "w", encoding="utf-8") as f:
                    f.write(battle_content)
            if commander_path:
                with open(commander_path, "w", encoding="utf-8") as f:
                    f.write(commander_content)
            if logistics_path:
                with open(logistics_path, "w", encoding="utf-8") as f:
                    f.write(logistics_content)
        except Exception as ex:
            self.status_var.set(f"Clear failed: {ex}")
            return

        self.file_mtime = None
        self.last_refresh_epoch = None
        self.activity_rows = []
        self._last_activity_signature = ""
        self.prev_recon_target_count = None
        self.prev_commander_actions = None
        self.prev_hub_state = None
        self.prev_resource_state = None
        self.resource_panel_prev_state = None
        self.resource_deltas = {}
        self.resource_cycle_object_delta = {
            "OPFOR": {"fuel": 0, "supplies": 0, "fabrication": 0, "manpower": 0, "electricity": 0},
            "BLUFOR": {"fuel": 0, "supplies": 0, "fabrication": 0, "manpower": 0, "electricity": 0},
        }
        self.resource_cycle_resource_delta = {
            "OPFOR": {"fuel": 0, "supplies": 0, "fabrication": 0, "manpower": 0, "electricity": 0},
            "BLUFOR": {"fuel": 0, "supplies": 0, "fabrication": 0, "manpower": 0, "electricity": 0},
        }
        self.resource_events = []
        self.prev_resource_event_ids = set()
        self.resource_last_update = "n/a"
        self.resource_opfor_total = 0
        self.resource_blufor_total = 0
        self.resource_opfor_total_delta = 0
        self.resource_blufor_total_delta = 0
        self.resource_advantage_text = "EVEN"
        self.resource_advantage_delta = 0
        self.status_var.set("INI data cleared")
        self.refresh_once()

    def refresh_once(self):
        battle_path = resolve_existing_path(self.path_var.get().strip(), BATTLE_INI_FALLBACKS)
        logistics_path = resolve_existing_path(self.logistics_path_var.get().strip(), LOGISTICS_INI_FALLBACKS)
        commander_path = resolve_existing_path(self.commander_path_var.get().strip(), COMMANDER_INI_FALLBACKS)

        if battle_path and battle_path != self.path_var.get().strip() and os.path.exists(battle_path):
            self.path_var.set(battle_path)
            self.config["battle_inidbi_file"] = battle_path
            self.config["inidbi_file"] = battle_path
            save_config(self.config)

        if logistics_path and logistics_path != self.logistics_path_var.get().strip() and os.path.exists(logistics_path):
            self.logistics_path_var.set(logistics_path)
            self.config["logistics_inidbi_file"] = logistics_path
            save_config(self.config)

        if commander_path and commander_path != self.commander_path_var.get().strip() and os.path.exists(commander_path):
            self.commander_path_var.set(commander_path)
            self.config["commander_inidbi_file"] = commander_path
            save_config(self.config)

        now = time.strftime("%Y-%m-%d %H:%M:%S")

        if not battle_path and not logistics_path and not commander_path:
            self.status_var.set("No INI paths set")
            self.update_var.set(f"Last UI refresh: {now}")
            return

        # Always poll dedicated game clock, even when main INI has no updates.
        self._refresh_current_game_time_from_clock_file()

        battle_parser = self._load_ini_parser(battle_path)
        logistics_parser = self._load_ini_parser(logistics_path)
        commander_parser = self._load_ini_parser(commander_path)

        if battle_parser is None and logistics_parser is None and commander_parser is None:
            self.status_var.set("INI files not found or unreadable")
            self.update_var.set(f"Last UI refresh: {now}")
            self._clear_table()
            return

        meta_time = "n/a"
        meta_count = "n/a"
        active_group_keys = []
        meta_section = get_section_name_case_insensitive(battle_parser, "Meta") if battle_parser is not None else None
        if meta_section is not None and battle_parser is not None:
            meta_time = normalize_value(battle_parser.get(meta_section, "LastExportTime", fallback="n/a"))
            meta_count = normalize_value(battle_parser.get(meta_section, "TargetCount", fallback="n/a"))
            active_group_keys = parse_active_group_keys(
                battle_parser.get(meta_section, "ActiveGroupKeys", fallback="[]")
            )

        rows = {}
        stats_section = get_section_name_case_insensitive(battle_parser, "TargetStats") if battle_parser is not None else None
        targets_section = get_section_name_case_insensitive(battle_parser, "Targets") if battle_parser is not None else None
        commander_meta_section = get_section_name_case_insensitive(commander_parser, "CommanderMeta") if commander_parser is not None else None
        commander_actions_section = get_section_name_case_insensitive(commander_parser, "CommanderActions") if commander_parser is not None else None
        hub_supply_meta_section = get_section_name_case_insensitive(logistics_parser, "HubSupplyMeta") if logistics_parser is not None else None
        hub_supplies_section = get_section_name_case_insensitive(logistics_parser, "HubSupplies") if logistics_parser is not None else None
        resource_meta_section = get_section_name_case_insensitive(logistics_parser, "ResourceMeta") if logistics_parser is not None else None
        resources_section = get_section_name_case_insensitive(logistics_parser, "Resources") if logistics_parser is not None else None
        resource_events_section = get_section_name_case_insensitive(logistics_parser, "ResourceEvents") if logistics_parser is not None else None

        if stats_section is not None and battle_parser is not None:
            rows = parse_target_stats(battle_parser.items(stats_section))

        fallback_rows = {}
        if targets_section is not None and battle_parser is not None:
            fallback_rows = parse_targets_fallback(battle_parser.items(targets_section))

        rows = merge_rows(rows, fallback_rows)

        if commander_meta_section is not None and commander_parser is not None:
            self.commander_cycle_index = int(float(normalize_value(commander_parser.get(commander_meta_section, "CycleIndex", fallback="0")) or 0))
            self.commander_loop_interval = float(normalize_value(commander_parser.get(commander_meta_section, "LoopInterval", fallback="0")) or 0)
            cycle_game_time_raw = normalize_value(commander_parser.get(commander_meta_section, "LastCycleGameTime", fallback="-1"))
            try:
                self.commander_last_cycle_game_time = float(cycle_game_time_raw)
            except ValueError:
                self.commander_last_cycle_game_time = None
            logistics_event_raw = normalize_value(commander_parser.get(commander_meta_section, "LastLogisticsEventGameTime", fallback="-1"))
            try:
                self.commander_logistics_event_game_time = float(logistics_event_raw)
            except ValueError:
                self.commander_logistics_event_game_time = None
            self.commander_logistics_state = normalize_value(
                commander_parser.get(commander_meta_section, "LogisticsState", fallback="NONE")
            ) or "NONE"
            support_event_raw = normalize_value(commander_parser.get(commander_meta_section, "LastSupportEventGameTime", fallback="-1"))
            try:
                self.commander_support_event_game_time = float(support_event_raw)
            except ValueError:
                self.commander_support_event_game_time = None
            self.commander_support_state = normalize_value(
                commander_parser.get(commander_meta_section, "SupportState", fallback="NONE")
            ) or "NONE"
            self.commander_support_tier = infer_support_tier(self.commander_support_state)
        else:
            self.commander_cycle_index = 0
            self.commander_loop_interval = 0.0
            self.commander_last_cycle_game_time = None
            self.commander_logistics_event_game_time = None
            self.commander_logistics_state = "NONE"
            self.commander_support_event_game_time = None
            self.commander_support_state = "NONE"
            self.commander_support_tier = ""

        self.commander_actions = {key: "NONE" for key, _ in COMMANDER_COLUMNS}
        if commander_actions_section is not None and commander_parser is not None:
            for key, _ in COMMANDER_COLUMNS:
                self.commander_actions[key] = normalize_value(commander_parser.get(commander_actions_section, key, fallback="NONE")) or "NONE"

        if not self.commander_support_tier:
            self.commander_support_tier = infer_support_tier(self.commander_actions.get("SUPPORT", ""))

        self.commander_logistics_state = self.commander_actions.get("LOGISTICS", "NONE")
        self.commander_actions["LOGISTICS"] = self._derive_logistics_display_state()
        self.commander_actions["SUPPORT"] = self._derive_support_display_state()

        active_hub_keys = []
        if hub_supply_meta_section is not None and logistics_parser is not None:
            active_hub_keys = parse_active_group_keys(
                logistics_parser.get(hub_supply_meta_section, "ActiveHubKeys", fallback="[]")
            )

        self.hub_supply_rows = []
        if hub_supplies_section is not None and logistics_parser is not None:
            self.hub_supply_rows = parse_hub_supply_rows(logistics_parser.items(hub_supplies_section))
            if active_hub_keys:
                active_set = {k.lower() for k in active_hub_keys}
                self.hub_supply_rows = [
                    r for r in self.hub_supply_rows
                    if str(r.get("hub_id", "")).lower() in active_set
                ]

        resource_export_time = "n/a"
        resource_interval = "n/a"
        resource_cycle = "n/a"
        active_factions = []
        active_resource_event_keys = []
        self.resource_cycle_object_delta = {
            "OPFOR": {"fuel": 0, "supplies": 0, "fabrication": 0, "manpower": 0, "electricity": 0},
            "BLUFOR": {"fuel": 0, "supplies": 0, "fabrication": 0, "manpower": 0, "electricity": 0},
        }
        self.resource_cycle_resource_delta = {
            "OPFOR": {"fuel": 0, "supplies": 0, "fabrication": 0, "manpower": 0, "electricity": 0},
            "BLUFOR": {"fuel": 0, "supplies": 0, "fabrication": 0, "manpower": 0, "electricity": 0},
        }
        if resource_meta_section is not None and logistics_parser is not None:
            resource_export_time = normalize_value(logistics_parser.get(resource_meta_section, "LastExportTime", fallback="n/a"))
            resource_interval = normalize_value(logistics_parser.get(resource_meta_section, "UpdateInterval", fallback="n/a"))
            resource_cycle = normalize_value(logistics_parser.get(resource_meta_section, "ExportCycle", fallback="n/a"))
            active_factions = parse_active_group_keys(
                logistics_parser.get(resource_meta_section, "ActiveFactions", fallback="[]")
            )
            active_resource_event_keys = parse_active_group_keys(
                logistics_parser.get(resource_meta_section, "ActiveResourceEventKeys", fallback="[]")
            )

            self.resource_cycle_object_delta["OPFOR"] = parse_resource_delta_vector(
                logistics_parser.get(resource_meta_section, "LastCycleObjectDelta_OPFOR", fallback="[0,0,0,0,0]")
            )
            self.resource_cycle_object_delta["BLUFOR"] = parse_resource_delta_vector(
                logistics_parser.get(resource_meta_section, "LastCycleObjectDelta_BLUFOR", fallback="[0,0,0,0,0]")
            )
            self.resource_cycle_resource_delta["OPFOR"] = parse_resource_delta_vector(
                logistics_parser.get(resource_meta_section, "LastCycleResourceDelta_OPFOR", fallback="[0,0,0,0,0]")
            )
            self.resource_cycle_resource_delta["BLUFOR"] = parse_resource_delta_vector(
                logistics_parser.get(resource_meta_section, "LastCycleResourceDelta_BLUFOR", fallback="[0,0,0,0,0]")
            )

        self.resource_rows = []
        if resources_section is not None and logistics_parser is not None:
            self.resource_rows = parse_resource_rows(logistics_parser.items(resources_section))
            if active_factions:
                active_set = {f.lower() for f in active_factions}
                self.resource_rows = [
                    r for r in self.resource_rows
                    if str(r.get("faction", "")).lower() in active_set
                ]

        self.resource_events = []
        if resource_events_section is not None and logistics_parser is not None:
            self.resource_events = parse_resource_event_rows(logistics_parser.items(resource_events_section))
            if active_resource_event_keys:
                active_event_set = {k.lower() for k in active_resource_event_keys}
                self.resource_events = [
                    r for r in self.resource_events
                    if str(r.get("event_id", "")).lower() in active_event_set
                ]

        self.resource_last_update = resource_export_time
        self._compute_resource_deltas()

        if active_group_keys:
            active_set = set(active_group_keys)
            rows = {k: v for k, v in rows.items() if k in active_set}

        self._populate_table(rows)
        self._populate_commander_table()
        self._populate_hub_supply_table()
        self._populate_resource_panel()
        self._update_activity_log(
            now,
            meta_count,
            self.commander_actions,
            self.hub_supply_rows,
            self.resource_rows,
            self.resource_events,
        )
        self._populate_activity_table()
        self.meta_var.set(f"Meta: LastExportTime={meta_time} | TargetCount={meta_count}")
        self.resource_meta_var.set(
            f"Resources: LastExportTime={resource_export_time} | UpdateInterval={resource_interval}s | ExportCycle={resource_cycle}"
        )
        self.status_var.set("Live data loaded (battle/logistics/commander)")
        self.update_var.set(f"Last UI refresh: {now}")
        self._update_commander_status()
        self.last_refresh_epoch = time.time()

    def _clear_table(self):
        for item in self.tree.get_children():
            self.tree.delete(item)

    def _populate_commander_table(self):
        for item in self.commander_tree.get_children():
            self.commander_tree.delete(item)

        for key, label in COMMANDER_COLUMNS:
            self.commander_tree.insert(
                "",
                "end",
                values=(label, self.commander_actions.get(key, "NONE")),
            )

    def _populate_hub_supply_table(self):
        for item in self.hub_tree.get_children():
            self.hub_tree.delete(item)

        for row in self.hub_supply_rows:
            status = row.get("status", "RED")
            self.hub_tree.insert(
                "",
                "end",
                values=(
                    row.get("hub_grid", "n/a"),
                    f"{row.get('pct', 0)}%",
                    f"{row.get('raw_pct', 0)}%",
                    row.get("total", 0),
                    status,
                    row.get("control", "NONE"),
                ),
                tags=(status,),
            )

    def _compute_resource_deltas(self):
        current_state = {
            str(row.get("faction", "")).upper(): {
                "fuel": int(row.get("fuel", 0)),
                "supplies": int(row.get("supplies", 0)),
                "fabrication": int(row.get("fabrication", 0)),
                "manpower": int(row.get("manpower", 0)),
                "electricity": int(row.get("electricity", 0)),
            }
            for row in self.resource_rows
        }

        if self.resource_panel_prev_state is None:
            self.resource_deltas = {
                faction: {k: 0 for k in vals.keys()}
                for faction, vals in current_state.items()
            }
        else:
            deltas = {}
            for faction, vals in current_state.items():
                prev_vals = self.resource_panel_prev_state.get(
                    faction,
                    {k: 0 for k in vals.keys()},
                )
                deltas[faction] = {
                    k: int(vals.get(k, 0)) - int(prev_vals.get(k, 0))
                    for k in vals.keys()
                }
            self.resource_deltas = deltas

        self.resource_panel_prev_state = current_state

    def _format_delta(self, delta):
        if delta > 0:
            return f"+{delta}"
        return str(delta)

    def _delta_tag(self, delta):
        if delta > 0:
            return "POS"
        if delta < 0:
            return "NEG"
        return "NEU"

    def _get_faction_resource_pack(self, faction_name):
        faction = faction_name.upper()
        current = {
            "fuel": 0,
            "supplies": 0,
            "fabrication": 0,
            "manpower": 0,
            "electricity": 0,
        }

        for row in self.resource_rows:
            if str(row.get("faction", "")).upper() == faction:
                current = {
                    "fuel": int(row.get("fuel", 0)),
                    "supplies": int(row.get("supplies", 0)),
                    "fabrication": int(row.get("fabrication", 0)),
                    "manpower": int(row.get("manpower", 0)),
                    "electricity": int(row.get("electricity", 0)),
                }
                break

        delta = self.resource_deltas.get(
            faction,
            {k: 0 for k in current.keys()},
        )
        return current, delta

    def _populate_resource_panel(self):
        opfor_cur, opfor_delta = self._get_faction_resource_pack("OPFOR")
        blufor_cur, blufor_delta = self._get_faction_resource_pack("BLUFOR")

        last_update_text = self.resource_last_update
        try:
            last_update_text = str(int(float(last_update_text)))
        except (ValueError, TypeError):
            last_update_text = "n/a"

        opfor_total = sum(opfor_cur.values())
        blufor_total = sum(blufor_cur.values())
        opfor_total_delta = sum(opfor_delta.values())
        blufor_total_delta = sum(blufor_delta.values())
        self.resource_opfor_total = opfor_total
        self.resource_blufor_total = blufor_total
        self.resource_opfor_total_delta = opfor_total_delta
        self.resource_blufor_total_delta = blufor_total_delta

        if opfor_total > blufor_total:
            self.resource_advantage_text = "OPFOR"
            self.resource_advantage_delta = opfor_total - blufor_total
        elif blufor_total > opfor_total:
            self.resource_advantage_text = "BLUFOR"
            self.resource_advantage_delta = blufor_total - opfor_total
        else:
            self.resource_advantage_text = "EVEN"
            self.resource_advantage_delta = 0

        for item in self.resource_tree.get_children():
            self.resource_tree.delete(item)

        self.resource_tree.insert(
            "",
            "end",
            values=("OPFOR", f"LAST UPDATE: {last_update_text}", ""),
            tags=("NEU",),
        )

        metric_rows = [
            ("FUEL", "fuel"),
            ("SUPPLIES", "supplies"),
            ("MANPOWER", "manpower"),
            ("ELECT", "electricity"),
            ("FABRICATION", "fabrication"),
        ]

        for label, key in metric_rows:
            delta = self.resource_cycle_resource_delta.get("OPFOR", {}).get(key, 0)
            object_delta = self.resource_cycle_object_delta.get("OPFOR", {}).get(key, 0)
            gains_text = self._format_delta(delta)
            if object_delta != 0:
                gains_text = f"{gains_text} | obj {self._format_delta(object_delta)}"
            self.resource_tree.insert(
                "",
                "end",
                values=(label, str(opfor_cur.get(key, 0)), gains_text),
                tags=(self._delta_tag(delta),),
            )

        totals_text = (
            f"OPFOR {opfor_total} ({self._format_delta(opfor_total_delta)}) | "
            f"BLUFOR {blufor_total} ({self._format_delta(blufor_total_delta)})"
        )
        self.resource_tree.insert(
            "",
            "end",
            values=("TOTALS", str(opfor_total), totals_text),
            tags=("NEU",),
        )

        advantage_msg = "EVEN"
        advantage_tag = "NEU"
        if self.resource_advantage_text == "OPFOR":
            advantage_msg = f"OPFOR (+{self.resource_advantage_delta})"
            advantage_tag = "POS"
        elif self.resource_advantage_text == "BLUFOR":
            advantage_msg = f"BLUFOR (+{self.resource_advantage_delta})"
            advantage_tag = "NEG"

        self.resource_tree.insert(
            "",
            "end",
            values=("ADVANTAGE", self.resource_advantage_text, advantage_msg),
            tags=(advantage_tag,),
        )

    def _add_activity(self, when_text, category, message):
        signature = f"{category}|{message}"
        if signature == self._last_activity_signature:
            return

        self._last_activity_signature = signature
        self.activity_rows.append((when_text, category, message))
        if len(self.activity_rows) > MAX_ACTIVITY_LOG_ROWS:
            self.activity_rows = self.activity_rows[-MAX_ACTIVITY_LOG_ROWS:]

    def _update_activity_log(self, now_text, recon_count_raw, commander_actions, hub_rows, resource_rows, resource_events):
        # Normalize recon count.
        try:
            recon_count = int(float(normalize_value(recon_count_raw) or 0))
        except ValueError:
            recon_count = 0

        if self.prev_recon_target_count is None:
            self.prev_recon_target_count = recon_count
            self._add_activity(now_text, "RECON", f"Baseline loaded: {recon_count} active sightings")
        elif recon_count != self.prev_recon_target_count:
            delta = recon_count - self.prev_recon_target_count
            change = f"+{delta}" if delta > 0 else str(delta)
            self._add_activity(now_text, "RECON", f"Sightings changed {change} (now {recon_count})")
            self.prev_recon_target_count = recon_count

        # Commander action transitions.
        hub_grid_hint = "n/a"
        if hub_rows:
            sorted_hubs = sorted(hub_rows, key=lambda r: int(r.get("pct", 0)))
            hub_grid_hint = str(sorted_hubs[0].get("hub_grid", "n/a"))

        if self.prev_commander_actions is None:
            self.prev_commander_actions = dict(commander_actions)
            self._add_activity(now_text, "COMMAND", "Commander actions baseline loaded")
        else:
            for key, val in commander_actions.items():
                prev_val = self.prev_commander_actions.get(key, "NONE")
                if normalize_value(val) != normalize_value(prev_val):
                    if key in ["LOGISTICS", "SUPPORT"] and hub_grid_hint != "n/a":
                        self._add_activity(now_text, "COMMAND", f"{key}: {prev_val} -> {val} [GRID {hub_grid_hint}]")
                    else:
                        self._add_activity(now_text, "COMMAND", f"{key}: {prev_val} -> {val}")
            self.prev_commander_actions = dict(commander_actions)

        # Hub state transitions by hub ID.
        current_hub_state = {
            str(r.get("hub_id", "")): (
                int(r.get("pct", 0)),
                normalize_value(r.get("status", "RED")),
                normalize_value(r.get("control", "NONE")),
            )
            for r in hub_rows
        }

        if self.prev_hub_state is None:
            self.prev_hub_state = dict(current_hub_state)
            self._add_activity(now_text, "HUB", f"Hub baseline loaded ({len(current_hub_state)} hubs)")
        else:
            hub_grid_by_id = {
                str(r.get("hub_id", "")): str(r.get("hub_grid", "n/a"))
                for r in hub_rows
            }
            for hub_id, cur in current_hub_state.items():
                prev = self.prev_hub_state.get(hub_id)
                grid = hub_grid_by_id.get(hub_id, "n/a")
                if prev is None:
                    self._add_activity(now_text, "HUB", f"{hub_id} [GRID {grid}] added ({cur[0]}%, {cur[1]})")
                    continue
                if cur != prev:
                    self._add_activity(
                        now_text,
                        "HUB",
                        f"{hub_id} [GRID {grid}] {prev[0]}%/{prev[1]} -> {cur[0]}%/{cur[1]}",
                    )
            for hub_id in self.prev_hub_state.keys():
                if hub_id not in current_hub_state:
                    self._add_activity(now_text, "HUB", f"{hub_id} removed")
            self.prev_hub_state = dict(current_hub_state)

        # Resource transitions by faction.
        current_res_state = {
            str(r.get("faction", "")): (
                int(r.get("fuel", 0)),
                int(r.get("supplies", 0)),
                int(r.get("fabrication", 0)),
                int(r.get("manpower", 0)),
                int(r.get("electricity", 0)),
            )
            for r in resource_rows
        }

        if self.prev_resource_state is None:
            self.prev_resource_state = dict(current_res_state)
            self._add_activity(now_text, "RES", "Resource baseline loaded")
        else:
            for faction, cur in current_res_state.items():
                prev = self.prev_resource_state.get(faction)
                if prev is None:
                    self._add_activity(now_text, "RES", f"{faction} resource row added")
                    continue
                if cur != prev:
                    self._add_activity(
                        now_text,
                        "RES",
                        f"{faction} F:{prev[0]}->{cur[0]} S:{prev[1]}->{cur[1]} Fab:{prev[2]}->{cur[2]} M:{prev[3]}->{cur[3]} E:{prev[4]}->{cur[4]}",
                    )
            self.prev_resource_state = dict(current_res_state)

        current_event_ids = {str(r.get("event_id", "")) for r in resource_events if str(r.get("event_id", ""))}
        if not self.prev_resource_event_ids:
            self.prev_resource_event_ids = set(current_event_ids)
            if current_event_ids:
                self._add_activity(now_text, "RES", f"Resource event baseline loaded ({len(current_event_ids)} events)")
        else:
            for event in resource_events:
                event_id = str(event.get("event_id", ""))
                if not event_id or event_id in self.prev_resource_event_ids:
                    continue

                delta = int(event.get("delta", 0))
                verb = "gained" if delta > 0 else "lost" if delta < 0 else "changed"
                object_type = str(event.get("object_type", "unknown_object"))
                grid = str(event.get("grid", "n/a"))
                marker = str(event.get("marker", "n/a"))
                faction = str(event.get("faction", "NONE"))
                resource = str(event.get("resource", "UNKNOWN"))
                self._add_activity(
                    now_text,
                    "RES_EVT",
                    f"[{object_type}][GRID {grid}] {verb} {self._format_delta(delta)} {resource} ({faction}) @ {marker}",
                )

            self.prev_resource_event_ids = set(current_event_ids)

    def _populate_activity_table(self):
        for item in self.activity_tree.get_children():
            self.activity_tree.delete(item)

        for when_text, category, message in self.activity_rows[-MAX_ACTIVITY_LOG_ROWS:]:
            self.activity_tree.insert("", "end", values=(when_text, category, message))

    def _update_commander_status(self):
        if (
            self.commander_cycle_index <= 0 or
            self.commander_loop_interval <= 0 or
            self.commander_last_cycle_game_time is None or
            self.current_game_time is None or
            self.commander_last_cycle_game_time < 0
        ):
            self.commander_var.set("n/a")
            return

        elapsed = max(0.0, self.current_game_time - self.commander_last_cycle_game_time)
        remaining = max(0, int(self.commander_loop_interval - elapsed))
        self.commander_var.set(f"#{self.commander_cycle_index} | next cycle in ~{remaining}s")

    def _derive_support_display_state(self):
        base = self._derive_timed_action_display_state(
            self.commander_support_state,
            self.commander_support_event_game_time,
            self.commander_support_cooldown_seconds,
        )
        if self.commander_support_tier:
            if base == "COOL DOWN":
                return f"COOL DOWN ({self.commander_support_tier})"
            if base == "NONE":
                return f"NONE ({self.commander_support_tier})"
            if self.commander_support_tier not in base:
                return f"{base} ({self.commander_support_tier})"
        return base

    def _derive_logistics_display_state(self):
        return self._derive_timed_action_display_state(
            self.commander_logistics_state,
            self.commander_logistics_event_game_time,
            self.commander_support_cooldown_seconds,
        )

    def _derive_timed_action_display_state(self, raw_state, event_game_time, cooldown_seconds):
        normalized = normalize_value(raw_state).upper()
        now_game_time = self.current_game_time

        if normalized != "NONE":
            if now_game_time is not None and event_game_time is not None:
                elapsed = now_game_time - event_game_time
                if elapsed <= 1.0:
                    return normalized
                if elapsed < cooldown_seconds:
                    return "COOL DOWN"
            return normalized

        if now_game_time is not None and event_game_time is not None:
            elapsed = now_game_time - event_game_time
            if 0 <= elapsed < cooldown_seconds:
                return "COOL DOWN"

        return "NONE"

    def _populate_table(self, grouped_rows):
        self._clear_table()

        sorted_rows = sorted(grouped_rows.items(), key=lambda item: danger_sort_key(item[1]), reverse=True)

        for group_name, row in sorted_rows:
            row = grouped_rows[group_name]

            inferred_type = infer_type_from_composition(row)
            marker_type = infer_type_from_marker_text(row.get("MarkerText", ""))
            squad_type = inferred_type if inferred_type != "unknown" else marker_type if marker_type != "unknown" else normalize_value(row.get("SquadType", "unknown"))

            self.tree.insert(
                "",
                "end",
                values=(
                    group_name,
                    row.get("SquadSizeAlive", "0"),
                    row.get("SquadSizeTotal", "0"),
                    row.get("SquadCasualties", "0"),
                    squad_type,
                    row.get("SquadStrengthPct", "0"),
                    row.get("SquadStrengthLabel", "unknown"),
                    row.get("SquadAvgHealthPct", "0"),
                    row.get("LastSeen", "n/a"),
                ),
            )


def main():
    root = tk.Tk()
    style = ttk.Style(root)
    try:
        style.theme_use("clam")
    except tk.TclError:
        pass

    ReconViewerApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
