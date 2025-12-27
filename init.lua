--------------------------------------------------
-- Human-like activity simulator (macOS)
-- Pauses on real user input, resumes after 5s idle
-- Rectified + hardened version
--------------------------------------------------

math.randomseed(os.time())

--------------------------------------------------
-- CONFIG
--------------------------------------------------
local IDLE_SECONDS = 5
local SELF_EVENT_GRACE_MS = 3000 -- Increased to 3s to better prevent self-pause
local ENABLE_GLOBAL_UI = true -- Mission Control / Spotlight
local ENABLE_TYPING = true -- Keyboard typing in apps
local MIN_INTERVAL = 2 -- Balanced for natural activity
local MAX_INTERVAL = 5 -- Balanced for natural activity
local AUTO_REVERT_DELAY = 0.8 -- Fast revert to avoid conflicts (0.8s)
local ENABLE_AUTO_REVERT = true -- Automatically revert actions for humanized behavior
local PRIORITY_APPS = {"Code", "Visual Studio Code"} -- VS Code is top priority
local SECONDARY_APPS = {"Chrome", "Google Chrome"} -- Chrome secondary
local VSCODE_FOCUS_CHANCE = 85 -- 85% chance to focus VS Code specifically
local PRIORITY_APP_FOCUS_CHANCE = 75 -- Overall chance to focus priority apps

--------------------------------------------------
-- STATE
--------------------------------------------------
local activityTimer = nil
local resumeTimer = nil
local isPausedByUser = false
local lastSimulationTime = 0
local actionHistory = {} -- Store history of actions for undo
local MAX_HISTORY = 10 -- Keep last 10 actions

--------------------------------------------------
-- TIME (MONOTONIC)
--------------------------------------------------
local function nowMs()
  return hs.timer.secondsSinceEpoch() * 1000
end

--------------------------------------------------
-- TYPING HELPERS
--------------------------------------------------
-- Terminal commands for NestJS & Flutter developer (Flutter-focused)
local terminalCommands = {
  "flutter run", "flutter doctor", "flutter pub get", "flutter clean",
  "flutter build apk", "flutter analyze", "flutter create", "flutter test",
  "git status", "git add .", "git commit -m \"", "git push origin",
  "npm run start:dev", "npm install", "npm run build",
  "docker-compose up -d", "docker ps", "yarn install",
  "cd mobile && flutter pub get", "cd backend && npm install",
  "flutter build ios", "flutter devices", "flutter upgrade"
}

-- Flutter/Dart code snippets (PRIMARY - most common)
local flutterSnippets = {
  "class MyWidget extends StatelessWidget {", "Widget build(BuildContext context) {",
  "return Scaffold(", "setState(() {", "final controller = TextEditingController();",
  "Navigator.push(context, MaterialPageRoute(", "import 'package:flutter/material.dart';",
  "Future<void> fetchData() async {", "try { await http.get(",
  "child: Column(children: [", "onPressed: () {", "const SizedBox(height: ",
  "Provider.of<", "BlocBuilder<", "GetX<", "StreamBuilder<",
  "final response = await dio.get(", "ListView.builder(itemBuilder: (context, index) =>",
  "Container(padding: EdgeInsets.all(", "Text('", "ElevatedButton(",
  "TextFormField(decoration: InputDecoration(",
  "final _formKey = GlobalKey<FormState>();", "context.read<",
  "Navigator.pop(context);", "showDialog(context: context, builder: (context) =>",
  "FutureBuilder<", "Image.asset('", "Icon(Icons."
}

-- NestJS code snippets (SECONDARY)
local nestjsSnippets = {
  "@Controller('", "@Get()", "@Post()", "@Injectable()",
  "async create(@Body() dto: ", "constructor(private readonly ",
  "import { Controller, Get, Post } from '@nestjs/common';",
  "export class AppService {", "@Module({ imports: [",
  "async findAll(): Promise<", "return this.service.",
  "@UseGuards(JwtAuthGuard)", "throw new HttpException(",
  "await this.repository.save(", "@ApiTags('",
  "implements OnModuleInit {", "private readonly logger = new Logger("
}

-- Mixed code snippets for full-stack dev
local codeSnippets = {
  "async function fetchData() {", "const response = await axios.get(",
  "try { const result = ", "} catch (error) { console.error(",
  "interface UserDto {", "type ResponseType = {",
  "export default function", "import { useState } from 'react';",
  "const [data, setData] = useState(", "useEffect(() => {",
  "return { statusCode: 200,", "await repository.findOne(",
}

-- Browser search queries for developers (Flutter-focused)
local browserSearches = {
  "flutter widgets catalog", "flutter state management", "dart async programming",
  "flutter bloc pattern", "flutter riverpod tutorial", "dart null safety",
  "flutter responsive design", "firebase flutter integration", "flutter animations",
  "stackoverflow flutter", "flutter pub packages", "flutter dio http",
  "nestjs documentation", "nestjs typeorm relations", "nestjs jwt authentication",
  "docker nestjs production", "nestjs swagger setup", "nestjs middleware"
}

-- Regular text for notes/documents (Flutter-focused)
local documentText = {
  "mobile app feature requirements", "flutter widget tree optimization",
  "UI/UX design implementation notes", "state management refactoring",
  "API integration documentation", "app performance improvements",
  "sprint planning tasks", "code review comments and feedback",
  "user authentication flow", "backend service architecture",
  "deployment checklist items", "bug fixes and improvements needed"
}

-- Communication text for Slack/Mail (Flutter-focused)
local messageText = {
  "pushed the latest Flutter changes", "updated the mobile UI components",
  "completed the feature implementation", "flutter build completed successfully",
  "need help with flutter widget", "fixed the state management issue",
  "merged the PR, please review", "backend service is ready for testing",
  "deployment completed successfully", "database migration ran successfully",
  "found a bug in the API endpoint", "code review requested for mobile module"
}

-- Generic code comments for VS Code
local codeComments = {
  "// TODO: Refactor this logic",
  "// FIXME: Handle edge cases",
  "// NOTE: Review performance here",
  "// TODO: Add error handling",
  "// OPTIMIZE: Improve efficiency",
  "// BUG: Check null values",
  "// REVIEW: Verify this implementation",
  "// TODO: Add unit tests",
  "// NOTE: Consider refactoring",
  "// FIXME: Update documentation",
  "// TODO: Implement validation",
  "// REVIEW: Check for memory leaks",
  "// NOTE: Optimize for performance",
  "// TODO: Add logging here",
  "// FIXME: Handle async properly"
}

-- Function to add comment in code
local function addCodeComment()
  local comment = codeComments[math.random(1, #codeComments)]
  
  -- Track this action for undo
  addToHistory("comment", { text = comment })
  
  -- Go to end of current line and add new line
  hs.eventtap.keyStroke({"cmd"}, "right")
  hs.timer.usleep(30000) -- Faster
  hs.eventtap.keyStroke({}, "return")
  hs.timer.usleep(50000) -- Faster
  
  -- Type the comment faster (counts as more keystrokes)
  for i = 1, #comment do
    local char = comment:sub(i, i)
    hs.eventtap.keyStrokes(char)
    hs.timer.usleep(math.random(20000, 40000)) -- Faster typing
  end
  
  -- Quick undo using Cmd+Z (faster revert)
  hs.timer.doAfter(AUTO_REVERT_DELAY, function()
    -- Use Cmd+Z to undo - this works with editor's undo system
    hs.eventtap.keyStroke({"cmd"}, "z")
    hs.timer.usleep(50000)
    -- Undo again to remove the newline
    hs.eventtap.keyStroke({"cmd"}, "z")
    
    -- Add scrolling after undo (simulates reading the code)
    hs.timer.doAfter(0.2, function()
      local scrollAmount = math.random(-20, -5)
      hs.eventtap.scrollWheel({ 0, scrollAmount }, {}, "pixel")
      
      -- Always scroll back for clean revert
      hs.timer.doAfter(AUTO_REVERT_DELAY, function()
        hs.eventtap.scrollWheel({ 0, -scrollAmount }, {}, "pixel")
      end)
    end)
  end)
end

-- Detect file type from window title or app
local function detectFileType(appName, windowTitle)
  windowTitle = windowTitle or ""
  
  -- Check window title for file extensions and keywords
  if windowTitle:match("%.dart") or windowTitle:match("flutter") or 
     windowTitle:match("%.yaml") and (windowTitle:match("pubspec") or appName:match("Code")) then
    return "flutter"
  elseif windowTitle:match("%.ts") or windowTitle:match("%.js") or 
         windowTitle:match("nest") or windowTitle:match("%.controller") or
         windowTitle:match("%.service") or windowTitle:match("%.module") then
    return "nestjs"
  elseif appName:match("Code") or appName:match("Visual Studio Code") then
    -- Default to Flutter for VS Code if uncertain (user does mostly Flutter)
    return "flutter"
  end
  
  return "general"
end

-- Generate text based on app type and file context
local function getTextForApp(appName)
  local win = hs.window.focusedWindow()
  local windowTitle = win and win:title() or ""
  local fileType = detectFileType(appName, windowTitle)
  
  if appName:match("Terminal") or appName:match("iTerm") then
    return terminalCommands[math.random(1, #terminalCommands)]
  elseif appName:match("Code") or appName:match("Xcode") or appName:match("Sublime") or appName:match("Atom") then
    -- Intelligent file-based snippet selection
    if fileType == "flutter" then
      -- 80% Flutter, 20% other for Flutter files
      if math.random() > 0.2 then
        return flutterSnippets[math.random(1, #flutterSnippets)]
      else
        return codeSnippets[math.random(1, #codeSnippets)]
      end
    elseif fileType == "nestjs" then
      -- 70% NestJS, 30% other for NestJS files
      if math.random() > 0.3 then
        return nestjsSnippets[math.random(1, #nestjsSnippets)]
      else
        return codeSnippets[math.random(1, #codeSnippets)]
      end
    else
      -- Default: Favor Flutter (user does mostly Flutter) 60% Flutter, 20% NestJS, 20% general
      local rand = math.random()
      if rand > 0.4 then
        return flutterSnippets[math.random(1, #flutterSnippets)]
      elseif rand > 0.2 then
        return nestjsSnippets[math.random(1, #nestjsSnippets)]
      else
        return codeSnippets[math.random(1, #codeSnippets)]
      end
    end
  elseif appName:match("Safari") or appName:match("Chrome") or appName:match("Firefox") then
    return browserSearches[math.random(1, #browserSearches)]
  elseif appName:match("Slack") or appName:match("Mail") or appName:match("Messages") then
    return messageText[math.random(1, #messageText)]
  elseif appName:match("Notes") or appName:match("TextEdit") or appName:match("Pages") then
    return documentText[math.random(1, #documentText)]
  else
    -- Default: Favor Flutter since user does mostly Flutter work
    local rand = math.random()
    if rand > 0.5 then
      return flutterSnippets[math.random(1, #flutterSnippets)]
    elseif rand > 0.3 then
      return codeSnippets[math.random(1, #codeSnippets)]
    else
      return nestjsSnippets[math.random(1, #nestjsSnippets)]
    end
  end
end

local function simulateTyping(text)
  for i = 1, #text do
    local char = text:sub(i, i)
    -- Faster typing for more activity counts
    local delay = 30000
    if char:match("[%p%d]") then
      delay = math.random(40000, 80000) -- Faster for punctuation/numbers
    else
      delay = math.random(20000, 60000) -- Faster for letters
    end
    hs.timer.usleep(delay)
    hs.eventtap.keyStrokes(char)
    
    -- Less frequent pauses for more consistent activity
    if math.random() > 0.95 and i < #text then
      hs.timer.usleep(math.random(150000, 300000)) -- Shorter pauses
    end
  end
end

local function deleteTypedText(textLength)
  -- Fast and reliable deletion using multiple methods
  -- Method 1: Use Cmd+Z (undo) - most reliable for editors
  hs.eventtap.keyStroke({"cmd"}, "z")
  hs.timer.usleep(30000)
  
  -- Method 2: Select recent text and delete as backup
  for i = 1, math.min(textLength, 100) do
    hs.eventtap.keyStroke({}, "delete")
    if i % 10 == 0 then
      hs.timer.usleep(10000) -- Tiny pause every 10 deletes
    end
  end
end

--------------------------------------------------
-- UNDO/REVERT FUNCTIONALITY
--------------------------------------------------
local function addToHistory(actionType, data)
  table.insert(actionHistory, 1, {
    type = actionType,
    data = data,
    timestamp = os.time()
  })
  
  -- Keep history size limited
  if #actionHistory > MAX_HISTORY then
    table.remove(actionHistory, #actionHistory)
  end
end

local function undoLastAction()
  if #actionHistory == 0 then
    hs.alert.show("⚠️ No actions to undo", 1)
    return
  end
  
  local lastAction = table.remove(actionHistory, 1)
  
  if lastAction.type == "typing" then
    -- Undo typing by sending Cmd+Z
    hs.eventtap.keyStroke({"cmd"}, "z")
    hs.alert.show("⎌ Undone: " .. lastAction.type, 0.8)
  elseif lastAction.type == "comment" then
    -- Undo comment addition
    hs.eventtap.keyStroke({"cmd"}, "z")
    hs.alert.show("⎌ Undone: comment", 0.8)
  elseif lastAction.type == "window_resize" and lastAction.data then
    -- Restore previous window frame
    local win = hs.window.focusedWindow()
    if win then
      win:setFrame(lastAction.data.originalFrame, 0.2)
      hs.alert.show("⎌ Undone: window resize", 0.8)
    end
  elseif lastAction.type == "scroll" then
    -- Reverse scroll
    if lastAction.data then
      hs.eventtap.scrollWheel({ 0, -lastAction.data.amount }, {}, "pixel")
      hs.alert.show("⎌ Undone: scroll", 0.8)
    end
  else
    hs.alert.show("⎌ Undone: " .. lastAction.type, 0.8)
  end
end

local function clearHistory()
  actionHistory = {}
  hs.alert.show("🗑️ Action history cleared", 1)
end

--------------------------------------------------
-- PRIORITY APP HELPERS
--------------------------------------------------
local function isPriorityApp(appName)
  for _, priority in ipairs(PRIORITY_APPS) do
    if appName:match(priority) then
      return true
    end
  end
  for _, secondary in ipairs(SECONDARY_APPS) do
    if appName:match(secondary) then
      return true
    end
  end
  return false
end

local function isVSCode(appName)
  return appName:match("Code") or appName:match("Visual Studio Code")
end

local function focusPriorityApp()
  -- Try to find VS Code and Chrome
  local vscode = hs.application.find("Code") or hs.application.find("Visual Studio Code")
  local chrome = hs.application.find("Chrome") or hs.application.find("Google Chrome")
  
  -- 80% chance to focus VS Code if it exists, otherwise Chrome
  if vscode and math.random(1, 100) <= VSCODE_FOCUS_CHANCE then
    vscode:activate()
    return true
  elseif chrome then
    chrome:activate()
    return true
  elseif vscode then
    -- Fallback to VS Code if Chrome wasn't chosen
    vscode:activate()
    return true
  end
  return false
end

--------------------------------------------------
-- ACTIVITY FUNCTION (REAL INPUT)
--------------------------------------------------
local function simulateActivity()
  -- Skip if user is active
  if isPausedByUser then 
    print("⏸ Skipped - user is active")
    return 
  end
  
  -- Mark this as simulated activity FIRST to prevent self-pause
  lastSimulationTime = nowMs()
  print("✓ Executing activity...")

  -- Focus priority apps less frequently (60% chance)
  if math.random(1, 100) <= PRIORITY_APP_FOCUS_CHANCE then
    focusPriorityApp()
    hs.timer.usleep(500000) -- Wait 500ms for app to focus
  end

  -- Always: mouse movement that reverts (counts as activity)
  local originalPos = hs.mouse.absolutePosition()
  hs.mouse.absolutePosition({
    x = originalPos.x + math.random(-12, 12),
    y = originalPos.y + math.random(-12, 12)
  })
  -- Revert mouse position after delay
  hs.timer.doAfter(AUTO_REVERT_DELAY, function()
    hs.mouse.absolutePosition(originalPos)
  end)

  local action = math.random(1, 100)

  ------------------------------------------------
  -- OPTION 1: Type text and revert in ANY app (45% - TOP PRIORITY)
  ------------------------------------------------
  if action <= 45 and ENABLE_TYPING then
    lastSimulationTime = nowMs() -- Prevent self-pause during typing
    local win = hs.window.focusedWindow()
    if win then
      local appName = win:application():name()
      
      -- Get intelligent text based on the app (works for ALL apps)
      local text = getTextForApp(appName)
      local textLength = #text
      
      -- Track this action for undo
      addToHistory("typing", { text = text, app = appName })
      
      -- Type immediately (no delay)
      simulateTyping(text)
      
      -- Auto-revert: delete the typed text quickly
      hs.timer.doAfter(AUTO_REVERT_DELAY, function()
        deleteTypedText(textLength)
      end)
    end

  ------------------------------------------------
  -- OPTION 2: Click actions - buttons, UI elements, tabs (35% - EQUAL PRIORITY)
  ------------------------------------------------
  elseif action <= 80 then
    lastSimulationTime = nowMs() -- Prevent self-pause
    local originalPos = hs.mouse.absolutePosition()
    
    -- Different types of click interactions
    local clickType = math.random(1, 5)
    
    if clickType == 1 then
      -- Single click at current position (like selecting text or clicking UI)
      addToHistory("click", { type = "single", pos = originalPos })
      hs.eventtap.leftClick(originalPos)
      
    elseif clickType == 2 then
      -- Double click (like selecting word or opening file)
      addToHistory("click", { type = "double", pos = originalPos })
      hs.eventtap.leftClick(originalPos)
      hs.timer.usleep(50000)
      hs.eventtap.leftClick(originalPos)
      
    elseif clickType == 3 then
      -- Move and click (like clicking a button or tab)
      local target = {
        x = originalPos.x + math.random(-200, 200),
        y = originalPos.y + math.random(-100, 100)
      }
      
      -- Smooth movement to target
      local steps = math.random(5, 10)
      for i = 1, steps do
        hs.timer.doAfter(0.02 * i, function()
          hs.mouse.absolutePosition({
            x = originalPos.x + (target.x - originalPos.x) * (i / steps),
            y = originalPos.y + (target.y - originalPos.y) * (i / steps)
          })
        end)
      end
      
      -- Click at target position
      hs.timer.doAfter(0.02 * steps + 0.05, function()
        addToHistory("click", { type = "move_and_click", pos = target, original = originalPos })
        hs.eventtap.leftClick(target)
        
        -- Auto-revert: move back to original position
        if ENABLE_AUTO_REVERT then
          hs.timer.doAfter(AUTO_REVERT_DELAY, function()
            for j = 1, steps do
              hs.timer.doAfter(0.02 * j, function()
                local currentPos = hs.mouse.absolutePosition()
                hs.mouse.absolutePosition({
                  x = currentPos.x + (originalPos.x - currentPos.x) * (j / steps),
                  y = currentPos.y + (originalPos.y - currentPos.y) * (j / steps)
                })
              end)
            end
          end)
        end
      end)
      
    elseif clickType == 4 then
      -- Click and drag (like selecting text or resizing)
      local dragTarget = {
        x = originalPos.x + math.random(-100, 100),
        y = originalPos.y + math.random(-50, 50)
      }
      
      addToHistory("click", { type = "drag", start = originalPos, target = dragTarget })
      
      -- Perform drag
      hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, originalPos):post()
      hs.timer.usleep(50000)
      
      -- Drag to target
      local steps = 8
      for i = 1, steps do
        hs.timer.doAfter(0.03 * i, function()
          local dragPos = {
            x = originalPos.x + (dragTarget.x - originalPos.x) * (i / steps),
            y = originalPos.y + (dragTarget.y - originalPos.y) * (i / steps)
          }
          hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDragged, dragPos):post()
        end)
      end
      
      -- Release mouse
      hs.timer.doAfter(0.03 * steps + 0.05, function()
        hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, dragTarget):post()
        
        -- Auto-revert: move back
        if ENABLE_AUTO_REVERT then
          hs.timer.doAfter(AUTO_REVERT_DELAY, function()
            hs.mouse.absolutePosition(originalPos)
          end)
        end
      end)
      
    else
      -- Right click (context menu)
      addToHistory("click", { type = "right", pos = originalPos })
      hs.eventtap.rightClick(originalPos)
      
      -- Close context menu with Escape
      hs.timer.doAfter(0.4, function()
        hs.eventtap.keyStroke({}, "escape")
      end)
    end -- Close clickType if statement

  ------------------------------------------------
  -- OPTION 3: Add code comments in VS Code (10% - additional typing)
  ------------------------------------------------
  elseif action <= 90 then
    lastSimulationTime = nowMs() -- Prevent self-pause
    local win = hs.window.focusedWindow()
    if win and isVSCode(win:application():name()) then
      addCodeComment()
    else
      -- Fallback to scroll if not in VS Code
      local scrollAmount = math.random(-25, -8)
      hs.eventtap.scrollWheel({ 0, scrollAmount }, {}, "pixel")
      if ENABLE_AUTO_REVERT then
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.scrollWheel({ 0, -scrollAmount }, {}, "pixel")
        end)
      end
    end

  ------------------------------------------------
  -- OPTION 4: Scroll (5% - reduced)
  ------------------------------------------------
  elseif action <= 95 then
    lastSimulationTime = nowMs() -- Prevent self-pause
    -- More aggressive scrolling
    local scrollType = math.random(1, 3)
    if scrollType == 1 then
      -- Single scroll
      local amount = math.random(-30, -5)
      addToHistory("scroll", { amount = amount })
      hs.eventtap.scrollWheel({ 0, amount }, {}, "pixel")
      
      -- Auto-revert: scroll back after delay
      if ENABLE_AUTO_REVERT then
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.scrollWheel({ 0, -amount }, {}, "pixel")
        end)
      end
    elseif scrollType == 2 then
      -- Double scroll (rapid)
      local amount1 = math.random(-20,-8)
      local amount2 = math.random(-20,-8)
      addToHistory("scroll", { amount = amount1 + amount2 })
      hs.eventtap.scrollWheel({ 0, amount1 }, {}, "pixel")
      hs.timer.doAfter(0.1, function()
        hs.eventtap.scrollWheel({ 0, amount2 }, {}, "pixel")
        
        -- Auto-revert: scroll back after delay
        if ENABLE_AUTO_REVERT then
          hs.timer.doAfter(AUTO_REVERT_DELAY, function()
            hs.eventtap.scrollWheel({ 0, -(amount1 + amount2) }, {}, "pixel")
          end)
        end
      end)
    else
      -- Horizontal scroll
      local amount = math.random(-15,15)
      addToHistory("scroll", { amount = amount, horizontal = true })
      hs.eventtap.scrollWheel({ amount, 0 }, {}, "pixel")
      
      -- Auto-revert: scroll back after delay
      if ENABLE_AUTO_REVERT then
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.scrollWheel({ -amount, 0 }, {}, "pixel")
        end)
      end
    end

  ------------------------------------------------
  -- OPTION 5: Cmd+Tab window switching (3% - minimal)
  ------------------------------------------------
  elseif action <= 98 then
    -- Update timestamp to prevent self-pause during Cmd+Tab
    lastSimulationTime = nowMs()
    
    -- Method 1: Use Cmd+Tab (70% of the time)
    if math.random() > 0.3 then
      -- Proper Cmd+Tab implementation
      hs.eventtap.keyStroke({"cmd"}, "tab")
      hs.timer.usleep(150000)
      
      -- Sometimes tab multiple times
      if math.random() > 0.5 then
        hs.eventtap.keyStroke({"cmd"}, "tab")
      end
    else
      -- Method 2: Direct app activation (30% of the time)
      focusPriorityApp()
      hs.timer.usleep(300000)
    end

    -- Scroll after switching
    hs.timer.doAfter(0.4, function()
      lastSimulationTime = nowMs() -- Prevent pause
      hs.eventtap.scrollWheel({ 0, math.random(-20,-8) }, {}, "pixel")
    end)

  ------------------------------------------------
  -- OPTION 6: Smooth mouse movement (2% - fallback)
  ------------------------------------------------
  else
    lastSimulationTime = nowMs() -- Prevent self-pause
    local start = hs.mouse.absolutePosition()
    local target = {
      x = start.x + math.random(-150,150), -- Larger movements
      y = start.y + math.random(-100,100)
    }

    local steps = math.random(8,15) -- More steps for smoother movement
    for i = 1, steps do
      hs.timer.doAfter(0.02 * i, function()
        hs.mouse.absolutePosition({
          x = start.x + (target.x - start.x) * (i / steps),
          y = start.y + (target.y - start.y) * (i / steps)
        })
      end)
    end
    
    -- Auto-revert: move mouse back to start after delay
    if ENABLE_AUTO_REVERT then
      hs.timer.doAfter(AUTO_REVERT_DELAY + 0.3, function()
        for i = 1, steps do
          hs.timer.doAfter(0.02 * i, function()
            local currentPos = hs.mouse.absolutePosition()
            hs.mouse.absolutePosition({
              x = currentPos.x + (start.x - currentPos.x) * (i / steps),
              y = currentPos.y + (start.y - currentPos.y) * (i / steps)
            })
          end)
        end
      end)
    else
      -- Sometimes click at the end of movement (old behavior)
      if math.random() > 0.7 then
        hs.timer.doAfter(0.02 * steps + 0.1, function()
          hs.eventtap.leftClick(hs.mouse.absolutePosition())
        end)
      end
    end
  end -- Close main action if/elseif chain

  ------------------------------------------------
  -- (Mission Control disabled to prioritize typing)
  ------------------------------------------------

  ------------------------------------------------
  -- OPTION 7: Window resize / move (2%)
  ------------------------------------------------
  if action <= 97 then
    local win = hs.window.focusedWindow()
    if win then
      local f = win:frame()
      local originalFrame = hs.geometry.copy(f) -- Save original
      local s = win:screen():frame()

      if math.random() > 0.5 then
        f.w = math.max(400, f.w + math.random(-50,50))
        f.h = math.max(300, f.h + math.random(-50,50))
      else
        f.x = math.max(s.x, math.min(s.x + s.w - f.w, f.x + math.random(-30,30)))
        f.y = math.max(s.y, math.min(s.y + s.h - f.h, f.y + math.random(-30,30)))
      end

      addToHistory("window_resize", { originalFrame = originalFrame })
      win:setFrame(f, 0.2)
      
      -- Auto-revert: restore window after delay
      if ENABLE_AUTO_REVERT then
        hs.timer.doAfter(AUTO_REVERT_DELAY + 0.5, function()
          if win and win:isVisible() then
            win:setFrame(originalFrame, 0.2)
          end
        end)
      end
    end

  ------------------------------------------------
  -- OPTION 8: Spotlight search with typing (1%)
  ------------------------------------------------
  if action <= 98 and ENABLE_GLOBAL_UI and ENABLE_TYPING then
    hs.eventtap.keyStroke({"cmd"}, "space")
    hs.timer.doAfter(0.3, function()
      local searchTerms = {"calculator", "system preferences", "activity monitor", "finder", "safari", "notes", "terminal"}
      local term = searchTerms[math.random(1, #searchTerms)]
      local termLength = #term
      simulateTyping(term)
      -- Delete the search and close spotlight
      hs.timer.doAfter(0.7, function()
        deleteTypedText(termLength)
        hs.timer.usleep(200000)
        hs.eventtap.keyStroke({}, "escape")
      end)
    end)

  ------------------------------------------------
  -- OPTION 8: Copy/Paste/Select operations (5% - increased with auto-revert)
  ------------------------------------------------
  if action <= 98 then
    local operations = {
      function() 
        hs.eventtap.keyStroke({"cmd"}, "a") -- Select all
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.keyStroke({}, "right") -- Deselect
        end)
      end,
      function() 
        hs.eventtap.keyStroke({"cmd"}, "c") -- Copy (safe, no visual change)
      end,
      function() 
        hs.eventtap.keyStroke({"cmd"}, "f") -- Find
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.keyStroke({}, "escape") -- Close find
        end)
      end,
      function() 
        hs.eventtap.keyStroke({"shift"}, "left") 
        hs.timer.usleep(50000)
        hs.eventtap.keyStroke({"shift"}, "left") 
        hs.eventtap.keyStroke({"shift"}, "left") 
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.keyStroke({}, "right") -- Deselect
        end)
      end,
      function()
        hs.eventtap.keyStroke({"cmd"}, "left") -- Move to beginning
        hs.timer.usleep(80000)
        hs.eventtap.keyStroke({"shift", "cmd"}, "right") -- Select to end
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.keyStroke({}, "right") -- Deselect
        end)
      end,
      function()
        -- Quick navigation that counts as activity
        hs.eventtap.keyStroke({"cmd"}, "up") -- Go to top
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.keyStroke({"cmd"}, "z") -- Undo navigation if it changed something
        end)
      end,
      function()
        -- Open/close sidebar (VS Code command palette)
        hs.eventtap.keyStroke({"cmd"}, "b") -- Toggle sidebar
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.keyStroke({"cmd"}, "b") -- Toggle back
        end)
      end,
    }
    operations[math.random(1, #operations)]()

  ------------------------------------------------
  -- OPTION 8: Rapid scroll burst (3%)
  ------------------------------------------------
  else
    -- More intensive scroll bursts
    local burstCount = math.random(4,8)
    local totalScroll = 0
    for i = 1, burstCount do
      hs.timer.doAfter(0.08 * i, function()
        local scrollAmount = math.random(-18,-8)
        totalScroll = totalScroll + scrollAmount
        hs.eventtap.scrollWheel({ 0, scrollAmount }, {}, "pixel")
      end)
    end
    
    -- Auto-revert: scroll back after burst
    if ENABLE_AUTO_REVERT then
      hs.timer.doAfter(AUTO_REVERT_DELAY + 0.8, function()
        hs.eventtap.scrollWheel({ 0, -totalScroll }, {}, "pixel")
      end)
    end
  end
end

--------------------------------------------------
-- SCHEDULER (NON-MECHANICAL)
--------------------------------------------------
local function scheduleNext()
  activityTimer = hs.timer.doAfter(math.random(MIN_INTERVAL, MAX_INTERVAL), function()
    simulateActivity()
    scheduleNext()
  end)
end

--------------------------------------------------
-- START / STOP
--------------------------------------------------
local function startAutomation()
  if activityTimer then return end
  scheduleNext()
  hs.alert.show("▶ Activity automation running", 1)
end

local function stopAutomation()
  if activityTimer then
    activityTimer:stop()
    activityTimer = nil
  end
end

--------------------------------------------------
-- USER INPUT DETECTION
--------------------------------------------------
local function onUserInput(event)
  local now = nowMs()
  local timeSinceLastSim = now - lastSimulationTime
  
  -- Only check grace period, don't block if already paused
  if timeSinceLastSim < SELF_EVENT_GRACE_MS then 
    return false -- Likely a simulated event, ignore
  end
  
  -- Real user input detected
  if not isPausedByUser then
    isPausedByUser = true
    stopAutomation()
    hs.alert.show("⏸ Paused - User active", 0.5)
  end

  -- Reset the resume timer
  if resumeTimer then resumeTimer:stop() end
  resumeTimer = hs.timer.doAfter(IDLE_SECONDS, function()
    isPausedByUser = false
    startAutomation()
    hs.alert.show("▶ Resumed automation", 0.5)
  end)
  
  return false
end

--------------------------------------------------
-- EVENT TAPS
--------------------------------------------------
local userEventTap = hs.eventtap.new(
  {
    hs.eventtap.event.types.mouseMoved,
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
    hs.eventtap.event.types.scrollWheel,
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.flagsChanged -- Detect modifier keys
  },
  function(event)
    onUserInput(event)
    return false -- Don't block the event
  end
)

userEventTap:start()

--------------------------------------------------
-- MANUAL TOGGLE (HOTKEY)
--------------------------------------------------
hs.hotkey.bind({"cmd","alt","ctrl"}, "S", function()
  if activityTimer then
    stopAutomation()
    hs.alert.show("⛔ Automation stopped")
  else
    startAutomation()
  end
end)

--------------------------------------------------
-- UNDO HOTKEY (Cmd+Shift+Z)
--------------------------------------------------
hs.hotkey.bind({"cmd","shift"}, "Z", function()
  undoLastAction()
end)

--------------------------------------------------
-- CLEAR HISTORY HOTKEY (Cmd+Alt+Shift+C)
--------------------------------------------------
hs.hotkey.bind({"cmd","alt","shift"}, "C", function()
  clearHistory()
end)

--------------------------------------------------
-- SHOW HISTORY HOTKEY (Cmd+Alt+Shift+H)
--------------------------------------------------
hs.hotkey.bind({"cmd","alt","shift"}, "H", function()
  if #actionHistory == 0 then
    hs.alert.show("📋 No actions in history", 1.5)
  else
    local historyText = "📋 Last " .. #actionHistory .. " actions:\n"
    for i, action in ipairs(actionHistory) do
      historyText = historyText .. i .. ". " .. action.type .. "\n"
      if i >= 5 then break end -- Show only first 5
    end
    hs.alert.show(historyText, 3)
  end
end)

--------------------------------------------------
-- AUTO START
--------------------------------------------------
startAutomation()
