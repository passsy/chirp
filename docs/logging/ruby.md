# Ruby Logging Libraries

A comprehensive guide to the most popular logging libraries for Ruby, with a focus on colorful console output.

## 1. Semantic Logger

**Gem:**
```bash
gem install semantic_logger
gem install amazing_print  # Optional, for colorized hash output
```
**GitHub Stars:** ~600+

Semantic Logger is a feature-rich logging framework and replacement for existing Ruby and Rails loggers.

### Key Features
- Colorized console output
- Structured logging (JSON, key-value)
- Multiple appenders (file, syslog, MongoDB, etc.)
- Automatic log rotation
- Performance logging

### Example
```ruby
require 'semantic_logger'

# Setup colorized console logging
SemanticLogger.add_appender(io: $stdout, formatter: :color)
SemanticLogger.default_level = :trace

logger = SemanticLogger['MyApp']

# Basic logging with colors
logger.trace 'Trace message'
logger.debug 'Debug message'
logger.info 'Info message'        # Green
logger.warn 'Warning message'     # Yellow
logger.error 'Error message'      # Red
logger.fatal 'Fatal message'      # Red background

# With structured data
logger.info 'User logged in', user: 'alice', ip: '192.168.1.1'

# With payload
logger.info message: 'Processing', user: 'alice', count: 42

# Timing
logger.measure_info 'Expensive operation' do
  sleep(0.1)
end

# With exception
begin
  raise 'Something went wrong!'
rescue => e
  logger.error 'Error occurred', e
end
```

### Rails Integration
```ruby
# Gemfile
gem 'rails_semantic_logger'

# config/application.rb
config.rails_semantic_logger.semantic = true
config.rails_semantic_logger.started = true
config.rails_semantic_logger.processing = true
config.rails_semantic_logger.rendered = true
```

---

## 2. Rainbow

**Gem:**
```bash
gem install rainbow
```
**GitHub Stars:** ~1k+

Rainbow adds colors to your strings using a clean chainable API.

### Key Features
- Simple chainable API
- 256 color and true color support
- Works with any output (including logging)
- Respects NO_COLOR environment variable

### Example
```ruby
require 'rainbow'

# Basic colors
puts Rainbow('Red text').red
puts Rainbow('Green text').green
puts Rainbow('Yellow text').yellow
puts Rainbow('Blue text').blue

# With styles
puts Rainbow('Bold red').red.bold
puts Rainbow('Italic blue').blue.italic
puts Rainbow('Underlined').underline

# Background colors
puts Rainbow('White on red').white.bg(:red)
puts Rainbow('Black on yellow').black.bg(:yellow)

# Custom logger
class ColorLogger
  def info(msg)
    puts "#{Rainbow('[INFO]').cyan} #{msg}"
  end

  def success(msg)
    puts "#{Rainbow('[SUCCESS]').green.bold} #{Rainbow('✔').green} #{msg}"
  end

  def warn(msg)
    puts "#{Rainbow('[WARN]').yellow} #{Rainbow('⚠').yellow} #{msg}"
  end

  def error(msg)
    puts "#{Rainbow('[ERROR]').red.bold} #{Rainbow('✖').red} #{msg}"
  end
end

logger = ColorLogger.new
logger.info 'Processing request...'
logger.success 'Operation completed!'
logger.warn 'High memory usage'
logger.error 'Connection failed!'
```

---

## 3. Colorize

**Gem:**
```bash
gem install colorize
```

Colorize extends String with color methods.

### Key Features
- Extends String class directly
- Simple to use
- Foreground and background colors
- Text modes (bold, italic, etc.)

### Example
```ruby
require 'colorize'

# Basic colors (extends String)
puts 'Red text'.red
puts 'Green text'.green
puts 'Yellow text'.yellow
puts 'Blue text'.blue
puts 'Magenta text'.magenta
puts 'Cyan text'.cyan

# With background
puts 'White on red'.white.on_red
puts 'Black on green'.black.on_green

# With modes
puts 'Bold text'.bold
puts 'Underlined'.underline
puts 'Bold red'.red.bold

# With Rails logger
Rails.logger.debug 'Debug message'.cyan
Rails.logger.info 'Info message'.green
Rails.logger.warn 'Warning message'.yellow
Rails.logger.error 'Error message'.red

# Custom log method
def log_info(msg)
  puts "[#{Time.now.strftime('%H:%M:%S')}] #{'INFO'.green}: #{msg}"
end

def log_error(msg)
  puts "[#{Time.now.strftime('%H:%M:%S')}] #{'ERROR'.red.bold}: #{msg}"
end
```

---

## 4. TTY::Logger

**Gem:**
```bash
gem install tty-logger
```

Part of the TTY toolkit, a beautiful console logger.

### Key Features
- Beautiful formatted output
- Multiple output levels
- Customizable formatting
- Structured data support
- Emoji support

### Example
```ruby
require 'tty-logger'

logger = TTY::Logger.new

# Basic logging with colors and icons
logger.debug 'Debug message'
logger.info 'Info message'
logger.success 'Success message'    # ✔ with green
logger.warn 'Warning message'       # ⚠ with yellow
logger.error 'Error message'        # ✖ with red
logger.fatal 'Fatal message'

# With structured data
logger.info 'Request completed', status: 200, path: '/api/users'

# With custom fields
logger.with(user: 'alice').info 'User action'

# Wait and complete pattern
logger.wait 'Processing...'
sleep(1)
logger.success 'Done!'

# Custom logger
custom = TTY::Logger.new do |config|
  config.level = :debug
  config.handlers = [
    [:console, {
      styles: {
        debug: { symbol: '🔍', label: 'DEBUG' },
        info: { symbol: 'ℹ️', label: 'INFO' },
        success: { symbol: '✅', label: 'SUCCESS' },
        warn: { symbol: '⚠️', label: 'WARN' },
        error: { symbol: '❌', label: 'ERROR' },
      }
    }]
  ]
end

custom.info 'Custom formatted message'
```

---

## 5. Logging (Ruby Logging Framework)

**Gem:**
```bash
gem install logging
```

A flexible logging library similar to Java's log4j.

### Key Features
- Multiple appenders
- Color support for console
- Pattern layouts
- Hierarchical loggers

### Example
```ruby
require 'logging'

# Setup colored console logging
Logging.color_scheme('bright',
  levels: {
    debug: :cyan,
    info: :green,
    warn: :yellow,
    error: :red,
    fatal: [:white, :on_red]
  },
  date: :blue,
  logger: :cyan,
  message: :white
)

Logging.appenders.stdout(
  'stdout',
  layout: Logging.layouts.pattern(
    pattern: '[%d] %-5l %c: %m\n',
    color_scheme: 'bright'
  )
)

logger = Logging.logger['MyApp']
logger.add_appenders('stdout')
logger.level = :debug

# Log with colors
logger.debug 'Debug message'
logger.info 'Info message'
logger.warn 'Warning message'
logger.error 'Error message'
logger.fatal 'Fatal message'
```

---

## 6. Awesome Print (for Data Logging)

**Gem:**
```bash
gem install awesome_print
```

Formats Ruby objects with colors for better readability.

### Key Features
- Colorful object inspection
- Supports hashes, arrays, and custom objects
- Configurable formatting
- Great for debugging

### Example
```ruby
require 'awesome_print'

# Colorful hash output
data = {
  user: 'alice',
  status: 'active',
  items: [1, 2, 3],
  metadata: { created_at: Time.now }
}

ap data  # Beautiful colorized output

# With Rails logger
Rails.logger.ap data, :info

# Configuration
AwesomePrint.defaults = {
  indent: 2,
  color: {
    hash: :cyan,
    array: :green,
    string: :yellowish,
    nilclass: :red,
    trueclass: :green,
    falseclass: :red
  }
}

# Use with logging
def log_data(label, data)
  puts Rainbow(label).cyan.bold
  ap data
end

log_data 'User Data:', { name: 'Alice', role: 'admin' }
```

---

## Quick Comparison

| Library | Colors | Structured | Features | Best For |
|---------|--------|------------|----------|----------|
| Semantic Logger | ⭐⭐⭐⭐⭐ | ✅ | Many appenders | Production |
| Rainbow | ⭐⭐⭐⭐⭐ | ❌ | Simple API | Any project |
| Colorize | ⭐⭐⭐⭐ | ❌ | Extends String | Quick use |
| TTY::Logger | ⭐⭐⭐⭐⭐ | ✅ | Beautiful | CLI tools |
| Awesome Print | ⭐⭐⭐⭐⭐ | ✅ | Data formatting | Debugging |

## Recommendation

**For Rails apps:** Use **Semantic Logger** with rails_semantic_logger gem - it provides comprehensive logging with colors.

**For CLI tools:** Use **TTY::Logger** - it has the most beautiful output with icons.

**For simple projects:** Use **Rainbow** - it's clean, well-maintained, and has a nice API.

## Sources

- [Semantic Logger Documentation](https://logger.rocketjob.io/)
- [Better Stack: Best Ruby Logging Libraries](https://betterstack.com/community/guides/logging/best-ruby-logging-libraries/)
- [Rainbow GitHub](https://github.com/sickill/rainbow)
- [TTY::Logger GitHub](https://github.com/piotrmurach/tty-logger)
- [Highlight.io: 5 Best Ruby Logging Libraries](https://www.highlight.io/blog/5-best-ruby-logging-libraries)
