# Hammerspoon Activity Simulator

A human-like activity simulator for macOS using [Hammerspoon](https://www.hammerspoon.org/). This script simulates realistic user activity to prevent your Mac from going to sleep or appearing idle, while intelligently pausing when you're actually using your computer.

## Features

- **High-Intensity Activity Simulation**: Performs random actions including:

  - **Keyboard typing in applications (30%)**: Types realistic text in editors, browsers, terminals, Slack, etc.
  - **Scrolling (25%)**: Vertical and horizontal scrolling with varied speeds
  - **App switching with Cmd+Tab (20%)**: Switches between applications
  - **Smooth mouse movements (10%)**: Natural cursor movements
  - **Mission Control (5%)**: Activates Mission Control view
  - **Window resizing/moving (4%)**: Adjusts window sizes and positions
  - **Spotlight search with typing (3%)**: Opens Spotlight and types search queries
  - **Copy/Paste/Select operations (2%)**: Text selection and clipboard operations
  - **Rapid scroll bursts (1%)**: Quick scrolling sequences

- **Intelligent Pause/Resume**: Automatically pauses when you use your Mac and resumes after 5 seconds of inactivity
- **High-Frequency Actions**: Uses short gaps between keyboard, scroll, and mouse events for sustained activity
- **Manual Toggle**: Stop/start automation with `Cmd+Ctrl+Shift+F`

## Prerequisites

You must have [Hammerspoon](https://www.hammerspoon.org/) installed on your Mac.

```bash
# Install Hammerspoon via Homebrew
brew install --cask hammerspoon

# Launch Hammerspoon (first time only)
open -a Hammerspoon

# Grant Accessibility permissions when prompted
# Go to: System Settings → Privacy & Security → Accessibility
# Enable Hammerspoon
```

## Installation

### Option 1: Direct Clone (Recommended)

Clone this repository directly into your Hammerspoon configuration directory:

```bash
# Backup existing config with timestamp (if it exists)
if [ -d ~/.hammerspoon ]; then
  mv ~/.hammerspoon ~/.hammerspoon.backup.$(date +%Y%m%d_%H%M%S)
fi

# Clone this repository
git clone https://github.com/Shahzad-Official/hamerspoon_script.git ~/.hammerspoon

# Launch Hammerspoon (if not already running)
open -a Hammerspoon 2>/dev/null || echo "Hammerspoon is already running"

# Reload Hammerspoon configuration
open -g "hammerspoon://reload"
```

**Note**: If you already have a `.hammerspoon.backup` directory, the backup will be timestamped to avoid conflicts.

### Option 2: Fresh Install (if Option 1 fails)

If the directory already exists and you want a clean install:

```bash
# Remove existing directory (⚠️ WARNING: This deletes your current config)
rm -rf ~/.hammerspoon ~/.hammerspoon.backup*

# Clone this repository
git clone https://github.com/Shahzad-Official/hamerspoon_script.git ~/.hammerspoon

# Launch and reload Hammerspoon
open -a Hammerspoon
open -g "hammerspoon://reload"
```

### Option 3: Copy File

If you already have a Hammerspoon configuration you want to keep:

```bash
# Clone to a temporary location
git clone https://github.com/Shahzad-Official/hamerspoon_script.git /tmp/hamerspoon_script

# Copy or merge the init.lua file
cp /tmp/hamerspoon_script/init.lua ~/.hammerspoon/

# Reload Hammerspoon configuration
open -g "hammerspoon://reload"
```

### Option 4: Manual Download

1. Download [init.lua](init.lua) from this repository
2. Place it in `~/.hammerspoon/`
3. Reload Hammerspoon configuration

## Configuration

You can customize the behavior by editing the CONFIG section in [init.lua](init.lua):

```lua
MIN_READ_TIME = 1.00            -- Gap between normal actions
MAX_READ_TIME = 1.80
READ_STEP_MIN = 1.00            -- Gap between read/scroll bursts
READ_STEP_MAX = 1.80
MOUSE_STEP_MIN = 0.45            -- Gap between mouse movements
MOUSE_STEP_MAX = 0.90
SCROLLS_BEFORE_TYPING = 3        -- Scroll ticks before keyboard activity begins
```

**To adjust activity levels:**

- **Higher activity (approximately 70-85%)**: Keep the current defaults, especially the `READ_STEP_*` and `MOUSE_STEP_*` gaps
- **Lower activity**: Increase `MIN_READ_TIME`, `MAX_READ_TIME`, `READ_STEP_MIN`, and `READ_STEP_MAX`
- **Start keyboard activity sooner**: Lower `SCROLLS_BEFORE_TYPING` (minimum `1`)

## Usage

### Automatic Start

The automation starts automatically when Hammerspoon loads the configuration.

### Manual Control

- **Toggle On/Off**: Press `Cmd+Ctrl+Shift+F` to manually stop or start the automation
- **Reload Config**: Use the Hammerspoon menu bar icon → "Reload Config"

### How It Works

1. The script schedules random activities with sub-second gaps between input bursts
2. Actions include typing, scrolling, app switching, and mouse movement in VS Code
3. The typing phase starts after the configured number of scroll ticks
4. Explicit mouse-move events are posted so cursor movement is observable by activity monitors
5. At the deadline, keyboard events stop and higher-frequency scroll/mouse activity continues

### Timed Type/Delete Loop

When the simulator is started, a 4-minute-50-second monotonic timer begins immediately. After
3 scroll ticks, it rapidly types a random lowercase letter or number and removes it with
Backspace in alternating events. At the exact deadline, all keyboard events are blocked and the
simulator continues with scroll and mouse movement actions only.

## Troubleshooting

**Script not running?**

- Check Hammerspoon console for errors: Hammerspoon menu → Console
- Ensure Hammerspoon has Accessibility permissions: System Settings → Privacy & Security → Accessibility

**Getting rate-limited or detected?**

- Increase the timing values in the CONFIG section for less frequent activity
- Increase `SCROLLS_BEFORE_TYPING` if keyboard simulation should start later

**Typing appears in wrong applications?**

- The script only types in compatible apps (editors, browsers, terminals)
- Increase `SCROLLS_BEFORE_TYPING` or set `TYPE_DELETE_MIN`/`TYPE_DELETE_MAX` lower in the CONFIG section

**Activity too high/intrusive?**

- Increase `MIN_READ_TIME`, `MAX_READ_TIME`, `READ_STEP_*`, and `MOUSE_STEP_*`
- Increase `SCROLLS_BEFORE_TYPING` to delay keyboard simulation

**Want to disable completely?**

- Press `Cmd+Ctrl+Shift+F` to stop

## License

MIT License - feel free to modify and use as needed.

## Disclaimer

This tool is intended for legitimate purposes such as preventing your Mac from sleeping during presentations or long-running tasks. Please use responsibly and in accordance with your organization's policies.
