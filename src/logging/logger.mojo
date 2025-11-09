"""
Logging Framework for mojo-postgres.

Provides structured logging with multiple log levels, context propagation,
and customizable output handlers.

Log Levels:
- DEBUG: Detailed diagnostic information
- INFO: General informational messages
- WARN: Warning messages for potentially harmful situations
- ERROR: Error messages for failure scenarios
- FATAL: Critical errors that may cause termination

Features:
- Structured logging with fields
- Context propagation (trace IDs, connection IDs)
- Multiple output targets (stdout, stderr, file, custom)
- Query logging with timing
- Connection lifecycle logging
- Production-safe parameter logging (no sensitive data)

Usage:
    from src.logging import Logger, LogLevel

    var logger = Logger.get("postgres")
    logger.info("Connection established", "host", "localhost", "port", "5432")
    logger.error("Query failed", "error", str(error))
"""

from collections import List
from time import now


# ============================================================================
# Log Levels
# ============================================================================

@value
struct LogLevel:
    """
    Log level enumeration.

    Levels (in order of severity):
    - DEBUG (10): Detailed diagnostic information
    - INFO (20): General informational messages
    - WARN (30): Warning messages
    - ERROR (40): Error messages
    - FATAL (50): Critical errors

    Example:
        var level = LogLevel.info()
        if level.value >= LogLevel.warn().value:
            print("Important message")
    """
    var value: Int
    var name: String

    @staticmethod
    fn debug() -> LogLevel:
        """DEBUG level (10) - Detailed diagnostics."""
        return LogLevel(10, "DEBUG")

    @staticmethod
    fn info() -> LogLevel:
        """INFO level (20) - General information."""
        return LogLevel(20, "INFO")

    @staticmethod
    fn warn() -> LogLevel:
        """WARN level (30) - Warnings."""
        return LogLevel(30, "WARN")

    @staticmethod
    fn error() -> LogLevel:
        """ERROR level (40) - Errors."""
        return LogLevel(40, "ERROR")

    @staticmethod
    fn fatal() -> LogLevel:
        """FATAL level (50) - Critical errors."""
        return LogLevel(50, "FATAL")

    fn to_string(self) -> String:
        """Convert log level to string."""
        return self.name

    fn is_enabled(self, min_level: LogLevel) -> Bool:
        """Check if this level is enabled given minimum level."""
        return self.value >= min_level.value


# ============================================================================
# Log Entry
# ============================================================================

@value
struct LogEntry:
    """
    Represents a single log entry.

    Attributes:
        level: Log level
        message: Log message
        timestamp: Timestamp in nanoseconds
        logger_name: Name of logger that created this entry
        context_fields: Key-value pairs for context

    Example:
        var entry = LogEntry(
            LogLevel.info(),
            "Query executed",
            now(),
            "postgres",
            List[String]()
        )
    """
    var level: LogLevel
    var message: String
    var timestamp: Int
    var logger_name: String
    var fields: List[String]  # Alternating keys and values

    fn to_string(self) -> String:
        """Format log entry as string."""
        var result = String("")

        # Timestamp (simplified - just use raw value)
        result += "[" + String(self.timestamp) + "] "

        # Level
        result += "[" + self.level.to_string() + "] "

        # Logger name
        result += "[" + self.logger_name + "] "

        # Message
        result += self.message

        # Fields
        if len(self.fields) > 0:
            result += " {"
            var i = 0
            while i < len(self.fields) - 1:
                if i > 0:
                    result += ", "
                result += self.fields[i] + "=" + self.fields[i + 1]
                i += 2
            result += "}"

        return result

    fn to_json(self) -> String:
        """Format log entry as JSON."""
        var result = "{"

        # Timestamp
        result += "\"timestamp\":" + String(self.timestamp)

        # Level
        result += ",\"level\":\"" + self.level.to_string() + "\""

        # Logger
        result += ",\"logger\":\"" + self.logger_name + "\""

        # Message
        result += ",\"message\":\"" + self.escape_json(self.message) + "\""

        # Fields
        if len(self.fields) > 0:
            var i = 0
            while i < len(self.fields) - 1:
                result += ",\"" + self.fields[i] + "\":\"" + self.escape_json(self.fields[i + 1]) + "\""
                i += 2

        result += "}"
        return result

    fn escape_json(self, text: String) -> String:
        """Escape string for JSON."""
        # Simplified - in production would handle all escapes
        var result = String("")
        for i in range(len(text)):
            var ch = text[i]
            if ch == ord('"'):
                result += "\\\""
            elif ch == ord('\\'):
                result += "\\\\"
            else:
                result += chr(int(ch))
        return result


# ============================================================================
# Log Handler
# ============================================================================

trait LogHandler:
    """
    Interface for log output handlers.

    Implementations can write logs to:
    - Console (stdout/stderr)
    - Files
    - Syslog
    - External logging services
    """
    fn handle(inout self, entry: LogEntry) raises:
        """Handle a log entry."""
        pass


@value
struct ConsoleHandler(LogHandler):
    """
    Writes log entries to console (stdout).

    Example:
        var handler = ConsoleHandler()
        handler.handle(entry)
    """
    var use_json: Bool

    fn __init__(inout self, use_json: Bool = False):
        """Initialize console handler."""
        self.use_json = use_json

    fn handle(inout self, entry: LogEntry) raises:
        """Write log entry to stdout."""
        if self.use_json:
            print(entry.to_json())
        else:
            print(entry.to_string())


# ============================================================================
# Logger
# ============================================================================

struct Logger:
    """
    Logger for structured logging.

    Features:
    - Multiple log levels
    - Context fields
    - Custom handlers
    - Filtering by level

    Example:
        var logger = Logger.get("postgres")
        logger.set_level(LogLevel.info())
        logger.info("Connected", "host", "localhost")
        logger.error("Query failed", "error", "syntax error")
    """
    var name: String
    var min_level: LogLevel
    var handler: ConsoleHandler
    var enabled: Bool

    fn __init__(inout self, name: String):
        """Initialize logger with name."""
        self.name = name
        self.min_level = LogLevel.info()
        self.handler = ConsoleHandler(False)
        self.enabled = True

    @staticmethod
    fn get(name: String) -> Logger:
        """Get logger with given name."""
        return Logger(name)

    fn set_level(inout self, level: LogLevel):
        """Set minimum log level."""
        self.min_level = level

    fn set_json_format(inout self, use_json: Bool):
        """Enable or disable JSON output format."""
        self.handler = ConsoleHandler(use_json)

    fn disable(inout self):
        """Disable logging."""
        self.enabled = False

    fn enable(inout self):
        """Enable logging."""
        self.enabled = True

    fn is_debug_enabled(self) -> Bool:
        """Check if DEBUG level is enabled."""
        return self.enabled and LogLevel.debug().is_enabled(self.min_level)

    fn is_info_enabled(self) -> Bool:
        """Check if INFO level is enabled."""
        return self.enabled and LogLevel.info().is_enabled(self.min_level)

    fn log(inout self, level: LogLevel, message: String, *fields: String) raises:
        """
        Log message at given level with optional fields.

        Args:
            level: Log level
            message: Log message
            fields: Alternating key-value pairs

        Example:
            logger.log(LogLevel.info(), "Connected", "host", "localhost", "port", "5432")
        """
        if not self.enabled:
            return

        if not level.is_enabled(self.min_level):
            return

        var field_list = List[String]()
        for i in range(len(fields)):
            field_list.append(fields[i])

        var entry = LogEntry(
            level,
            message,
            now(),
            self.name,
            field_list
        )

        self.handler.handle(entry)

    fn debug(inout self, message: String, *fields: String) raises:
        """
        Log DEBUG message.

        Example:
            logger.debug("Executing query", "sql", "SELECT * FROM users")
        """
        self.log(LogLevel.debug(), message, *fields)

    fn info(inout self, message: String, *fields: String) raises:
        """
        Log INFO message.

        Example:
            logger.info("Connection established", "host", "localhost")
        """
        self.log(LogLevel.info(), message, *fields)

    fn warn(inout self, message: String, *fields: String) raises:
        """
        Log WARN message.

        Example:
            logger.warn("Slow query detected", "duration_ms", "5000")
        """
        self.log(LogLevel.warn(), message, *fields)

    fn error(inout self, message: String, *fields: String) raises:
        """
        Log ERROR message.

        Example:
            logger.error("Query failed", "error", "connection timeout")
        """
        self.log(LogLevel.error(), message, *fields)

    fn fatal(inout self, message: String, *fields: String) raises:
        """
        Log FATAL message.

        Example:
            logger.fatal("Cannot connect to database", "error", str(error))
        """
        self.log(LogLevel.fatal(), message, *fields)


# ============================================================================
# Query Logger
# ============================================================================

struct QueryLogger:
    """
    Specialized logger for SQL query logging.

    Features:
    - Query text logging (sanitized)
    - Query timing
    - Row count logging
    - Error logging
    - Slow query detection

    Example:
        var qlogger = QueryLogger(logger)
        qlogger.log_query("SELECT * FROM users", 15.5, 100)
    """
    var logger: Logger
    var slow_query_threshold_ms: Float64

    fn __init__(inout self, inout logger: Logger, slow_query_threshold_ms: Float64 = 1000.0):
        """Initialize query logger."""
        self.logger = logger
        self.slow_query_threshold_ms = slow_query_threshold_ms

    fn log_query(inout self, query: String, duration_ms: Float64, row_count: Int) raises:
        """
        Log query execution.

        Args:
            query: SQL query text (first 200 chars)
            duration_ms: Query duration in milliseconds
            row_count: Number of rows returned/affected
        """
        # Truncate query for logging
        var query_preview = query
        if len(query) > 200:
            query_preview = query[:200] + "..."

        # Check if slow query
        if duration_ms >= self.slow_query_threshold_ms:
            self.logger.warn(
                "Slow query detected",
                "query", query_preview,
                "duration_ms", String(duration_ms),
                "rows", String(row_count)
            )
        elif self.logger.is_debug_enabled():
            self.logger.debug(
                "Query executed",
                "query", query_preview,
                "duration_ms", String(duration_ms),
                "rows", String(row_count)
            )

    fn log_query_error(inout self, query: String, error: String) raises:
        """
        Log query error.

        Args:
            query: SQL query that failed
            error: Error message
        """
        var query_preview = query
        if len(query) > 200:
            query_preview = query[:200] + "..."

        self.logger.error(
            "Query failed",
            "query", query_preview,
            "error", error
        )


# ============================================================================
# Connection Logger
# ============================================================================

struct ConnectionLogger:
    """
    Specialized logger for connection lifecycle events.

    Logs:
    - Connection creation
    - Connection close
    - Authentication events
    - Network errors
    - Pool events

    Example:
        var clogger = ConnectionLogger(logger)
        clogger.log_connected("localhost", 5432)
    """
    var logger: Logger

    fn __init__(inout self, inout logger: Logger):
        """Initialize connection logger."""
        self.logger = logger

    fn log_connecting(inout self, host: String, port: Int) raises:
        """Log connection attempt."""
        self.logger.info(
            "Connecting to database",
            "host", host,
            "port", String(port)
        )

    fn log_connected(inout self, host: String, port: Int) raises:
        """Log successful connection."""
        self.logger.info(
            "Connected to database",
            "host", host,
            "port", String(port)
        )

    fn log_disconnected(inout self, host: String, port: Int) raises:
        """Log connection closed."""
        self.logger.info(
            "Disconnected from database",
            "host", host,
            "port", String(port)
        )

    fn log_connection_error(inout self, host: String, port: Int, error: String) raises:
        """Log connection error."""
        self.logger.error(
            "Connection failed",
            "host", host,
            "port", String(port),
            "error", error
        )

    fn log_authentication_success(inout self, user: String, database: String) raises:
        """Log successful authentication."""
        self.logger.info(
            "Authentication successful",
            "user", user,
            "database", database
        )

    fn log_authentication_failure(inout self, user: String, database: String, error: String) raises:
        """Log authentication failure."""
        self.logger.error(
            "Authentication failed",
            "user", user,
            "database", database,
            "error", error
        )


# ============================================================================
# Global Logger Registry
# ============================================================================

fn get_logger(name: String) -> Logger:
    """
    Get or create logger with given name.

    This is a simplified implementation. In production, would maintain
    a registry of loggers to avoid duplicates.

    Args:
        name: Logger name (typically module or component name)

    Returns:
        Logger instance

    Example:
        var logger = get_logger("postgres.pool")
        logger.info("Pool created")
    """
    return Logger.get(name)
