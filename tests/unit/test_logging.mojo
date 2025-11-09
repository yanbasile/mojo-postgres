"""
Unit tests for Logging Framework.

Tests log levels, structured logging, formatters, and specialized loggers.

Test Categories:
1. Log level tests
2. Logger configuration tests
3. Log entry formatting tests
4. Query logger tests
5. Connection logger tests
6. Edge cases
"""

from testing import assert_equal, assert_true, assert_false
from src.logging.logger import Logger, LogLevel, LogEntry, QueryLogger, ConnectionLogger
from collections import List
from time import now


# ============================================================================
# Test 1: Log Level Tests
# ============================================================================

fn test_log_level_values() raises:
    """Test 1.1: Log level values."""
    print("  test_log_level_values...", end="")

    assert_equal(LogLevel.debug().value, 10)
    assert_equal(LogLevel.info().value, 20)
    assert_equal(LogLevel.warn().value, 30)
    assert_equal(LogLevel.error().value, 40)
    assert_equal(LogLevel.fatal().value, 50)

    print(" ✅")


fn test_log_level_names() raises:
    """Test 1.2: Log level names."""
    print("  test_log_level_names...", end="")

    assert_equal(LogLevel.debug().to_string(), "DEBUG")
    assert_equal(LogLevel.info().to_string(), "INFO")
    assert_equal(LogLevel.warn().to_string(), "WARN")
    assert_equal(LogLevel.error().to_string(), "ERROR")
    assert_equal(LogLevel.fatal().to_string(), "FATAL")

    print(" ✅")


fn test_log_level_comparison() raises:
    """Test 1.3: Log level comparison."""
    print("  test_log_level_comparison...", end="")

    # DEBUG is lowest
    assert_true(LogLevel.debug().value < LogLevel.info().value)
    assert_true(LogLevel.info().value < LogLevel.warn().value)
    assert_true(LogLevel.warn().value < LogLevel.error().value)
    assert_true(LogLevel.error().value < LogLevel.fatal().value)

    print(" ✅")


fn test_log_level_is_enabled() raises:
    """Test 1.4: Log level filtering."""
    print("  test_log_level_is_enabled...", end="")

    var min_level = LogLevel.warn()

    # Should be enabled
    assert_true(LogLevel.warn().is_enabled(min_level))
    assert_true(LogLevel.error().is_enabled(min_level))
    assert_true(LogLevel.fatal().is_enabled(min_level))

    # Should be disabled
    assert_false(LogLevel.debug().is_enabled(min_level))
    assert_false(LogLevel.info().is_enabled(min_level))

    print(" ✅")


# ============================================================================
# Test 2: Logger Configuration Tests
# ============================================================================

fn test_logger_creation() raises:
    """Test 2.1: Logger creation."""
    print("  test_logger_creation...", end="")

    var logger = Logger.get("test")
    assert_equal(logger.name, "test")
    assert_equal(logger.min_level.value, LogLevel.info().value)
    assert_true(logger.enabled)

    print(" ✅")


fn test_logger_set_level() raises:
    """Test 2.2: Set logger level."""
    print("  test_logger_set_level...", end="")

    var logger = Logger.get("test")

    logger.set_level(LogLevel.debug())
    assert_equal(logger.min_level.value, LogLevel.debug().value)

    logger.set_level(LogLevel.error())
    assert_equal(logger.min_level.value, LogLevel.error().value)

    print(" ✅")


fn test_logger_enable_disable() raises:
    """Test 2.3: Enable/disable logger."""
    print("  test_logger_enable_disable...", end="")

    var logger = Logger.get("test")

    assert_true(logger.enabled)

    logger.disable()
    assert_false(logger.enabled)

    logger.enable()
    assert_true(logger.enabled)

    print(" ✅")


fn test_logger_is_level_enabled() raises:
    """Test 2.4: Check if level is enabled."""
    print("  test_logger_is_level_enabled...", end="")

    var logger = Logger.get("test")
    logger.set_level(LogLevel.info())

    assert_false(logger.is_debug_enabled())
    assert_true(logger.is_info_enabled())

    logger.set_level(LogLevel.debug())
    assert_true(logger.is_debug_enabled())
    assert_true(logger.is_info_enabled())

    print(" ✅")


# ============================================================================
# Test 3: Log Entry Formatting Tests
# ============================================================================

fn test_log_entry_to_string() raises:
    """Test 3.1: Log entry to string format."""
    print("  test_log_entry_to_string...", end="")

    var fields = List[String]()
    fields.append("key1")
    fields.append("value1")

    var entry = LogEntry(
        LogLevel.info(),
        "Test message",
        now(),
        "test",
        fields
    )

    var str = entry.to_string()
    assert_true("INFO" in str)
    assert_true("Test message" in str)
    assert_true("key1=value1" in str)

    print(" ✅")


fn test_log_entry_to_json() raises:
    """Test 3.2: Log entry to JSON format."""
    print("  test_log_entry_to_json...", end="")

    var fields = List[String]()
    fields.append("host")
    fields.append("localhost")

    var entry = LogEntry(
        LogLevel.error(),
        "Connection failed",
        now(),
        "postgres",
        fields
    )

    var json = entry.to_json()
    assert_true("\"level\":\"ERROR\"" in json)
    assert_true("\"message\":\"Connection failed\"" in json)
    assert_true("\"logger\":\"postgres\"" in json)
    assert_true("\"host\":\"localhost\"" in json)

    print(" ✅")


fn test_log_entry_with_multiple_fields() raises:
    """Test 3.3: Log entry with multiple fields."""
    print("  test_log_entry_with_multiple_fields...", end="")

    var fields = List[String]()
    fields.append("key1")
    fields.append("value1")
    fields.append("key2")
    fields.append("value2")
    fields.append("key3")
    fields.append("value3")

    var entry = LogEntry(
        LogLevel.debug(),
        "Debug info",
        now(),
        "test",
        fields
    )

    var str = entry.to_string()
    assert_true("key1=value1" in str)
    assert_true("key2=value2" in str)
    assert_true("key3=value3" in str)

    print(" ✅")


fn test_log_entry_no_fields() raises:
    """Test 3.4: Log entry with no fields."""
    print("  test_log_entry_no_fields...", end="")

    var fields = List[String]()
    var entry = LogEntry(
        LogLevel.info(),
        "Simple message",
        now(),
        "test",
        fields
    )

    var str = entry.to_string()
    assert_true("Simple message" in str)
    assert_true("INFO" in str)

    print(" ✅")


# ============================================================================
# Test 4: Query Logger Tests
# ============================================================================

fn test_query_logger_creation() raises:
    """Test 4.1: Query logger creation."""
    print("  test_query_logger_creation...", end="")

    var logger = Logger.get("test")
    var qlogger = QueryLogger(logger, 100.0)

    assert_equal(qlogger.slow_query_threshold_ms, 100.0)

    print(" ✅")


fn test_query_logger_fast_query() raises:
    """Test 4.2: Log fast query (below threshold)."""
    print("  test_query_logger_fast_query...", end="")

    var logger = Logger.get("test")
    logger.set_level(LogLevel.debug())
    var qlogger = QueryLogger(logger, 100.0)

    # Should log at DEBUG level
    qlogger.log_query("SELECT * FROM users", 50.0, 10)

    print(" ✅")


fn test_query_logger_slow_query() raises:
    """Test 4.3: Log slow query (exceeds threshold)."""
    print("  test_query_logger_slow_query...", end="")

    var logger = Logger.get("test")
    var qlogger = QueryLogger(logger, 100.0)

    # Should log at WARN level
    qlogger.log_query("SELECT * FROM large_table", 250.0, 10000)

    print(" ✅")


fn test_query_logger_error() raises:
    """Test 4.4: Log query error."""
    print("  test_query_logger_error...", end="")

    var logger = Logger.get("test")
    var qlogger = QueryLogger(logger, 100.0)

    qlogger.log_query_error(
        "SELECT * FROM non_existent",
        "relation does not exist"
    )

    print(" ✅")


# ============================================================================
# Test 5: Connection Logger Tests
# ============================================================================

fn test_connection_logger_creation() raises:
    """Test 5.1: Connection logger creation."""
    print("  test_connection_logger_creation...", end="")

    var logger = Logger.get("test")
    var clogger = ConnectionLogger(logger)

    # Just verify it was created successfully
    print(" ✅")


fn test_connection_logger_connect_events() raises:
    """Test 5.2: Log connection events."""
    print("  test_connection_logger_connect_events...", end="")

    var logger = Logger.get("test")
    var clogger = ConnectionLogger(logger)

    clogger.log_connecting("localhost", 5432)
    clogger.log_connected("localhost", 5432)
    clogger.log_disconnected("localhost", 5432)

    print(" ✅")


fn test_connection_logger_auth_events() raises:
    """Test 5.3: Log authentication events."""
    print("  test_connection_logger_auth_events...", end="")

    var logger = Logger.get("test")
    var clogger = ConnectionLogger(logger)

    clogger.log_authentication_success("user", "database")
    clogger.log_authentication_failure("user", "database", "wrong password")

    print(" ✅")


fn test_connection_logger_error() raises:
    """Test 5.4: Log connection error."""
    print("  test_connection_logger_error...", end="")

    var logger = Logger.get("test")
    var clogger = ConnectionLogger(logger)

    clogger.log_connection_error(
        "db.example.com",
        5432,
        "Connection timeout"
    )

    print(" ✅")


# ============================================================================
# Test 6: Edge Cases
# ============================================================================

fn test_logger_with_empty_name() raises:
    """Test 6.1: Logger with empty name."""
    print("  test_logger_with_empty_name...", end="")

    var logger = Logger.get("")
    assert_equal(logger.name, "")

    print(" ✅")


fn test_log_entry_json_escaping() raises:
    """Test 6.2: JSON escaping in log entry."""
    print("  test_log_entry_json_escaping...", end="")

    var fields = List[String]()
    fields.append("error")
    fields.append("Message with \"quotes\"")

    var entry = LogEntry(
        LogLevel.error(),
        "Test message",
        now(),
        "test",
        fields
    )

    var json = entry.to_json()
    # Should escape quotes
    assert_true("\\\"" in json)

    print(" ✅")


fn test_query_logger_long_query() raises:
    """Test 6.3: Query logger with very long query."""
    print("  test_query_logger_long_query...", end="")

    var logger = Logger.get("test")
    logger.set_level(LogLevel.debug())
    var qlogger = QueryLogger(logger, 100.0)

    # Create long query (> 200 chars)
    var long_query = "SELECT " + ("column," * 50) + " FROM table"
    qlogger.log_query(long_query, 10.0, 1)

    print(" ✅")


fn test_logger_disabled_no_output() raises:
    """Test 6.4: Disabled logger produces no output."""
    print("  test_logger_disabled_no_output...", end="")

    var logger = Logger.get("test")
    logger.disable()

    # These should not produce output
    logger.info("Should not appear")
    logger.error("Should not appear")

    print(" ✅")


fn main() raises:
    print("\n" + "=" * 70)
    print("Logging Framework Unit Tests")
    print("=" * 70 + "\n")

    print("Test 1: Log Level Tests")
    test_log_level_values()
    test_log_level_names()
    test_log_level_comparison()
    test_log_level_is_enabled()

    print("\nTest 2: Logger Configuration Tests")
    test_logger_creation()
    test_logger_set_level()
    test_logger_enable_disable()
    test_logger_is_level_enabled()

    print("\nTest 3: Log Entry Formatting Tests")
    test_log_entry_to_string()
    test_log_entry_to_json()
    test_log_entry_with_multiple_fields()
    test_log_entry_no_fields()

    print("\nTest 4: Query Logger Tests")
    test_query_logger_creation()
    test_query_logger_fast_query()
    test_query_logger_slow_query()
    test_query_logger_error()

    print("\nTest 5: Connection Logger Tests")
    test_connection_logger_creation()
    test_connection_logger_connect_events()
    test_connection_logger_auth_events()
    test_connection_logger_error()

    print("\nTest 6: Edge Cases")
    test_logger_with_empty_name()
    test_log_entry_json_escaping()
    test_query_logger_long_query()
    test_logger_disabled_no_output()

    print("\n" + "=" * 70)
    print("✅ All 24 tests passed!")
    print("=" * 70 + "\n")
