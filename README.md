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
- **High-Frequency Actions**: Performs activities every 2-5 seconds for sustained 50-70% activity levels
- **Manual Toggle**: Stop/start automation with `Cmd+Alt+Ctrl+S`

## Prerequisites

You must have [Hammerspoon](https://www.hammerspoon.org/) installed on your Mac.

```bash
# Install Hammerspoon via Homebrew
brew install --cask hammerspoon
```

## Installation

### Option 1: Direct Clone (Recommended)

Clone this repository directly into your Hammerspoon configuration directory:

```bash
# Backup existing config if you have one
mv ~/.hammerspoon ~/.hammerspoon.backup

# Clone this repository
git clone https://github.com/yourusername/hammerspoon_script.git ~/.hammerspoon

# Reload Hammerspoon config
# You can do this from the Hammerspoon menu bar icon or run:
open -g "hammerspoon://reload"
```

### Option 2: Copy File

If you already have a Hammerspoon configuration:

```bash
# Clone to a temporary location
git clone https://github.com/yourusername/hammerspoon_script.git /tmp/hammerspoon_script

# Copy or merge the init.lua file
cp /tmp/hammerspoon_script/init.lua ~/.hammerspoon/

# Reload Hammerspoon
open -g "hammerspoon://reload"
```

### Option 3: Manual Download

1. Download [init.lua](init.lua) from this repository
2. Place it in `~/.hammerspoon/`
3. Reload Hammerspoon configuration

## Configuration

You can customize the behavior by editing the CONFIG section in [init.lua](init.lua):

```lua
local IDLE_SECONDS = 5          -- Time to wait before resuming after user activity
local ENABLE_GLOBAL_UI = true   -- Enable Mission Control/Spotlight actions
local ENABLE_TYPING = true      -- Enable keyboard typing in applications
local MIN_INTERVAL = 2          -- Minimum seconds between actions (lower = more activity)
local MAX_INTERVAL = 5          -- Maximum seconds between actions (lower = more activity)
```

**To adjust activity levels:**

- **Higher activity (60-80%)**: Set `MIN_INTERVAL = 1` and `MAX_INTERVAL = 3`
- **Current activity (50-70%)**: Use defaults `MIN_INTERVAL = 2` and `MAX_INTERVAL = 5`
- **Lower activity (20-40%)**: Set `MIN_INTERVAL = 6` and `MAX_INTERVAL = 12`
- **Disable typing**: Set `ENABLE_TYPING = false` to prevent keyboard input simulation

## Usage

### Automatic Start

The automation starts automatically when Hammerspoon loads the configuration.

### Manual Control

- **Toggle On/Off**: Press `Cmd+Alt+Ctrl+S` to manually stop or start the automation
- **Reload Config**: Use the Hammerspoon menu bar icon → "Reload Config"

### How It Works

1. The script schedules random activities at high frequency (every 2-5 seconds)
2. Actions include typing, scrolling, app switching, and system interactions
3. When you interact with your Mac (mouse, keyboard, scroll), it automatically pauses
4. After 5 seconds of inactivity, it automatically resumes
5. All simulated events have a grace period to avoid triggering the pause mechanism
6. Typing occurs in compatible apps: Code, TextEdit, Notes, Terminal, Safari, Chrome, Slack, Mail

## Troubleshooting

**Script not running?**

- Check Hammerspoon console for errors: Hammerspoon menu → Console
- Ensure Hammerspoon has Accessibility permissions: System Settings → Privacy & Security → Accessibility

**Getting rate-limited or detected?**

- Increase `MIN_INTERVAL` and `MAX_INTERVAL` for less frequent activity
- Disable `ENABLE_GLOBAL_UI` if Mission Control/Spotlight actions are too noticeable
- Disable `ENABLE_TYPING` if keyboard simulation is interfering with your work

**Typing appears in wrong applications?**

- The script only types in compatible apps (editors, browsers, terminals)
- If it interferes, set `ENABLE_TYPING = false` in the CONFIG section
- You can customize the app list in the typing section of the script

**Activity too high/intrusive?**

- Reduce frequency: Set `MIN_INTERVAL = 6` and `MAX_INTERVAL = 12`
- Disable features: Set `ENABLE_TYPING = false` or `ENABLE_GLOBAL_UI = false`
- The script will automatically pause when you're actively working

**Want to disable completely?**

- Press `Cmd+Alt+Ctrl+S` to stop
- Or comment out the `startAutomation()` call at the end of the script

## License

MIT License - feel free to modify and use as needed.

## Disclaimer

This tool is intended for legitimate purposes such as preventing your Mac from sleeping during presentations or long-running tasks. Please use responsibly and in accordance with your organization's policies.
