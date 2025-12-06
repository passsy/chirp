# JavaScript/Node.js Logging Libraries

A comprehensive guide to the most popular logging libraries for JavaScript and Node.js, with a focus on colorful and fancy console output.

## 1. Consola

**Package:** `consola`
**GitHub Stars:** ~5k+
**Install:** `npm install consola`

Consola is an elegant console logger for Node.js and browsers with fancy colored output.

### Key Features
- Fancy colored output with fallback for minimal environments
- Browser support
- Pluggable reporters
- Tag support
- Spam prevention by throttling logs
- Interactive prompt support powered by clack

### Example
```javascript
import { consola, createConsola } from "consola";

// Basic usage
consola.info("Using consola 3.0.0");
consola.start("Building project...");
consola.warn("A warning message");
consola.success("Project built!");
consola.error(new Error("Something went wrong"));

// With tags
consola.withTag("nuxt").info("This is Nuxt");

// Box output
consola.box("Fancy Box Output!");

// Create custom instance
const logger = createConsola({
  level: 4, // debug level
  fancy: true,
});
```

---

## 2. Winston

**Package:** `winston`
**GitHub Stars:** ~22k
**Weekly Downloads:** 12M+
**Install:** `npm install winston`

Winston is the most popular logging library for Node.js, highly configurable with multiple transports.

### Key Features
- Multiple transports (console, file, database, cloud services)
- Custom log levels
- Colorized output with `colorize` formatter
- JSON and simple formatting
- Log level filtering

### Example
```javascript
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.colorize({ all: true }),
    winston.format.timestamp(),
    winston.format.printf(({ timestamp, level, message }) => {
      return `${timestamp} ${level}: ${message}`;
    })
  ),
  transports: [
    new winston.transports.Console(),
  ],
});

logger.info('This is an info message');    // Green
logger.warn('This is a warning');           // Yellow
logger.error('This is an error');           // Red
logger.debug('Debug message');              // Blue
```

---

## 3. Pino

**Package:** `pino` + `pino-pretty`
**GitHub Stars:** ~14k
**Install:** `npm install pino pino-pretty`

Pino is the fastest Node.js logging library, 5-10x faster than alternatives.

### Key Features
- Extremely fast (minimal CPU overhead)
- JSON output by default (great for production)
- `pino-pretty` for colorful development output
- Async operations for better performance

### Example
```javascript
const pino = require('pino');

// Development with pretty printing and colors
const logger = pino({
  transport: {
    target: 'pino-pretty',
    options: {
      colorize: true,
      translateTime: 'SYS:standard',
      ignore: 'pid,hostname',
    },
  },
});

logger.info('Server starting...');
logger.debug({ port: 3000 }, 'Configuration loaded');
logger.warn('Deprecated API used');
logger.error({ err: new Error('Failed') }, 'Request failed');

// Production (JSON output)
const prodLogger = pino();
prodLogger.info({ event: 'startup' }, 'Application started');
```

---

## 4. Chalk + Custom Logger

**Package:** `chalk`
**GitHub Stars:** ~21k
**Install:** `npm install chalk`

Chalk is not a logger but a terminal styling library. Perfect for building custom colorful loggers.

### Key Features
- 256 colors and truecolor support
- Chainable API
- Template literal support
- Auto-detects color support

### Example
```javascript
import chalk from 'chalk';

const log = {
  info: (msg) => console.log(chalk.blue('ℹ'), chalk.blue(msg)),
  success: (msg) => console.log(chalk.green('✔'), chalk.green(msg)),
  warn: (msg) => console.log(chalk.yellow('⚠'), chalk.yellow(msg)),
  error: (msg) => console.log(chalk.red('✖'), chalk.red.bold(msg)),
  debug: (msg) => console.log(chalk.gray('🔍'), chalk.gray(msg)),
};

log.info('Processing request...');
log.success('Operation completed!');
log.warn('Resource usage high');
log.error('Connection failed!');

// Advanced styling
console.log(chalk.bgRed.white.bold(' ERROR ') + ' ' + chalk.red('Critical failure'));
console.log(chalk.hex('#FF8800')('Custom orange color'));
console.log(chalk.rgb(123, 45, 67)('RGB color'));
```

---

## 5. Signale

**Package:** `signale`
**GitHub Stars:** ~9k
**Install:** `npm install signale`

Signale is a hackable console logger with beautiful output and custom log types.

### Key Features
- 19 built-in loggers (success, error, warn, await, complete, etc.)
- Customizable log types with emojis and colors
- Scoped loggers
- Timers and secrets filtering

### Example
```javascript
const { Signale } = require('signale');

const signale = new Signale();

signale.success('Operation successful');      // ✔ success
signale.error('Something went wrong');        // ✖ error
signale.warn('Deprecation warning');          // ⚠ warning
signale.await('Fetching data...');            // … await
signale.complete('Task finished');            // ☒ complete
signale.pending('Build in progress');         // ◯ pending
signale.note('Important note');               // ● note
signale.start('Starting server');             // ▶ start
signale.pause('Paused');                      // ‖ pause
signale.debug('Debug info');                  // ● debug
signale.watch('Watching for changes');        // ● watch
signale.star('Starred item');                 // ★ star

// Custom logger
const custom = new Signale({
  types: {
    rocket: {
      badge: '🚀',
      color: 'magenta',
      label: 'deploy',
    },
  },
});

custom.rocket('Deploying to production!');
```

---

## 6. node-color-log

**Package:** `node-color-log`
**Install:** `npm install node-color-log`

A lightweight logger with colorful fonts and backgrounds.

### Key Features
- Simple API
- Colored fonts and backgrounds
- 4 log levels (debug, info, warn, error)
- Method chaining

### Example
```javascript
const logger = require('node-color-log');

// Basic colored logs
logger.color('red').log('Red text');
logger.color('green').bgColor('yellow').log('Green on yellow');
logger.fontColorLog('blue', 'Blue text message');

// Log levels with colors
logger.debug('Debug message');        // Cyan
logger.info('Info message');          // Green
logger.warn('Warning message');       // Yellow
logger.error('Error message');        // Red

// Bold and styling
logger.color('red').bold().log('Bold red text');
logger.color('blue').italic().underscore().log('Styled text');

// With timestamp
logger.setDate(() => new Date().toISOString());
logger.info('Message with timestamp');
```

---

## 7. Debug

**Package:** `debug`
**GitHub Stars:** ~11k
**Install:** `npm install debug`

A tiny debugging utility modeled after Node.js core's debugging technique.

### Key Features
- Namespace-based logging
- Environment variable control
- Auto-assigned colors per namespace
- Zero overhead when disabled

### Example
```javascript
const debug = require('debug');

const log = debug('app:main');
const dbLog = debug('app:database');
const httpLog = debug('app:http');

// Each namespace gets its own color automatically
log('Application starting...');
dbLog('Connected to database');
httpLog('Request received: GET /api/users');

// Enable with: DEBUG=app:* node app.js
// Or specific: DEBUG=app:database node app.js
```

---

## Quick Comparison

| Library | Speed | Fancy Output | JSON Support | Best For |
|---------|-------|--------------|--------------|----------|
| Consola | Medium | ⭐⭐⭐⭐⭐ | ✅ | CLI tools, Nuxt |
| Winston | Medium | ⭐⭐⭐ | ✅ | Enterprise apps |
| Pino | Fast | ⭐⭐⭐⭐ | ✅ | High-performance APIs |
| Signale | Medium | ⭐⭐⭐⭐⭐ | ❌ | CLI tools, dev |
| Chalk | N/A | ⭐⭐⭐⭐⭐ | N/A | Custom loggers |
| Debug | Fast | ⭐⭐⭐ | ❌ | Development |

## Sources

- [Better Stack: Best Node.js Logging Libraries](https://betterstack.com/community/guides/logging/best-nodejs-logging-libraries/)
- [Consola GitHub](https://github.com/unjs/consola)
- [Pino vs Winston Comparison](https://betterstack.com/community/comparisons/pino-vs-winston/)
- [Dash0: Top 5 Node.js Logging Frameworks 2025](https://www.dash0.com/faq/the-top-5-best-node-js-and-javascript-logging-frameworks-in-2025-a-complete-guide)
