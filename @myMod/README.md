# My Test Mod - GUI Testing

This is a test mod to verify that Arma 3 mod loading and GUI systems work correctly.

## Folder Structure

```
@myMod/
├── mod.cpp                          (Mod definition)
└── addons/
    └── mymod_gui/
        ├── config.cpp               (Main config with CfgPatches)
        ├── functions.sqf            (Test functions)
        └── dialogs/
            ├── myMapDialog.hpp      (Standalone dialog)
            └── mapOverlay.hpp       (Map screen overlay)
```

## How to Test (Unpacked - No PBO Required)

### 1. Load the Mod in Arma 3 Launcher

1. Open Arma 3 Launcher
2. Go to "Mods" tab
3. Click "Add local mod"
4. Browse to: `D:\Arma 3\missions\discord-testing-a3.Stratis\@myMod`
5. Enable the mod checkbox
6. Launch the game

### 2. Test in Debug Console

Once in-game (in your mission):

**Test 1: Load functions**
```sqf
[] execVM "\@myMod\addons\mymod_gui\functions.sqf";
```

You should see chat messages confirming the functions loaded.

**Test 2: Open standalone dialog**
```sqf
[] call mymod_fnc_openDialog;
```

This should open a dialog window with test buttons.

Or directly:
```sqf
createDialog "MyMapDialog";
```

**Test 3: Test functions**
```sqf
[] call mymod_fnc_testFunction;
```

**Test 4: Check map overlay**
- Press M to open the map
- Look for two custom buttons on the left side:
  - "HVT Intel" (orange button)
  - "Test Dialog" (blue button)
- Click them to test

**Test 5: Map key handler**
```sqf
[] call mymod_fnc_addMapKeyHandler;
```
Then press M to open map, and press H key to test.

## What Each File Does

### mod.cpp
Defines the mod metadata (name, description, etc.)

### config.cpp
- Declares `CfgPatches` (required for Arma to recognize the addon)
- Includes the dialog definitions

### myMapDialog.hpp
A standalone dialog with:
- Background
- Title
- Test buttons
- Close button

Can be opened with `createDialog "MyMapDialog";`

### mapOverlay.hpp
Extends `RscDisplayMainMap` to add custom buttons to the map screen.
⚠️ WARNING: Display inheritance can be fragile. If the map breaks, comment out the include in config.cpp.

### functions.sqf
Contains reusable SQF functions:
- `mymod_fnc_openDialog` - Opens the test dialog
- `mymod_fnc_testFunction` - Simple test function
- `mymod_fnc_testMapAccess` - Checks if map is open
- `mymod_fnc_addMapKeyHandler` - Adds keyboard handler to map

## Troubleshooting

### Mod doesn't load
- Check that the path in Arma 3 Launcher is correct
- Make sure the mod is enabled (checkbox checked)
- Restart Arma 3 completely

### Dialog doesn't open
- Make sure config.cpp is correct (no syntax errors)
- Try loading functions first: `[] execVM "\@myMod\addons\mymod_gui\functions.sqf";`
- Check RPT logs for errors

### Map overlay doesn't show
- The map overlay might conflict with other mods
- Try commenting out the mapOverlay.hpp include in config.cpp
- Check if buttons are there but positioned off-screen (adjust x/y values)

### Syntax errors
- Config files use C-style syntax (semicolons required!)
- Each property needs a semicolon
- Arrays use {} not []
- Strings use quotes ""

## Next Steps

Once this works, you can:
- Modify colors and positions
- Add more buttons
- Create more complex dialogs
- Integrate with your HVT system
- Build proper function libraries
- Eventually PBO it for distribution

## Important Notes

- You're testing UNPACKED - no PBO required yet
- Only PBO it once everything works
- Keep functions modular (don't hardcode in config actions)
- Use unique IDD/IDC numbers to avoid conflicts (9000+ range)
- SafeZone coordinates: x/y are 0-1, where 0.5 is center
