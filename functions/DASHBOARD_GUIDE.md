# TWS Status Dashboard - User Guide

## Overview

The TWS Status Dashboard provides a clean, web-based interface to monitor all simulation activity in real-time, replacing the need to read through RPT log files.

## How It Works

The system generates two files that work together:
1. **tws_dashboard.html** - The dashboard interface (generated once)
2. **tws_data.js** - Live data updates (generated every 2 minutes)

Both are exported to your Arma 3 RPT log file, where you can copy them out and view in any web browser.

---

## Setup Instructions

### Step 1: Run the Mission

Start your mission with the TWS system loaded. The dashboard will automatically initialize.

You'll see:
```
[TWS] ✓ Status Dashboard loaded
[TWS] Dashboard data exports to RPT log every 2 minutes
```

### Step 2: Find Your RPT Log

RPT logs are located in:
```
%LOCALAPPDATA%\Arma 3\
```

The file is named like: `arma3_x64_2024-12-12_12-34-56.rpt`

### Step 3: Extract the Dashboard Files

Open the RPT file in a text editor (Notepad++, VSCode, etc.)

#### Extract the HTML (once):

Look for:
```
[TWS] ========== DASHBOARD HTML START ==========
```

Copy everything between START and END markers to a new file named `tws_dashboard.html`

Save it anywhere on your computer.

#### Extract the Data (every update):

Look for:
```
[TWS] ========== DASHBOARD DATA START ==========
```

Copy everything between START and END markers to a new file named `tws_data.js`

Save it in the **same folder** as `tws_dashboard.html`

### Step 4: View the Dashboard

Double-click `tws_dashboard.html` to open it in your web browser.

You'll see a beautiful dashboard with:
- Real-time resource levels
- Operational tempo
- Factory status
- Commander personality
- Morale levels
- Casualties
- Sector control
- Recent activity feed

### Step 5: Update the Data

Every 2 minutes, new data is exported to the RPT log.

To update your dashboard:
1. Open the RPT log
2. Find the latest `========== DASHBOARD DATA START ==========`
3. Copy the new data section
4. Overwrite `tws_data.js` with the new data
5. Refresh your browser (F5)

---

## Automation (Optional)

### Windows PowerShell Script

Create `update_dashboard.ps1`:

```powershell
# Configuration
$rptPath = "$env:LOCALAPPDATA\Arma 3"
$outputPath = "C:\TWS_Dashboard"

# Create output directory
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

# Find latest RPT file
$latestRPT = Get-ChildItem -Path $rptPath -Filter "arma3_x64_*.rpt" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

if ($latestRPT) {
    Write-Host "Reading: $($latestRPT.Name)"
    $content = Get-Content $latestRPT.FullName -Raw
    
    # Extract HTML (only once)
    $htmlPath = Join-Path $outputPath "tws_dashboard.html"
    if (-not (Test-Path $htmlPath)) {
        if ($content -match '(?s)\[TWS\] ========== DASHBOARD HTML START ==========(.+?)\[TWS\] ========== DASHBOARD HTML END ==========') {
            $matches[1].Trim() | Out-File -FilePath $htmlPath -Encoding UTF8
            Write-Host "✓ Dashboard HTML extracted"
        }
    }
    
    # Extract latest data
    if ($content -match '(?s)(?:.+)\[TWS\] ========== DASHBOARD DATA START ==========(.+?)\[TWS\] ========== DASHBOARD DATA END ==========') {
        $dataPath = Join-Path $outputPath "tws_data.js"
        $matches[1].Trim() | Out-File -FilePath $dataPath -Encoding UTF8
        Write-Host "✓ Dashboard data updated"
        Write-Host ""
        Write-Host "Dashboard ready at: $htmlPath"
    }
}
```

**Usage:**
```powershell
# Run once to extract files
.\update_dashboard.ps1

# Or run continuously (updates every 2 minutes)
while ($true) { .\update_dashboard.ps1; Start-Sleep -Seconds 120 }
```

### Python Script (Cross-Platform)

Create `update_dashboard.py`:

```python
import os
import re
import time
from pathlib import Path

# Configuration
RPT_PATH = Path(os.getenv('LOCALAPPDATA')) / 'Arma 3'
OUTPUT_PATH = Path('C:/TWS_Dashboard')

OUTPUT_PATH.mkdir(exist_ok=True)

def find_latest_rpt():
    """Find the most recent RPT file"""
    rpt_files = list(RPT_PATH.glob('arma3_x64_*.rpt'))
    if not rpt_files:
        return None
    return max(rpt_files, key=lambda p: p.stat().st_mtime)

def extract_section(content, marker):
    """Extract content between markers"""
    pattern = rf'{marker} START =+(.+?){marker} END =+'
    match = re.search(pattern, content, re.DOTALL)
    return match.group(1).strip() if match else None

def update_dashboard():
    """Update dashboard files from latest RPT"""
    rpt_file = find_latest_rpt()
    if not rpt_file:
        print("No RPT file found")
        return
    
    print(f"Reading: {rpt_file.name}")
    content = rpt_file.read_text(encoding='utf-8', errors='ignore')
    
    # Extract HTML (once)
    html_path = OUTPUT_PATH / 'tws_dashboard.html'
    if not html_path.exists():
        html = extract_section(content, r'\[TWS\] ={10} DASHBOARD HTML')
        if html:
            html_path.write_text(html, encoding='utf-8')
            print("✓ Dashboard HTML extracted")
    
    # Extract latest data
    data = extract_section(content, r'\[TWS\] ={10} DASHBOARD DATA')
    if data:
        data_path = OUTPUT_PATH / 'tws_data.js'
        data_path.write_text(data, encoding='utf-8')
        print("✓ Dashboard data updated")
        print(f"\nDashboard ready at: {html_path}")

if __name__ == '__main__':
    # Run once
    update_dashboard()
    
    # Or run continuously (uncomment)
    # while True:
    #     update_dashboard()
    #     time.sleep(120)  # Update every 2 minutes
```

**Usage:**
```bash
python update_dashboard.py
```

---

## Dashboard Features

### BLUFOR Panel (Blue)
- Resource levels with color coding (green=good, yellow=warning, red=critical)
- Operational tempo bar
- Factory status (operational/total)
- Commander personality
- Morale indicator
- Casualty count
- Territory control

### OPFOR Panel (Red)
- Same features as BLUFOR
- Side-by-side comparison

### Activity Feed
- Last 20 events
- Timestamps
- Production notifications
- Reinforcement dispatches
- Training completions
- Sector events

### Refresh Button
- Manual refresh option
- Auto-refresh coming in future updates

---

## Customization

### Change Update Interval

In your mission init:
```sqf
TWS_dashboardConfig set ["updateInterval", 60]; // 1 minute
```

### Disable Dashboard

```sqf
TWS_dashboardConfig set ["enabled", false];
```

### Add Custom Activity

```sqf
["🎯 Custom event message"] call TWS_fnc_addActivity;
```

---

## Troubleshooting

### Dashboard not updating?

Check:
1. Mission is running
2. RPT file is being updated (check file timestamp)
3. You're copying the **latest** data section (there may be multiple)

### HTML looks broken?

- Make sure you copied the **entire** section between markers
- Check that quotes aren't escaped incorrectly
- Try a different browser (Chrome/Firefox work best)

### Can't find RPT file?

Run this in PowerShell:
```powershell
explorer "$env:LOCALAPPDATA\Arma 3"
```

---

## Future Enhancements

Coming soon:
- Auto-refresh without manual copy
- HTTP server option (requires extension)
- Historical charts
- Sector map visualization
- Alert notifications
- Mobile-friendly layout

---

## Manual Viewing Alternative

If you don't want to extract files, you can still use the enhanced monitoring system which outputs to chat every 2 minutes:

```sqf
// View in-game
TWS_monitoringConfig set ["enabled", true];

// Check status manually
[] call TWS_fnc_compileDetailedStatus;
```

---

**For support or questions, check QUICKSTART.md and README_TWS.md**
