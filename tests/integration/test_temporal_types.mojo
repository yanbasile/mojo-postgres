"""
Integration tests for PostgreSQL temporal type decoders.

Tests typed accessors against real PostgreSQL database:
- TIMESTAMP (without timezone)
- TIMESTAMPTZ (with timezone)  
- DATE
- TIME

Prerequisites:
Run PostgreSQL locally:
  docker run -d -p 5432:5432 \
    -e POSTGRES_PASSWORD=test \
    -e POSTGRES_USER=test \
    -e POSTGRES_DB=test \
    postgres:16
"""

from src.protocol.connection import PostgresConnection


# ============================================================================
# TIMESTAMP Integration Tests
# ============================================================================

fn test_timestamp_simple_query() raises:
    """Test TIMESTAMP decoding from simple query."""
    print("  Testing TIMESTAMP simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT '2024-01-15 10:30:45'::TIMESTAMP AS value")

    var ts = result.get_timestamp(0, 0)

    if ts.year != 2024 or ts.month != 1 or ts.day != 15:
        raise Error("Date mismatch")
    if ts.hour != 10 or ts.minute != 30 or ts.second != 45:
        raise Error("Time mismatch")

    conn.close()
    print("    ✓ TIMESTAMP simple query works")


fn test_timestamp_with_microseconds() raises:
    """Test TIMESTAMP with microseconds."""
    print("  Testing TIMESTAMP with microseconds...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT '2024-01-15 10:30:45.123456'::TIMESTAMP AS value")

    var ts = result.get_timestamp(0, 0)

    if ts.microsecond != 123456:
        raise Error("Microsecond mismatch")

    conn.close()
    print("    ✓ TIMESTAMP with microseconds works")


fn test_timestamp_null_handling() raises:
    """Test TIMESTAMP NULL handling."""
    print("  Testing TIMESTAMP NULL handling...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            ('2024-01-15 10:30:45'::TIMESTAMP),
            (NULL::TIMESTAMP)
        ) AS t(value)
    """)

    # First row should work
    var ts1 = result.get_timestamp(0, 0)
    if ts1.year != 2024:
        raise Error("Expected 2024")

    # Second row should raise error
    var error_raised = False
    try:
        var ts2 = result.get_timestamp(1, 0)
    except:
        error_raised = True

    if not error_raised:
        raise Error("Expected error when accessing NULL TIMESTAMP")

    conn.close()
    print("    ✓ TIMESTAMP NULL handling works")


# ============================================================================
# TIMESTAMPTZ Integration Tests
# ============================================================================

fn test_timestamptz_simple_query() raises:
    """Test TIMESTAMPTZ decoding from simple query."""
    print("  Testing TIMESTAMPTZ simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT '2024-01-15 10:30:45+00'::TIMESTAMPTZ AS value")

    var tstz = result.get_timestamptz(0, 0)

    if tstz.year != 2024 or tstz.month != 1 or tstz.day != 15:
        raise Error("Date mismatch")
    if tstz.timezone_offset_seconds != 0:
        raise Error("Timezone mismatch")

    conn.close()
    print("    ✓ TIMESTAMPTZ simple query works")


fn test_timestamptz_with_timezone() raises:
    """Test TIMESTAMPTZ with various timezones."""
    print("  Testing TIMESTAMPTZ with timezones...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            ('2024-01-15 10:30:45+00'::TIMESTAMPTZ),
            ('2024-01-15 10:30:45-05'::TIMESTAMPTZ),
            ('2024-01-15 10:30:45+05:30'::TIMESTAMPTZ)
        ) AS t(value)
    """)

    # UTC
    var tstz1 = result.get_timestamptz(0, 0)
    if tstz1.timezone_offset_seconds != 0:
        raise Error("UTC timezone mismatch")

    # EST (-5 hours)
    var tstz2 = result.get_timestamptz(1, 0)
    if tstz2.timezone_offset_seconds != -18000:  # -5 * 3600
        raise Error("EST timezone mismatch")

    # IST (+5:30)
    var tstz3 = result.get_timestamptz(2, 0)
    if tstz3.timezone_offset_seconds != 19800:  # 5.5 * 3600
        raise Error("IST timezone mismatch")

    conn.close()
    print("    ✓ TIMESTAMPTZ with timezones works")


# ============================================================================
# DATE Integration Tests
# ============================================================================

fn test_date_simple_query() raises:
    """Test DATE decoding from simple query."""
    print("  Testing DATE simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT '2024-01-15'::DATE AS value")

    var date = result.get_date(0, 0)

    if date.year != 2024 or date.month != 1 or date.day != 15:
        raise Error("Date mismatch")

    conn.close()
    print("    ✓ DATE simple query works")


fn test_date_leap_year() raises:
    """Test DATE with leap year."""
    print("  Testing DATE leap year...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT '2024-02-29'::DATE AS value")

    var date = result.get_date(0, 0)

    if date.year != 2024 or date.month != 2 or date.day != 29:
        raise Error("Leap year date mismatch")

    conn.close()
    print("    ✓ DATE leap year works")


# ============================================================================
# TIME Integration Tests
# ============================================================================

fn test_time_simple_query() raises:
    """Test TIME decoding from simple query."""
    print("  Testing TIME simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT '10:30:45'::TIME AS value")

    var time = result.get_time(0, 0)

    if time.hour != 10 or time.minute != 30 or time.second != 45:
        raise Error("Time mismatch")

    conn.close()
    print("    ✓ TIME simple query works")


fn test_time_with_microseconds() raises:
    """Test TIME with microseconds."""
    print("  Testing TIME with microseconds...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT '10:30:45.123456'::TIME AS value")

    var time = result.get_time(0, 0)

    if time.microsecond != 123456:
        raise Error("Microsecond mismatch")

    conn.close()
    print("    ✓ TIME with microseconds works")


# ============================================================================
# Real-World Use Case Tests
# ============================================================================

fn test_timeseries_data() raises:
    """Test temporal types with TimescaleDB-style time series data."""
    print("  Testing time series data (TimescaleDB style)...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create temporary table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE sensor_readings (
            id SERIAL PRIMARY KEY,
            sensor_id INT NOT NULL,
            recorded_at TIMESTAMPTZ NOT NULL,
            value FLOAT8 NOT NULL
        )
    """)

    # Insert sample data
    var __ = conn.query("""
        INSERT INTO sensor_readings (sensor_id, recorded_at, value) VALUES
            (1, '2024-01-15 10:00:00+00', 23.5),
            (1, '2024-01-15 10:01:00+00', 23.7),
            (1, '2024-01-15 10:02:00+00', 23.6)
    """)

    # Query and verify
    var result = conn.query("""
        SELECT sensor_id, recorded_at, value
        FROM sensor_readings
        ORDER BY recorded_at
    """)

    if result.row_count() != 3:
        raise Error("Expected 3 readings")

    # Verify first reading
    var sensor_id = result.get_int4(0, 0)
    var tstz = result.get_timestamptz(0, 1)
    var value = result.get_float8(0, 2)

    if sensor_id != 1:
        raise Error("Sensor ID mismatch")
    if tstz.year != 2024 or tstz.hour != 10 or tstz.minute != 0:
        raise Error("Timestamp mismatch")
    if value < 23.4 or value > 23.6:
        raise Error("Value mismatch")

    conn.close()
    print("    ✓ Time series data works")


# ============================================================================
# Main Test Runner
# ============================================================================

fn main() raises:
    print("\n" + "=" * 70)
    print("Integration Tests: Temporal Type Decoders")
    print("=" * 70)
    print("")
    print("Testing against PostgreSQL database...")
    print("Connection: localhost:5432, database: test")
    print("")

    print("TIMESTAMP Tests:")
    test_timestamp_simple_query()
    test_timestamp_with_microseconds()
    test_timestamp_null_handling()

    print("\nTIMESTAMPTZ Tests:")
    test_timestamptz_simple_query()
    test_timestamptz_with_timezone()

    print("\nDATE Tests:")
    test_date_simple_query()
    test_date_leap_year()

    print("\nTIME Tests:")
    test_time_simple_query()
    test_time_with_microseconds()

    print("\nReal-World Use Cases:")
    test_timeseries_data()

    print("\n" + "=" * 70)
    print("✅ All integration tests passed!")
    print("=" * 70)
    print("")
    print("Summary:")
    print("  - TIMESTAMP: ✓")
    print("  - TIMESTAMPTZ: ✓")
    print("  - DATE: ✓")
    print("  - TIME: ✓")
    print("  - NULL handling: ✓")
    print("  - TimescaleDB use case: ✓")
    print("")
    print("Temporal type decoders are production-ready for TimescaleDB! 🔥")
    print("=" * 70)
