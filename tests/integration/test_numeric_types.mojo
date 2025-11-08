"""
Integration tests for PostgreSQL numeric type decoders.

Tests typed accessors against real PostgreSQL database:
- INT2 (SMALLINT)
- INT4 (INTEGER)
- INT8 (BIGINT)
- FLOAT4 (REAL)
- FLOAT8 (DOUBLE PRECISION)

Prerequisites:
Run PostgreSQL locally:
  docker run -d -p 5432:5432 \
    -e POSTGRES_PASSWORD=test \
    -e POSTGRES_USER=test \
    -e POSTGRES_DB=test \
    postgres:16

Or use existing test database from Task 1.2 setup.
"""

from src.protocol.connection import PostgresConnection
from testing import assert_equal, assert_true, assert_false


# ============================================================================
# INT4 (INTEGER) Integration Tests
# ============================================================================

fn test_int4_simple_query() raises:
    """Test INT4 decoding from simple query."""
    print("  Testing INT4 simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT 42::INT4 AS value")

    # Verify we got 1 row
    if result.row_count() != 1:
        raise Error("Expected 1 row, got " + String(result.row_count()))

    # Use typed accessor
    var value = result.get_int4(0, 0)

    if value != 42:
        raise Error("Expected 42, got " + String(value))

    conn.close()
    print("    ✓ INT4 simple query works")


fn test_int4_multiple_values() raises:
    """Test INT4 with multiple values including positive, negative, zero."""
    print("  Testing INT4 multiple values...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            (42::INT4),
            (-100::INT4),
            (0::INT4),
            (2147483647::INT4),
            (-2147483648::INT4)
        ) AS t(value)
    """)

    if result.row_count() != 5:
        raise Error("Expected 5 rows")

    # Verify values
    var val1 = result.get_int4(0, 0)
    if val1 != 42:
        raise Error("Row 0: Expected 42, got " + String(val1))

    var val2 = result.get_int4(1, 0)
    if val2 != -100:
        raise Error("Row 1: Expected -100, got " + String(val2))

    var val3 = result.get_int4(2, 0)
    if val3 != 0:
        raise Error("Row 2: Expected 0, got " + String(val3))

    var val4 = result.get_int4(3, 0)
    if val4 != 2147483647:  # INT32_MAX
        raise Error("Row 3: Expected INT32_MAX")

    var val5 = result.get_int4(4, 0)
    if val5 != -2147483648:  # INT32_MIN
        raise Error("Row 4: Expected INT32_MIN")

    conn.close()
    print("    ✓ INT4 multiple values work")


fn test_int4_null_handling() raises:
    """Test INT4 NULL handling."""
    print("  Testing INT4 NULL handling...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            (42::INT4),
            (NULL::INT4)
        ) AS t(value)
    """)

    # First row should work
    var val1 = result.get_int4(0, 0)
    if val1 != 42:
        raise Error("Expected 42")

    # Second row should raise error
    var error_raised = False
    try:
        var val2 = result.get_int4(1, 0)
    except:
        error_raised = True

    if not error_raised:
        raise Error("Expected error when accessing NULL INT4")

    # Should use is_null() first
    if not result.is_null(1, 0):
        raise Error("is_null() should return True for NULL value")

    conn.close()
    print("    ✓ INT4 NULL handling works")


# ============================================================================
# INT8 (BIGINT) Integration Tests
# ============================================================================

fn test_int8_simple_query() raises:
    """Test INT8 decoding from simple query."""
    print("  Testing INT8 simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT 1000000000000::INT8 AS value")

    var value = result.get_int8(0, 0)

    if value != 1000000000000:
        raise Error("Expected 1000000000000, got " + String(value))

    conn.close()
    print("    ✓ INT8 simple query works")


fn test_int8_timestamp_values() raises:
    """Test INT8 with timestamp-like values (common use case)."""
    print("  Testing INT8 timestamp values...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Microseconds since epoch (typical TimescaleDB usage)
    var result = conn.query("""
        SELECT * FROM (VALUES
            (1704067200000000::INT8),  -- 2024-01-01 in microseconds
            (1735689600000000::INT8),  -- 2025-01-01 in microseconds
            (9223372036854775807::INT8) -- INT64_MAX
        ) AS t(timestamp_us)
    """)

    var ts1 = result.get_int8(0, 0)
    if ts1 != 1704067200000000:
        raise Error("Expected 2024-01-01 timestamp")

    var ts2 = result.get_int8(1, 0)
    if ts2 != 1735689600000000:
        raise Error("Expected 2025-01-01 timestamp")

    var ts3 = result.get_int8(2, 0)
    if ts3 != 9223372036854775807:
        raise Error("Expected INT64_MAX")

    conn.close()
    print("    ✓ INT8 timestamp values work")


fn test_int8_edge_cases() raises:
    """Test INT8 edge cases (min/max values)."""
    print("  Testing INT8 edge cases...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            (9223372036854775807::INT8),   -- INT64_MAX
            (-9223372036854775808::INT8),  -- INT64_MIN
            (0::INT8)
        ) AS t(value)
    """)

    var max_val = result.get_int8(0, 0)
    if max_val != 9223372036854775807:
        raise Error("Expected INT64_MAX")

    var min_val = result.get_int8(1, 0)
    if min_val != -9223372036854775808:
        raise Error("Expected INT64_MIN")

    var zero_val = result.get_int8(2, 0)
    if zero_val != 0:
        raise Error("Expected 0")

    conn.close()
    print("    ✓ INT8 edge cases work")


# ============================================================================
# FLOAT8 (DOUBLE PRECISION) Integration Tests
# ============================================================================

fn test_float8_simple_query() raises:
    """Test FLOAT8 decoding from simple query."""
    print("  Testing FLOAT8 simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT 3.14159::FLOAT8 AS value")

    var value = result.get_float8(0, 0)

    # Floating point comparison with tolerance
    if value < 3.14158 or value > 3.14160:
        raise Error("Expected ~3.14159, got " + String(value))

    conn.close()
    print("    ✓ FLOAT8 simple query works")


fn test_float8_crypto_prices() raises:
    """Test FLOAT8 with cryptocurrency price values (target use case)."""
    print("  Testing FLOAT8 crypto prices...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            (50123.45::FLOAT8),      -- BTC price
            (3012.67::FLOAT8),       -- ETH price
            (0.00000123::FLOAT8),    -- Small altcoin
            (-42.5::FLOAT8)          -- Negative value
        ) AS prices(price)
    """)

    var btc = result.get_float8(0, 0)
    if btc < 50123.44 or btc > 50123.46:
        raise Error("BTC price mismatch")

    var eth = result.get_float8(1, 0)
    if eth < 3012.66 or eth > 3012.68:
        raise Error("ETH price mismatch")

    var altcoin = result.get_float8(2, 0)
    if altcoin < 0.0000012 or altcoin > 0.0000013:
        raise Error("Altcoin price mismatch")

    var negative = result.get_float8(3, 0)
    if negative > -42.4 or negative < -42.6:
        raise Error("Negative value mismatch")

    conn.close()
    print("    ✓ FLOAT8 crypto prices work")


fn test_float8_special_values() raises:
    """Test FLOAT8 special values (Infinity, -Infinity, NaN)."""
    print("  Testing FLOAT8 special values...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            ('Infinity'::FLOAT8),
            ('-Infinity'::FLOAT8),
            ('NaN'::FLOAT8)
        ) AS t(value)
    """)

    from math import isinf, isnan

    var inf_val = result.get_float8(0, 0)
    if not isinf(inf_val):
        raise Error("Expected Infinity")

    var neg_inf_val = result.get_float8(1, 0)
    if not isinf(neg_inf_val):
        raise Error("Expected -Infinity")

    var nan_val = result.get_float8(2, 0)
    if not isnan(nan_val):
        raise Error("Expected NaN")

    conn.close()
    print("    ✓ FLOAT8 special values work")


fn test_float8_scientific_notation() raises:
    """Test FLOAT8 with scientific notation."""
    print("  Testing FLOAT8 scientific notation...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # PostgreSQL may return scientific notation for very large/small numbers
    var result = conn.query("""
        SELECT * FROM (VALUES
            (1.23e5::FLOAT8),
            (1.5e-3::FLOAT8)
        ) AS t(value)
    """)

    var large = result.get_float8(0, 0)
    if large < 122999 or large > 123001:
        raise Error("Expected ~123000")

    var small = result.get_float8(1, 0)
    if small < 0.0014 or small > 0.0016:
        raise Error("Expected ~0.0015")

    conn.close()
    print("    ✓ FLOAT8 scientific notation works")


# ============================================================================
# INT2 (SMALLINT) Integration Tests
# ============================================================================

fn test_int2_simple_query() raises:
    """Test INT2 decoding from simple query."""
    print("  Testing INT2 simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT 42::INT2 AS value")

    var value = result.get_int2(0, 0)

    if value != 42:
        raise Error("Expected 42, got " + String(value))

    conn.close()
    print("    ✓ INT2 simple query works")


fn test_int2_edge_cases() raises:
    """Test INT2 edge cases (min/max values)."""
    print("  Testing INT2 edge cases...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            (32767::INT2),   -- INT16_MAX
            (-32768::INT2),  -- INT16_MIN
            (0::INT2)
        ) AS t(value)
    """)

    var max_val = result.get_int2(0, 0)
    if max_val != 32767:
        raise Error("Expected INT16_MAX")

    var min_val = result.get_int2(1, 0)
    if min_val != -32768:
        raise Error("Expected INT16_MIN")

    var zero_val = result.get_int2(2, 0)
    if zero_val != 0:
        raise Error("Expected 0")

    conn.close()
    print("    ✓ INT2 edge cases work")


# ============================================================================
# FLOAT4 (REAL) Integration Tests
# ============================================================================

fn test_float4_simple_query() raises:
    """Test FLOAT4 decoding from simple query."""
    print("  Testing FLOAT4 simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT 3.14::FLOAT4 AS value")

    var value = result.get_float4(0, 0)

    # FLOAT4 has less precision than FLOAT8
    if value < 3.13 or value > 3.15:
        raise Error("Expected ~3.14")

    conn.close()
    print("    ✓ FLOAT4 simple query works")


# ============================================================================
# Mixed Types and Error Handling
# ============================================================================

fn test_mixed_numeric_types() raises:
    """Test query with mixed numeric types."""
    print("  Testing mixed numeric types...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT
            42::INT2 AS small_int,
            1000000::INT4 AS medium_int,
            1000000000000::INT8 AS big_int,
            3.14::FLOAT4 AS small_float,
            50123.45::FLOAT8 AS big_float
    """)

    var small_int = result.get_int2(0, 0)
    if small_int != 42:
        raise Error("INT2 mismatch")

    var medium_int = result.get_int4(0, 1)
    if medium_int != 1000000:
        raise Error("INT4 mismatch")

    var big_int = result.get_int8(0, 2)
    if big_int != 1000000000000:
        raise Error("INT8 mismatch")

    var small_float = result.get_float4(0, 3)
    if small_float < 3.13 or small_float > 3.15:
        raise Error("FLOAT4 mismatch")

    var big_float = result.get_float8(0, 4)
    if big_float < 50123.44 or big_float > 50123.46:
        raise Error("FLOAT8 mismatch")

    conn.close()
    print("    ✓ Mixed numeric types work")


fn test_type_mismatch_errors() raises:
    """Test error handling when using wrong type accessor."""
    print("  Testing type mismatch errors...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query returns TEXT, but we'll try to get as INT4
    var result = conn.query("SELECT 'hello'::TEXT AS value")

    var error_raised = False
    try:
        var value = result.get_int4(0, 0)
    except:
        error_raised = True

    if not error_raised:
        raise Error("Expected error when getting TEXT as INT4")

    conn.close()
    print("    ✓ Type mismatch errors work")


fn test_real_table_operations() raises:
    """Test numeric types with real table operations."""
    print("  Testing real table operations...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create temporary table with numeric columns
    var _ = conn.query("""
        CREATE TEMPORARY TABLE crypto_trades (
            id SERIAL PRIMARY KEY,
            timestamp_us INT8 NOT NULL,
            symbol TEXT NOT NULL,
            price FLOAT8 NOT NULL,
            volume INT8 NOT NULL
        )
    """)

    # Insert sample data
    var __ = conn.query("""
        INSERT INTO crypto_trades (timestamp_us, symbol, price, volume) VALUES
            (1704067200000000, 'BTC', 50123.45, 1000000),
            (1704067260000000, 'ETH', 3012.67, 5000000),
            (1704067320000000, 'BTC', 50145.23, 750000)
    """)

    # Query and verify
    var result = conn.query("""
        SELECT timestamp_us, price, volume
        FROM crypto_trades
        WHERE symbol = 'BTC'
        ORDER BY timestamp_us
    """)

    if result.row_count() != 2:
        raise Error("Expected 2 BTC trades")

    # First trade
    var ts1 = result.get_int8(0, 0)
    var price1 = result.get_float8(0, 1)
    var volume1 = result.get_int8(0, 2)

    if ts1 != 1704067200000000:
        raise Error("Timestamp 1 mismatch")
    if price1 < 50123.44 or price1 > 50123.46:
        raise Error("Price 1 mismatch")
    if volume1 != 1000000:
        raise Error("Volume 1 mismatch")

    # Second trade
    var ts2 = result.get_int8(1, 0)
    var price2 = result.get_float8(1, 1)
    var volume2 = result.get_int8(1, 2)

    if ts2 != 1704067320000000:
        raise Error("Timestamp 2 mismatch")
    if price2 < 50145.22 or price2 > 50145.24:
        raise Error("Price 2 mismatch")
    if volume2 != 750000:
        raise Error("Volume 2 mismatch")

    conn.close()
    print("    ✓ Real table operations work")


# ============================================================================
# Main Test Runner
# ============================================================================

fn main() raises:
    print("\n" + "=" * 70)
    print("Integration Tests: Numeric Type Decoders")
    print("=" * 70)
    print("")
    print("Testing against PostgreSQL database...")
    print("Connection: localhost:5432, database: test")
    print("")

    print("INT4 (INTEGER) Tests:")
    test_int4_simple_query()
    test_int4_multiple_values()
    test_int4_null_handling()

    print("\nINT8 (BIGINT) Tests:")
    test_int8_simple_query()
    test_int8_timestamp_values()
    test_int8_edge_cases()

    print("\nFLOAT8 (DOUBLE PRECISION) Tests:")
    test_float8_simple_query()
    test_float8_crypto_prices()
    test_float8_special_values()
    test_float8_scientific_notation()

    print("\nINT2 (SMALLINT) Tests:")
    test_int2_simple_query()
    test_int2_edge_cases()

    print("\nFLOAT4 (REAL) Tests:")
    test_float4_simple_query()

    print("\nMixed Types and Error Handling:")
    test_mixed_numeric_types()
    test_type_mismatch_errors()
    test_real_table_operations()

    print("\n" + "=" * 70)
    print("✅ All integration tests passed!")
    print("=" * 70)
    print("")
    print("Summary:")
    print("  - INT2 (SMALLINT): ✓")
    print("  - INT4 (INTEGER): ✓")
    print("  - INT8 (BIGINT): ✓")
    print("  - FLOAT4 (REAL): ✓")
    print("  - FLOAT8 (DOUBLE PRECISION): ✓")
    print("  - NULL handling: ✓")
    print("  - Type safety: ✓")
    print("  - Real table operations: ✓")
    print("")
    print("Numeric type decoders are production-ready! 🔥")
    print("=" * 70)
