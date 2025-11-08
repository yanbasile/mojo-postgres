"""
Logging Framework Examples.

Demonstrates structured logging for mojo-postgres applications.

Features:
- Multiple log levels (DEBUG, INFO, WARN, ERROR, FATAL)
- Structured fields (key-value pairs)
- JSON output format
- Query logging with timing
- Connection lifecycle logging
- Production-safe logging

Examples:
1. Basic logging with different levels
2. Structured logging with fields
3. JSON output format
4. Query logging
5. Connection logging
6. Log level filtering
7. Production logging patterns

Prerequisites:
- None (logging is standalone)
"""

from src.logging.logger import Logger, LogLevel, QueryLogger, ConnectionLogger, get_logger


fn example1_basic_logging() raises:
    """Example 1: Basic logging with different levels."""
    print("=" * 70)
    print("Example 1: Basic Logging")
    print("=" * 70)

    var logger = Logger.get("example")

    print("\n📝 Logging at different levels:\n")

    # DEBUG - Detailed diagnostics
    logger.debug("This is a debug message")

    # INFO - General information
    logger.info("This is an info message")

    # WARN - Warnings
    logger.warn("This is a warning message")

    # ERROR - Errors
    logger.error("This is an error message")

    # FATAL - Critical errors
    logger.fatal("This is a fatal message")

    print("\n✅ Example 1 complete!\n")


fn example2_structured_logging() raises:
    """Example 2: Structured logging with fields."""
    print("=" * 70)
    print("Example 2: Structured Logging")
    print("=" * 70)

    var logger = Logger.get("app")

    print("\n📊 Logging with context fields:\n")

    # Connection information
    logger.info(
        "Database connection established",
        "host", "localhost",
        "port", "5432",
        "database", "myapp"
    )

    # User action
    logger.info(
        "User logged in",
        "user_id", "12345",
        "username", "alice",
        "ip_address", "192.168.1.100"
    )

    # Query execution
    logger.debug(
        "Query executed",
        "query", "SELECT * FROM users WHERE id = $1",
        "duration_ms", "15.5",
        "rows", "1"
    )

    # Error with context
    logger.error(
        "Payment processing failed",
        "order_id", "ORD-789",
        "amount", "99.99",
        "error", "Card declined"
    )

    print("\n✅ Example 2 complete!\n")


fn example3_json_output() raises:
    """Example 3: JSON output format."""
    print("=" * 70)
    print("Example 3: JSON Output Format")
    print("=" * 70)

    var logger = Logger.get("api")
    logger.set_json_format(True)

    print("\n🔧 Logging in JSON format:\n")

    logger.info(
        "API request received",
        "method", "POST",
        "path", "/api/users",
        "status", "200"
    )

    logger.error(
        "Database connection failed",
        "host", "db.example.com",
        "port", "5432",
        "error", "Connection timeout"
    )

    print("\n✅ Example 3 complete!\n")


fn example4_query_logging() raises:
    """Example 4: Query logging with timing."""
    print("=" * 70)
    print("Example 4: Query Logging")
    print("=" * 70)

    var logger = Logger.get("postgres.query")
    logger.set_level(LogLevel.debug())  # Enable debug to see all queries

    var qlogger = QueryLogger(logger, slow_query_threshold_ms=100.0)

    print("\n⏱️  Query logging with timing:\n")

    # Fast query
    print("Fast query:")
    qlogger.log_query(
        "SELECT id, name FROM users WHERE id = 1",
        15.5,  # 15.5 ms
        1      # 1 row
    )

    # Slow query (exceeds threshold)
    print("\nSlow query:")
    qlogger.log_query(
        "SELECT * FROM orders JOIN users ON orders.user_id = users.id WHERE created_at > '2024-01-01'",
        250.0,  # 250 ms (exceeds 100ms threshold)
        5000    # 5000 rows
    )

    # Long query (truncated)
    print("\nLong query (truncated):")
    var long_query = "SELECT " + ("column" * 50) + " FROM table"
    qlogger.log_query(long_query, 5.0, 10)

    # Query error
    print("\nQuery error:")
    qlogger.log_query_error(
        "SELECT * FROM non_existent_table",
        "relation \"non_existent_table\" does not exist"
    )

    print("\n✅ Example 4 complete!\n")


fn example5_connection_logging() raises:
    """Example 5: Connection lifecycle logging."""
    print("=" * 70)
    print("Example 5: Connection Logging")
    print("=" * 70)

    var logger = Logger.get("postgres.connection")
    var clogger = ConnectionLogger(logger)

    print("\n🔌 Connection lifecycle events:\n")

    # Connection attempt
    print("Connecting:")
    clogger.log_connecting("localhost", 5432)

    # Successful connection
    print("\nConnected:")
    clogger.log_connected("localhost", 5432)

    # Authentication
    print("\nAuthentication:")
    clogger.log_authentication_success("admin", "myapp")

    # Disconnection
    print("\nDisconnected:")
    clogger.log_disconnected("localhost", 5432)

    # Connection error
    print("\nConnection error:")
    clogger.log_connection_error(
        "db.example.com",
        5432,
        "Connection timeout after 30s"
    )

    # Authentication failure
    print("\nAuthentication failure:")
    clogger.log_authentication_failure(
        "baduser",
        "myapp",
        "password authentication failed"
    )

    print("\n✅ Example 5 complete!\n")


fn example6_log_level_filtering() raises:
    """Example 6: Log level filtering."""
    print("=" * 70)
    print("Example 6: Log Level Filtering")
    print("=" * 70)

    var logger = Logger.get("filtered")

    print("\n🔍 Testing log level filtering:\n")

    # Set to INFO - should see INFO, WARN, ERROR, FATAL
    print("Level: INFO (should see INFO, WARN, ERROR, FATAL)")
    logger.set_level(LogLevel.info())

    logger.debug("This DEBUG will NOT be shown")
    logger.info("This INFO will be shown")
    logger.warn("This WARN will be shown")
    logger.error("This ERROR will be shown")

    print("\nLevel: WARN (should only see WARN, ERROR, FATAL)")
    logger.set_level(LogLevel.warn())

    logger.debug("This DEBUG will NOT be shown")
    logger.info("This INFO will NOT be shown")
    logger.warn("This WARN will be shown")
    logger.error("This ERROR will be shown")

    print("\nLevel: ERROR (should only see ERROR, FATAL)")
    logger.set_level(LogLevel.error())

    logger.info("This INFO will NOT be shown")
    logger.warn("This WARN will NOT be shown")
    logger.error("This ERROR will be shown")
    logger.fatal("This FATAL will be shown")

    print("\n✅ Example 6 complete!\n")


fn example7_production_patterns() raises:
    """Example 7: Production logging patterns."""
    print("=" * 70)
    print("Example 7: Production Logging Patterns")
    print("=" * 70)

    print("\n📋 Production Logging Best Practices:\n")

    print("1️⃣  Use structured fields for filtering and analysis:")
    print("""
    logger.info(
        "User action",
        "user_id", user_id,
        "action", "purchase",
        "amount", amount,
        "trace_id", trace_id  # For distributed tracing
    )
    """)

    print("\n2️⃣  Use appropriate log levels:")
    print("""
    DEBUG: Detailed diagnostics (development only)
    INFO: Normal operations (user actions, major events)
    WARN: Recoverable issues (slow queries, deprecated APIs)
    ERROR: Error conditions (failed operations, exceptions)
    FATAL: Critical failures (system shutdown, data corruption)
    """)

    print("\n3️⃣  Don't log sensitive data:")
    print("""
    # ❌ BAD
    logger.debug("User login", "password", user_password)

    # ✅ GOOD
    logger.info("User login", "user_id", user_id)
    """)

    print("\n4️⃣  Use JSON format in production:")
    print("""
    var logger = Logger.get("app")
    logger.set_json_format(True)  # For log aggregation tools
    """)

    print("\n5️⃣  Include context for debugging:")
    print("""
    logger.error(
        "Database operation failed",
        "operation", "INSERT",
        "table", "users",
        "error", error_message,
        "retries", retry_count,
        "connection_id", conn_id
    )
    """)

    print("\n6️⃣  Log at boundaries:")
    print("""
    # Log incoming requests
    logger.info("Request received", "method", "POST", "path", "/api/users")

    # Log database operations
    qlogger.log_query(sql, duration, rows)

    # Log outgoing responses
    logger.info("Response sent", "status", 200, "duration_ms", duration)
    """)

    print("\n7️⃣  Set appropriate levels for environments:")
    print("""
    Development: logger.set_level(LogLevel.debug())
    Staging: logger.set_level(LogLevel.info())
    Production: logger.set_level(LogLevel.warn())
    """)

    print("\n✅ Example 7 complete!\n")


fn main() raises:
    print("\n")
    print("🔥 Logging Framework Examples")
    print("Structured Logging for Production Applications")
    print("\n")

    # Run examples
    example1_basic_logging()
    example2_structured_logging()
    example3_json_output()
    example4_query_logging()
    example5_connection_logging()
    example6_log_level_filtering()
    example7_production_patterns()

    print("=" * 70)
    print("🎉 All examples completed successfully!")
    print("=" * 70)
    print("\n💡 Key Takeaways:")
    print("   - Use structured logging with key-value fields")
    print("   - Set appropriate log levels for each environment")
    print("   - Use JSON format for log aggregation")
    print("   - Never log sensitive data (passwords, tokens, PII)")
    print("   - Include context for effective debugging")
    print("\n💡 Integration:")
    print("   - Integrate with log aggregation (ELK, Splunk)")
    print("   - Set up alerts on ERROR and FATAL logs")
    print("   - Monitor slow query logs")
    print("   - Track connection errors")
    print("\n")
