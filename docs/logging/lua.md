# Lua Logging Libraries

A comprehensive guide to the most popular logging libraries for Lua, with a focus on colorful console output.

## 1. LuaLogging (with ansicolors)

**LuaRocks:**
```bash
luarocks install lualogging
luarocks install ansicolors
```

The standard logging library for Lua, based on log4j.

### Key Features
- Multiple appenders (console, file, socket, email)
- Log levels
- Pattern layouts
- Integration with ansicolors for colorful output

### Example with Colors
```lua
local logging = require("logging")
local ansicolors = require("ansicolors")

-- Create a custom colored console appender
local function coloredConsole(self, level, message)
    local colors = {
        [logging.TRACE] = "%{cyan}",
        [logging.DEBUG] = "%{blue}",
        [logging.INFO]  = "%{green}",
        [logging.WARN]  = "%{yellow}",
        [logging.ERROR] = "%{red}",
        [logging.FATAL] = "%{bright red}",
    }

    local color = colors[level] or ""
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local levelName = logging.tostring(level)

    local output = string.format(
        "%s[%s] [%s] %s%s",
        ansicolors(color),
        timestamp,
        levelName,
        message,
        ansicolors("%{reset}")
    )
    print(output)
    return true
end

-- Create logger
local logger = logging.new(coloredConsole)
logger:setLevel(logging.DEBUG)

-- Basic logging
logger:trace("Trace message")
logger:debug("Debug message")
logger:info("Info message")
logger:warn("Warning message")
logger:error("Error message")
logger:fatal("Fatal message")

-- With formatting
local user = "alice"
local count = 42
logger:info(string.format("User %s processed %d items", user, count))
```

### Console Appender
```lua
local logging = require("logging")
require("logging.console")

-- Create console logger
local logger = logging.console()
logger:setLevel(logging.DEBUG)

logger:debug("Debug message")
logger:info("Info message")
logger:warn("Warning message")
logger:error("Error message")
```

---

## 2. ansicolors.lua

**LuaRocks:**
```bash
luarocks install ansicolors
```

A simple library for terminal colors.

### Key Features
- Simple string template syntax
- Supports all ANSI colors
- Chainable styles

### Example
```lua
local colors = require("ansicolors")

-- Basic colors
print(colors("%{red}Red text"))
print(colors("%{green}Green text"))
print(colors("%{yellow}Yellow text"))
print(colors("%{blue}Blue text"))

-- Bright colors
print(colors("%{bright red}Bright red"))
print(colors("%{bright green}Bright green"))

-- Styles
print(colors("%{underline}Underlined text"))
print(colors("%{bold}Bold text"))

-- Combinations
print(colors("%{bright red underline}Bright red underlined"))

-- Background colors
print(colors("%{white redbg}White on red"))

-- Reset within string
print(colors("%{red}Red %{reset}Normal %{green}Green"))

-- Custom logger functions
local function info(msg)
    print(colors("%{blue}ℹ️ [INFO] " .. msg))
end

local function success(msg)
    print(colors("%{bright green}✅ [SUCCESS] " .. msg))
end

local function warn(msg)
    print(colors("%{yellow}⚠️ [WARN] " .. msg))
end

local function error(msg)
    print(colors("%{red}❌ [ERROR] " .. msg))
end

info("Processing request...")
success("Operation completed!")
warn("High memory usage")
error("Connection failed")
```

---

## 3. lua-log (Asynchronous Logger)

**GitHub:**
```bash
git clone https://github.com/moteus/lua-log
```

An asynchronous logging library with color support.

### Key Features
- Async logging
- Console color support
- Roll file appender
- Network appenders

### Example
```lua
local log = require("log").new(
    require("log.writer.console.color").new()
)

log.trace("Trace message")
log.debug("Debug message")
log.info("Info message")
log.warning("Warning message")
log.error("Error message")
log.fatal("Fatal message")

-- With formatting
log.info("User %s logged in", "alice")
log.error("Failed after %d retries", 3)
```

---

## 4. lualog

**GitHub:**
```bash
git clone https://github.com/Desvelao/lualog
```

A simple logger with color support.

### Key Features
- Simple API
- Custom styles
- Color combinations

### Example
```lua
local lualog = require("lualog")

-- Basic logging
lualog.info("Info message")
lualog.debug("Debug message")
lualog.warn("Warning message")
lualog.error("Error message")

-- Custom styles
lualog.info("Yellow text", "yellow")
lualog.info("Red on blue", "red.bgblue")

-- Paint method for colorized strings
local colored = lualog:paint("red", "This is red")
print(colored)
```

---

## 5. Custom Colorful Logger

Build your own colorful logger for Lua.

### Example
```lua
-- color_logger.lua

local ColorLogger = {}
ColorLogger.__index = ColorLogger

-- ANSI color codes
local COLORS = {
    reset = "\27[0m",
    -- Regular colors
    black = "\27[30m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    white = "\27[37m",
    -- Bright colors
    bright_red = "\27[91m",
    bright_green = "\27[92m",
    bright_yellow = "\27[93m",
    bright_blue = "\27[94m",
    -- Styles
    bold = "\27[1m",
    dim = "\27[2m",
    underline = "\27[4m",
    -- Backgrounds
    bg_red = "\27[41m",
    bg_green = "\27[42m",
    bg_yellow = "\27[43m",
}

local LEVELS = {
    TRACE = 0,
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5,
}

local LEVEL_CONFIG = {
    TRACE = { color = COLORS.dim, emoji = "🔍", name = "TRACE" },
    DEBUG = { color = COLORS.cyan, emoji = "🐛", name = "DEBUG" },
    INFO  = { color = COLORS.blue, emoji = "ℹ️", name = "INFO" },
    SUCCESS = { color = COLORS.bold .. COLORS.green, emoji = "✅", name = "SUCCESS" },
    WARN  = { color = COLORS.yellow, emoji = "⚠️", name = "WARN" },
    ERROR = { color = COLORS.red, emoji = "❌", name = "ERROR" },
    FATAL = { color = COLORS.bold .. COLORS.bg_red .. COLORS.white, emoji = "💀", name = "FATAL" },
}

function ColorLogger.new(name, level)
    local self = setmetatable({}, ColorLogger)
    self.name = name or "App"
    self.level = LEVELS[level] or LEVELS.DEBUG
    return self
end

function ColorLogger:setLevel(level)
    self.level = LEVELS[level] or LEVELS.DEBUG
end

function ColorLogger:_log(levelKey, message, ...)
    local config = LEVEL_CONFIG[levelKey]
    if not config then return end

    local levelNum = LEVELS[levelKey] or 0
    if levelNum < self.level then return end

    -- Format message if additional args provided
    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end

    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local output = string.format(
        "%s[%s] %s [%s] [%s] %s%s",
        config.color,
        timestamp,
        config.emoji,
        config.name,
        self.name,
        message,
        COLORS.reset
    )
    print(output)
end

-- Logging methods
function ColorLogger:trace(message, ...)
    self:_log("TRACE", message, ...)
end

function ColorLogger:debug(message, ...)
    self:_log("DEBUG", message, ...)
end

function ColorLogger:info(message, ...)
    self:_log("INFO", message, ...)
end

function ColorLogger:success(message, ...)
    self:_log("SUCCESS", message, ...)
end

function ColorLogger:warn(message, ...)
    self:_log("WARN", message, ...)
end

function ColorLogger:error(message, ...)
    self:_log("ERROR", message, ...)
end

function ColorLogger:fatal(message, ...)
    self:_log("FATAL", message, ...)
end

-- Box output
function ColorLogger:box(message)
    local len = #message
    local border = string.rep("═", len + 4)

    print(COLORS.green .. "╔" .. border .. "╗")
    print("║  " .. message .. "  ║")
    print("╚" .. border .. "╝" .. COLORS.reset)
end

-- Step logging
function ColorLogger:step(current, total, message)
    local output = string.format(
        "%s[STEP %d/%d] 📋 %s%s",
        COLORS.cyan,
        current,
        total,
        message,
        COLORS.reset
    )
    print(output)
end

return ColorLogger
```

### Usage
```lua
local ColorLogger = require("color_logger")

-- Create logger
local log = ColorLogger.new("MyApp")
log:setLevel("DEBUG")

-- Basic logging
log:trace("Trace message")
log:debug("Loading configuration...")
log:info("Server starting on port %d", 8080)
log:success("Database connected!")
log:warn("High memory usage: %dMB", 512)
log:error("Connection failed: %s", "timeout")
log:fatal("System crash!")

-- Step logging
log:step(1, 3, "Initializing...")
log:step(2, 3, "Processing...")
log:step(3, 3, "Finalizing...")

-- Box output
log:box("Application Ready!")
```

---

## 6. Simple ANSI Logger

A minimal logger using ANSI codes directly.

### Example
```lua
-- Simple colored logging

local function color(code)
    return string.format("\27[%sm", code)
end

local RESET = color(0)
local RED = color(31)
local GREEN = color(32)
local YELLOW = color(33)
local BLUE = color(34)
local CYAN = color(36)
local BOLD = color(1)

local function timestamp()
    return os.date("%H:%M:%S")
end

local function debug(msg)
    print(CYAN .. "[" .. timestamp() .. "] 🐛 [DEBUG] " .. msg .. RESET)
end

local function info(msg)
    print(BLUE .. "[" .. timestamp() .. "] ℹ️ [INFO] " .. msg .. RESET)
end

local function success(msg)
    print(GREEN .. BOLD .. "[" .. timestamp() .. "] ✅ [SUCCESS] " .. msg .. RESET)
end

local function warn(msg)
    print(YELLOW .. "[" .. timestamp() .. "] ⚠️ [WARN] " .. msg .. RESET)
end

local function err(msg)
    print(RED .. "[" .. timestamp() .. "] ❌ [ERROR] " .. msg .. RESET)
end

-- Usage
debug("Loading configuration...")
info("Processing items")
success("All items processed!")
warn("Some files skipped")
err("Failed to save results")
```

---

## Quick Comparison

| Library | Colors | Features | Best For |
|---------|--------|----------|----------|
| LuaLogging | ⭐⭐⭐⭐ | Full featured | Production |
| ansicolors | ⭐⭐⭐⭐⭐ | Simple API | Quick coloring |
| lua-log | ⭐⭐⭐⭐ | Async | High-load |
| Custom | ⭐⭐⭐⭐⭐ | Full control | Specific needs |

## Recommendation

**For general use:** Use **LuaLogging** with **ansicolors** - it's the standard and flexible.

**For simple coloring:** Use **ansicolors** directly - simple template syntax.

**For custom needs:** Build a **custom logger** using the templates above.

## Windows Note

ANSI colors may not work in Windows Command Prompt by default. Use:
- Windows Terminal (built-in support)
- PowerShell 7+
- Or enable ANSI support in legacy console

## Sources

- [LuaLogging Documentation](https://lunarmodules.github.io/lualogging/manual.html)
- [ansicolors GitHub](https://github.com/kikito/ansicolors.lua)
- [lua-log GitHub](https://github.com/moteus/lua-log)
- [lualog GitHub](https://github.com/Desvelao/lualog)
