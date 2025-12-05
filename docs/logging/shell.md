# Shell/Bash Logging Libraries

A comprehensive guide to logging utilities and patterns for Shell and Bash scripting, with a focus on colorful console output.

## 1. color-logger-bash

**Install:**
```bash
# Clone the repository
git clone https://github.com/swyckoff/color-logger-bash.git

# Or just source the script directly
curl -O https://raw.githubusercontent.com/swyckoff/color-logger-bash/master/color-logger.sh
```

A simple library for colorful logging in bash scripts.

### Example
```bash
#!/bin/bash
source color-logger.sh

# Logging functions
log_info "Info message"
log_success "Success message"
log_warning "Warning message"
log_error "Error message"
log_debug "Debug message"
```

---

## 2. colors.sh (Lightweight Colors)

A lightweight approach using a simple color library.

### Example
```bash
#!/bin/bash

# colors.sh content (source or include in script)
# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Usage
echo -e "${RED}Red text${NC}"
echo -e "${GREEN}Green text${NC}"
echo -e "${YELLOW}Yellow text${NC}"
echo -e "${BLUE}Blue text${NC}"

# With bold
echo -e "${BOLD}${RED}Bold red${NC}"
```

---

## 3. Custom Colorful Logger

Create your own comprehensive logging library.

### Full Implementation (logger.sh)
```bash
#!/bin/bash
#
# Colorful Logger for Bash Scripts
#

# Color codes
readonly RESET='\033[0m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[0;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly BG_RED='\033[41m'
readonly BG_GREEN='\033[42m'

# Log level (can be set via environment variable)
LOG_LEVEL=${LOG_LEVEL:-"DEBUG"}

# Log levels
declare -A LOG_LEVELS=(
    ["TRACE"]=0
    ["DEBUG"]=1
    ["INFO"]=2
    ["WARN"]=3
    ["ERROR"]=4
    ["FATAL"]=5
)

# Check if log level is enabled
_should_log() {
    local level=$1
    [[ ${LOG_LEVELS[$level]} -ge ${LOG_LEVELS[$LOG_LEVEL]} ]]
}

# Get timestamp
_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Core log function
_log() {
    local color=$1
    local level=$2
    local emoji=$3
    local message=$4

    if _should_log "$level"; then
        echo -e "${color}[$(_timestamp)] ${emoji} [${level}] ${message}${RESET}"
    fi
}

# Logging functions
log_trace() { _log "$DIM" "TRACE" "🔍" "$1"; }
log_debug() { _log "$CYAN" "DEBUG" "🐛" "$1"; }
log_info() { _log "$BLUE" "INFO" "ℹ️" "$1"; }
log_success() { _log "${BOLD}${GREEN}" "SUCCESS" "✅" "$1"; }
log_warn() { _log "$YELLOW" "WARN" "⚠️" "$1"; }
log_error() { _log "$RED" "ERROR" "❌" "$1"; }
log_fatal() { _log "${BOLD}${BG_RED}${WHITE}" "FATAL" "💀" "$1"; }

# Convenience aliases
info() { log_info "$1"; }
warn() { log_warn "$1"; }
error() { log_error "$1"; }
debug() { log_debug "$1"; }
success() { log_success "$1"; }

# Step logging (for multi-step processes)
log_step() {
    local step=$1
    local total=$2
    local message=$3
    echo -e "${CYAN}[$(_timestamp)] 📋 [STEP ${step}/${total}] ${message}${RESET}"
}

# Header/section logging
log_header() {
    local message=$1
    echo -e "\n${BOLD}${MAGENTA}═══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${MAGENTA}  $message${RESET}"
    echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════${RESET}\n"
}

# Box logging
log_box() {
    local message=$1
    local len=${#message}
    local border=$(printf '═%.0s' $(seq 1 $((len + 4))))

    echo -e "${GREEN}╔${border}╗${RESET}"
    echo -e "${GREEN}║  ${message}  ║${RESET}"
    echo -e "${GREEN}╚${border}╝${RESET}"
}

# Usage example
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_header "Logger Demo"

    log_trace "Trace message"
    log_debug "Debug message"
    log_info "Info message"
    log_success "Success message"
    log_warn "Warning message"
    log_error "Error message"
    log_fatal "Fatal message"

    echo ""
    log_step 1 3 "Initializing..."
    log_step 2 3 "Processing..."
    log_step 3 3 "Finalizing..."

    echo ""
    log_box "Operation Complete!"
fi
```

### Usage
```bash
#!/bin/bash
source logger.sh

# Set log level (optional)
export LOG_LEVEL="DEBUG"

log_header "My Script"

log_info "Starting application..."
log_debug "Loading configuration from /etc/myapp.conf"
log_success "Configuration loaded"
log_warn "Using default values for missing fields"

log_step 1 3 "Connecting to database..."
sleep 1
log_success "Connected"

log_step 2 3 "Running migrations..."
sleep 1
log_success "Migrations complete"

log_step 3 3 "Starting server..."
sleep 1
log_success "Server running on port 8080"

log_box "Application Ready!"
```

---

## 4. Gum (Glamorous Shell Scripts)

**Install:**
```bash
# macOS
brew install gum

# Linux
go install github.com/charmbracelet/gum@latest
```

A tool for glamorous shell scripts from Charm.sh.

### Example
```bash
#!/bin/bash

# Styled output
gum style --foreground 212 "Hello, World!"
gum style --foreground "#FF0000" --bold "Error message"

# Log-like output
gum log --level info "Info message"
gum log --level warn "Warning message"
gum log --level error "Error message"
gum log --level debug "Debug message"

# Spinners for long operations
gum spin --spinner dot --title "Installing..." -- sleep 3

# Confirm dialogs
gum confirm "Are you sure?" && echo "Confirmed!"

# Choose from options
gum choose "Option 1" "Option 2" "Option 3"

# Input
NAME=$(gum input --placeholder "Enter your name")
echo "Hello, $NAME!"

# Format output
gum format -- "# Header" "Some **bold** and *italic* text"
```

---

## 5. Bright Library

**Install:**
```bash
# Clone or download
git clone https://github.com/username/bright.git
source bright.sh
```

A lightweight collection of bash functions for console styling.

### Example
```bash
#!/bin/bash
source bright.sh

# Use bright functions
bright_red "Red text"
bright_green "Green text"
bright_yellow "Yellow text"
bright_blue "Blue text"

# Logging functions
bright_info "Info message"
bright_warn "Warning message"
bright_error "Error message"
bright_success "Success message"
```

---

## 6. Simple Inline Colors

No external dependencies, just use ANSI codes directly.

### Example
```bash
#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Simple logging functions
info() { echo -e "${BLUE}ℹ️ [INFO]${NC} $1"; }
success() { echo -e "${GREEN}✅ [SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️ [WARN]${NC} $1"; }
error() { echo -e "${RED}❌ [ERROR]${NC} $1"; }
debug() { echo -e "${CYAN}🔍 [DEBUG]${NC} $1"; }

# Usage
info "Processing files..."
success "All files processed"
warn "Some files were skipped"
error "Failed to process file.txt"
debug "Current directory: $(pwd)"
```

---

## 7. colout (External Tool)

**Install:**
```bash
pip install colout
```

A flexible tool for colorizing output.

### Example
```bash
# Colorize log levels
tail -f /var/log/syslog | colout '(ERROR)' red | colout '(WARN)' yellow | colout '(INFO)' green

# With your script
./my_script.sh 2>&1 | colout '\[ERROR\]' red | colout '\[WARN\]' yellow | colout '\[INFO\]' green
```

---

## 8. NO_COLOR Support

Respect the `NO_COLOR` environment variable standard.

### Example
```bash
#!/bin/bash

# Check for color support
supports_color() {
    [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]
}

if supports_color; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Usage - respects NO_COLOR=1
info "This respects NO_COLOR"
```

---

## Quick Comparison

| Tool | Type | Features | Best For |
|------|------|----------|----------|
| Custom Logger | Script | Full control | Any project |
| Gum | Binary | Rich UI | Interactive scripts |
| colout | Binary | Pipe colorizing | Log viewing |
| ANSI Codes | Built-in | Simple | Quick scripts |

## Recommendation

**For most scripts:** Create a **custom logger** using the template above - it gives you full control.

**For interactive scripts:** Use **Gum** - it provides beautiful prompts and spinners.

**For simple needs:** Just use **inline ANSI codes** - no dependencies needed.

## Tips

1. Always reset colors with `\033[0m` at the end
2. Use `-e` flag with `echo` to interpret escape sequences
3. Check if output is a terminal before using colors
4. Respect the `NO_COLOR` environment variable
5. Test in different terminals for compatibility

## Sources

- [color-logger-bash GitHub](https://github.com/swyckoff/color-logger-bash)
- [Gum by Charm](https://github.com/charmbracelet/gum)
- [ANSI Escape Codes](https://misc.flogisoft.com/bash/tip_colors_and_formatting)
- [NO_COLOR Standard](https://no-color.org/)
- [Stack Overflow: Colored Shell Script Output](https://stackoverflow.com/questions/16843382/colored-shell-script-output-library)
