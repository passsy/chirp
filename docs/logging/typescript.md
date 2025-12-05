# TypeScript Logging Libraries

A comprehensive guide to the most popular logging libraries for TypeScript, with a focus on colorful console output.

> Note: TypeScript shares the same ecosystem as JavaScript/Node.js. All JavaScript logging libraries work with TypeScript, often with built-in or community-provided type definitions.

## 1. Consola

**Install:**
```bash
npm install consola
```
**Types:** Built-in
**GitHub Stars:** ~5k+

An elegant console logger with TypeScript support.

### Key Features
- First-class TypeScript support
- Fancy colorful output by default
- Browser and Node.js support
- Spam prevention and throttling

### Example
```typescript
import { consola, createConsola } from 'consola';

// Basic logging with colors
consola.start('Starting the application...');
consola.info('Application info');
consola.success('Operation completed!');
consola.warn('Warning message');
consola.error('Error occurred');
consola.debug('Debug info');

// With tags
consola.withTag('api').info('Request received');
consola.withTag('db').success('Connected');

// Box output for important messages
consola.box('Important Notice!');

// Create custom instance
const logger = createConsola({
  level: 4, // debug level
  fancy: true,
  formatOptions: {
    columns: 80,
    colors: true,
    compact: false,
    date: true,
  },
});

logger.info('Custom logger message');

// Type-safe context
interface LogContext {
  userId: string;
  requestId: string;
}

const contextLogger = consola.withTag('request');
const ctx: LogContext = { userId: '123', requestId: 'abc' };
contextLogger.info('Processing', ctx);
```

---

## 2. Pino

**Install:**
```bash
npm install pino pino-pretty
npm install -D @types/pino
```
**GitHub Stars:** ~14k+

The fastest Node.js logger with TypeScript support.

### Key Features
- Extremely fast
- Type definitions included
- Pretty printing for development
- JSON output for production

### Example
```typescript
import pino, { Logger } from 'pino';

// Development logger with colors
const devLogger: Logger = pino({
  transport: {
    target: 'pino-pretty',
    options: {
      colorize: true,
      translateTime: 'SYS:standard',
      ignore: 'pid,hostname',
    },
  },
  level: 'debug',
});

devLogger.debug('Debug message');
devLogger.info('Info message');
devLogger.warn('Warning message');
devLogger.error('Error message');

// With typed context
interface RequestContext {
  userId: string;
  path: string;
  method: string;
}

const requestLogger = devLogger.child({ component: 'http' });
const ctx: RequestContext = {
  userId: '123',
  path: '/api/users',
  method: 'GET',
};

requestLogger.info(ctx, 'Request received');

// Production logger (JSON)
const prodLogger: Logger = pino({
  level: process.env.LOG_LEVEL || 'info',
});

prodLogger.info({ event: 'startup' }, 'Server started');
```

---

## 3. Winston

**Install:**
```bash
npm install winston
npm install -D @types/winston
```
**GitHub Stars:** ~22k+

The most popular logging library with TypeScript support.

### Example
```typescript
import winston, { Logger, format, transports } from 'winston';

const logger: Logger = winston.createLogger({
  level: 'debug',
  format: format.combine(
    format.colorize({ all: true }),
    format.timestamp({ format: 'HH:mm:ss' }),
    format.printf(({ timestamp, level, message, ...meta }) => {
      const metaStr = Object.keys(meta).length ? JSON.stringify(meta) : '';
      return `${timestamp} ${level}: ${message} ${metaStr}`;
    })
  ),
  transports: [new transports.Console()],
});

// Basic logging
logger.debug('Debug message');
logger.info('Info message');
logger.warn('Warning message');
logger.error('Error message');

// With metadata
interface UserMeta {
  userId: string;
  action: string;
}

const meta: UserMeta = { userId: '123', action: 'login' };
logger.info('User action', meta);

// Child logger
const childLogger = logger.child({ service: 'api' });
childLogger.info('API request');
```

---

## 4. tslog

**Install:**
```bash
npm install tslog
```
**Types:** Built-in
**GitHub Stars:** ~1k+

A TypeScript-first logging library with beautiful output.

### Key Features
- Built for TypeScript
- Pretty colorful output
- Source code location
- Structured logging

### Example
```typescript
import { Logger, ILogObj } from 'tslog';

// Create logger with colors
const log: Logger<ILogObj> = new Logger({
  name: 'MyApp',
  prettyLogTemplate: '{{yyyy}}.{{mm}}.{{dd}} {{hh}}:{{MM}}:{{ss}} {{logLevelName}} ',
  prettyLogTimeZone: 'local',
  stylePrettyLogs: true,
  prettyLogStyles: {
    logLevelName: {
      '*': ['bold', 'black', 'bgWhiteBright'],
      SILLY: ['bold', 'white'],
      TRACE: ['bold', 'whiteBright'],
      DEBUG: ['bold', 'green'],
      INFO: ['bold', 'blue'],
      WARN: ['bold', 'yellow'],
      ERROR: ['bold', 'red'],
      FATAL: ['bold', 'redBright'],
    },
  },
});

// Basic logging
log.silly('Silly message');
log.trace('Trace message');
log.debug('Debug message');
log.info('Info message');
log.warn('Warning message');
log.error('Error message');
log.fatal('Fatal message');

// With typed objects
interface User {
  id: string;
  name: string;
}

const user: User = { id: '123', name: 'Alice' };
log.info('User logged in', user);

// Child logger
const childLog = log.getSubLogger({ name: 'API' });
childLog.info('Request received');

// With error
try {
  throw new Error('Something went wrong!');
} catch (error) {
  log.error('Error occurred', error as Error);
}
```

---

## 5. Chalk + Custom Logger

**Install:**
```bash
npm install chalk
```
**Types:** Built-in (ESM)

Build a type-safe colorful logger with Chalk.

### Example
```typescript
import chalk from 'chalk';

type LogLevel = 'debug' | 'info' | 'success' | 'warn' | 'error';

interface LogOptions {
  timestamp?: boolean;
  prefix?: string;
}

class ColorLogger {
  private options: LogOptions;

  constructor(options: LogOptions = {}) {
    this.options = { timestamp: true, ...options };
  }

  private formatMessage(level: LogLevel, message: string): string {
    const timestamp = this.options.timestamp
      ? chalk.gray(`[${new Date().toISOString()}] `)
      : '';
    const prefix = this.options.prefix
      ? chalk.cyan(`[${this.options.prefix}] `)
      : '';

    const levelColors: Record<LogLevel, (s: string) => string> = {
      debug: chalk.gray,
      info: chalk.blue,
      success: chalk.green,
      warn: chalk.yellow,
      error: chalk.red,
    };

    const icons: Record<LogLevel, string> = {
      debug: '🔍',
      info: 'ℹ️',
      success: '✅',
      warn: '⚠️',
      error: '❌',
    };

    const levelStr = levelColors[level](`[${level.toUpperCase()}]`);
    return `${timestamp}${prefix}${icons[level]} ${levelStr} ${message}`;
  }

  debug(message: string): void {
    console.log(this.formatMessage('debug', message));
  }

  info(message: string): void {
    console.log(this.formatMessage('info', message));
  }

  success(message: string): void {
    console.log(this.formatMessage('success', message));
  }

  warn(message: string): void {
    console.warn(this.formatMessage('warn', message));
  }

  error(message: string, error?: Error): void {
    console.error(this.formatMessage('error', message));
    if (error) {
      console.error(chalk.red(error.stack));
    }
  }
}

// Usage
const logger = new ColorLogger({ prefix: 'MyApp' });

logger.debug('Loading configuration...');
logger.info('Server starting on port 3000');
logger.success('Database connected');
logger.warn('High memory usage');
logger.error('Connection failed');

try {
  throw new Error('Something went wrong!');
} catch (e) {
  logger.error('An error occurred', e as Error);
}
```

---

## 6. Signale

**Install:**
```bash
npm install signale
npm install -D @types/signale
```
**GitHub Stars:** ~9k+

A hackable console logger with beautiful output.

### Example
```typescript
import { Signale, SignaleOptions } from 'signale';

// Custom options
const options: SignaleOptions = {
  disabled: false,
  interactive: false,
  logLevel: 'info',
  scope: 'MyApp',
  types: {
    success: {
      badge: '✅',
      color: 'green',
      label: 'success',
    },
    error: {
      badge: '❌',
      color: 'red',
      label: 'error',
    },
    custom: {
      badge: '🚀',
      color: 'magenta',
      label: 'deploy',
    },
  },
};

const signale = new Signale(options);

// Built-in types
signale.success('Operation successful');
signale.error('Something went wrong');
signale.warn('Deprecation warning');
signale.await('Fetching data...');
signale.complete('Task finished');
signale.pending('Build in progress');
signale.note('Important note');
signale.start('Starting server');
signale.debug('Debug info');
signale.watch('Watching for changes');
signale.star('Starred item');

// Custom type
signale.custom('Deploying to production!');

// Scoped logger
const apiLogger = signale.scope('api');
apiLogger.info('Request received');
```

---

## Quick Comparison

| Library | Colors | TypeScript | Features | Best For |
|---------|--------|------------|----------|----------|
| Consola | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Built-in fancy | CLI tools |
| Pino | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Fastest | High-performance |
| Winston | ⭐⭐⭐⭐ | ⭐⭐⭐ | Most flexible | Enterprise |
| tslog | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | TS-first | TypeScript projects |
| Signale | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Many log types | Dev tools |
| Chalk | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Custom | DIY loggers |

## Recommendation

**For TypeScript projects:** Use **tslog** - it's built for TypeScript with beautiful default output.

**For CLI tools:** Use **Consola** - it has the best developer experience with fancy output.

**For production APIs:** Use **Pino** - it's the fastest with good TypeScript support.

**For maximum customization:** Use **Chalk** to build your own type-safe logger.

## Sources

- [Consola GitHub](https://github.com/unjs/consola)
- [Pino Documentation](https://getpino.io/)
- [tslog GitHub](https://github.com/fullstack-build/tslog)
- [Signale GitHub](https://github.com/klaudiosinani/signale)
- [Winston GitHub](https://github.com/winstonjs/winston)
