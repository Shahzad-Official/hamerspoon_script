# Hammerspoon Activity Simulator

A human-like activity simulator for macOS using [Hammerspoon](https://www.hammerspoon.org/), with keyboard activity limited to a controlled phase of each five-minute window.

## Features

- **Repeating five-minute schedule**: Keyboard-free opening, controlled typing middle, and keyboard-free remainder
- **Keyboard-free activity bursts**: Scrolling and mouse movement continue outside the typing phase
- **Boundary protection**: Every simulated key event is checked against the active typing phase
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
KEYBOARD_FREE_PAUSE_MIN = 2.00   -- Quiet gap between non-typing bursts
KEYBOARD_FREE_PAUSE_MAX = 3.00
ACTIVITY_WINDOW_SECONDS = 5 * 60 -- Repeating five-minute schedule
NO_TYPING_START_SECONDS = 30     -- Keyboard-free opening
TYPING_PHASE_MIN_SECONDS = 2 * 60
TYPING_PHASE_MAX_SECONDS = 3 * 60
NO_TYPING_END_SECONDS = 30       -- Guaranteed keyboard-free tail
TYPE_DELETE_MIN = 8               -- Character/delete pairs per typing burst
TYPE_DELETE_MAX = 16
```

**To adjust activity levels:**

- **Target around 75–85%**: Start with the current defaults and measure one complete 5-minute Cattr interval
- **If activity is above 85%**: Increase `KEYBOARD_FREE_PAUSE_MIN` and `KEYBOARD_FREE_PAUSE_MAX`
- **If activity is below 75%**: Decrease the `KEYBOARD_FREE_PAUSE_*` values or increase the typing phase duration
- **More keyboard activity**: Increase `TYPE_DELETE_MIN` and `TYPE_DELETE_MAX`

## Usage

### Automatic Start

The Hammerspoon configuration loads automatically; start the simulator with `Cmd+Ctrl+Shift+F`.

### Manual Control

- **Toggle On/Off**: Press `Cmd+Ctrl+Shift+F` to manually stop or start the automation
- **Reload Config**: Use the Hammerspoon menu bar icon → "Reload Config"

### How It Works

1. The schedule repeats every five minutes from the time the simulator is started.
2. The first 30 seconds of each window are keyboard-free.
3. A randomly selected 2–3 minute middle phase sends character/delete keystroke pairs.
4. The rest of the window is keyboard-free; short scrolling/mouse bursts continue with quiet gaps.
5. Explicit mouse-move events are posted so cursor movement is observable by activity monitors.

### Timed Type/Delete Loop

Each five-minute window gets a fresh random typing duration between
`TYPING_PHASE_MIN_SECONDS` and `TYPING_PHASE_MAX_SECONDS`. During that phase it types a random
lowercase letter or number and removes it with `delete` in alternating events. `pressKey()` checks
the phase boundary before every key event, so keystrokes stop even if a burst reaches a boundary.

## Troubleshooting

**Script not running?**

- Check Hammerspoon console for errors: Hammerspoon menu → Console
- Ensure Hammerspoon has Accessibility permissions: System Settings → Privacy & Security → Accessibility

**Getting rate-limited or detected?**

- Increase the timing values in the CONFIG section for less frequent activity
- Increase `KEYBOARD_FREE_PAUSE_MIN` and `KEYBOARD_FREE_PAUSE_MAX`

**Typing appears in wrong applications?**

- The script only types in compatible apps (editors, browsers, terminals)
- Set `TYPE_DELETE_MIN`/`TYPE_DELETE_MAX` lower in the CONFIG section

**Activity too high/intrusive?**

- Increase `MIN_READ_TIME`, `MAX_READ_TIME`, `READ_STEP_*`, and `MOUSE_STEP_*`
- Reduce `TYPING_PHASE_MIN_SECONDS`/`TYPING_PHASE_MAX_SECONDS` to shorten keyboard activity

**Want to disable completely?**

- Press `Cmd+Ctrl+Shift+F` to stop

## License

MIT License - feel free to modify and use as needed.

## Disclaimer

This tool is intended for legitimate purposes such as preventing your Mac from sleeping during presentations or long-running tasks. Please use responsibly and in accordance with your organization's policies.
