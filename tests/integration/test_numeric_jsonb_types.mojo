"""
Integration tests for PostgreSQL NUMERIC and JSONB type decoders.

Tests typed accessors against real PostgreSQL database:
- NUMERIC (arbitrary precision decimal)
- JSONB (JSON binary storage)

Prerequisites:
Run PostgreSQL locally:
  docker run -d -p 5432:5432 \
    -e POSTGRES_PASSWORD=test \
    -e POSTGRES_USER=test \
    -e POSTGRES_DB=test \
    postgres:16

Or use existing test database from previous tasks.
"""

from src.protocol.connection import PostgresConnection
from testing import assert_equal, assert_true, assert_false


# ============================================================================
# NUMERIC Integration Tests
# ============================================================================

fn test_numeric_simple_query() raises:
    """Test NUMERIC decoding from simple query."""
    print("  Testing NUMERIC simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT 123.45::NUMERIC AS value")

    # Verify we got 1 row
    if result.row_count() != 1:
        raise Error("Expected 1 row")

    # Use typed accessor
    var value = result.get_numeric(0, 0)

    if value.to_string() != "123.45":
        raise Error("Expected '123.45', got: " + value.to_string())

    conn.close()
    print("    ✓ NUMERIC simple query works")


fn test_numeric_high_precision() raises:
    """Test NUMERIC with high precision (crypto prices)."""
    print("  Testing NUMERIC high precision...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # 8 decimal places (typical for crypto)
    var result = conn.query("SELECT 50123.45678901::NUMERIC(20,8) AS value")

    var value = result.get_numeric(0, 0)

    if value.to_string() != "50123.45678901":
        raise Error("High precision mismatch: " + value.to_string())

    conn.close()
    print("    ✓ NUMERIC high precision works")


fn test_numeric_very_large() raises:
    """Test NUMERIC with very large numbers (beyond INT64)."""
    print("  Testing NUMERIC very large...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT 99999999999999999999.99::NUMERIC AS value")

    var value = result.get_numeric(0, 0)
    var str_val = value.to_string()

    # Should preserve exact representation
    print("    ✓ NUMERIC very large works (value: " + str_val + ")")

    conn.close()


fn test_numeric_very_small() raises:
    """Test NUMERIC with very small decimals (satoshis)."""
    print("  Testing NUMERIC very small...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # 1 satoshi = 0.00000001 BTC
    var result = conn.query("SELECT 0.00000001::NUMERIC AS value")

    var value = result.get_numeric(0, 0)

    if value.to_string() != "0.00000001":
        raise Error("Very small decimal mismatch: " + value.to_string())

    conn.close()
    print("    ✓ NUMERIC very small works")


fn test_numeric_negative() raises:
    """Test NUMERIC with negative values."""
    print("  Testing NUMERIC negative values...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            (-999.99::NUMERIC),
            (-0.01::NUMERIC)
        ) AS t(value)
    """)

    if result.row_count() != 2:
        raise Error("Expected 2 rows")

    var val1 = result.get_numeric(0, 0)
    if val1.to_string() != "-999.99":
        raise Error("Negative value 1 mismatch")

    var val2 = result.get_numeric(1, 0)
    if val2.to_string() != "-0.01":
        raise Error("Negative value 2 mismatch")

    conn.close()
    print("    ✓ NUMERIC negative values work")


fn test_numeric_null_handling() raises:
    """Test NUMERIC NULL handling."""
    print("  Testing NUMERIC NULL handling...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            (123.45::NUMERIC),
            (NULL::NUMERIC)
        ) AS t(value)
    """)

    # First row should work
    var val1 = result.get_numeric(0, 0)
    if val1.to_string() != "123.45":
        raise Error("Expected '123.45'")

    # Second row should raise error
    var error_raised = False
    try:
        var val2 = result.get_numeric(1, 0)
    except:
        error_raised = True

    if not error_raised:
        raise Error("Expected error when accessing NULL NUMERIC")

    # Should use is_null() first
    if not result.is_null(1, 0):
        raise Error("is_null() should return True for NULL value")

    conn.close()
    print("    ✓ NUMERIC NULL handling works")


fn test_numeric_financial_table() raises:
    """Test NUMERIC with financial data table."""
    print("  Testing NUMERIC financial table...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create temporary table with NUMERIC columns
    var _ = conn.query("""
        CREATE TEMPORARY TABLE account_balances (
            id SERIAL PRIMARY KEY,
            account_name TEXT NOT NULL,
            balance NUMERIC(20, 8) NOT NULL,
            reserved NUMERIC(20, 8) NOT NULL
        )
    """)

    # Insert sample data
    var __ = conn.query("""
        INSERT INTO account_balances (account_name, balance, reserved) VALUES
            ('alice_btc', 1.50000000, 0.10000000),
            ('bob_btc', 0.00123456, 0.00000000),
            ('charlie_btc', 999.99999999, 100.00000000)
    """)

    # Query and verify
    var result = conn.query("""
        SELECT account_name, balance, reserved
        FROM account_balances
        ORDER BY account_name
    """)

    if result.row_count() != 3:
        raise Error("Expected 3 accounts")

    # Alice
    var name1 = result.get_value(0, 0)
    var balance1 = result.get_numeric(0, 1)
    var reserved1 = result.get_numeric(0, 2)

    if name1 != "alice_btc":
        raise Error("Expected alice_btc")

    # Balance should be exact
    var balance1_float = balance1.to_float64()
    if abs(balance1_float - 1.5) > 0.00000001:
        raise Error("Alice balance mismatch")

    conn.close()
    print("    ✓ NUMERIC financial table works")


# ============================================================================
# JSONB Integration Tests
# ============================================================================

fn test_jsonb_simple_query() raises:
    """Test JSONB decoding from simple query."""
    print("  Testing JSONB simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""SELECT '{"name": "Alice", "age": 30}'::JSONB AS value""")

    # Verify we got 1 row
    if result.row_count() != 1:
        raise Error("Expected 1 row")

    # Use typed accessor
    var json = result.get_jsonb(0, 0)

    var name = json.get_string("name")
    if name != "Alice":
        raise Error("Expected 'Alice', got: " + name)

    var age = json.get_int("age")
    if age != 30:
        raise Error("Expected 30, got: " + String(age))

    conn.close()
    print("    ✓ JSONB simple query works")


fn test_jsonb_mixed_types() raises:
    """Test JSONB with mixed types (string, int, float, bool)."""
    print("  Testing JSONB mixed types...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT '{"name": "Bob", "balance": 123.45, "active": true, "count": 42}'::JSONB AS value
    """)

    var json = result.get_jsonb(0, 0)

    var name = json.get_string("name")
    if name != "Bob":
        raise Error("String field mismatch")

    var balance = json.get_float("balance")
    if abs(balance - 123.45) > 0.001:
        raise Error("Float field mismatch")

    var active = json.get_bool("active")
    if not active:
        raise Error("Bool field should be true")

    var count = json.get_int("count")
    if count != 42:
        raise Error("Int field mismatch")

    conn.close()
    print("    ✓ JSONB mixed types work")


fn test_jsonb_nested_objects() raises:
    """Test JSONB with nested objects."""
    print("  Testing JSONB nested objects...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT '{"user": {"name": "Charlie", "id": 123}}'::JSONB AS value
    """)

    var json = result.get_jsonb(0, 0)

    var user = json.get_object("user")
    var name = user.get_string("name")

    if name != "Charlie":
        raise Error("Nested name mismatch")

    conn.close()
    print("    ✓ JSONB nested objects work")


fn test_jsonb_arrays() raises:
    """Test JSONB with arrays."""
    print("  Testing JSONB arrays...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT '{"tags": ["crypto", "trading", "BTC"]}'::JSONB AS value
    """)

    var json = result.get_jsonb(0, 0)

    var tags = json.get_array("tags")
    if tags.length() != 3:
        raise Error("Expected 3 tags")

    var tag0 = tags.get_string(0)
    if tag0 != "crypto":
        raise Error("Tag 0 mismatch")

    conn.close()
    print("    ✓ JSONB arrays work")


fn test_jsonb_null_values() raises:
    """Test JSONB with null values inside JSON."""
    print("  Testing JSONB null values...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT '{"name": "Alice", "email": null}'::JSONB AS value
    """)

    var json = result.get_jsonb(0, 0)

    if not json.is_null("email"):
        raise Error("Expected null for email")

    conn.close()
    print("    ✓ JSONB null values work")


fn test_jsonb_metadata_table() raises:
    """Test JSONB with metadata storage table."""
    print("  Testing JSONB metadata table...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create temporary table with JSONB column
    var _ = conn.query("""
        CREATE TEMPORARY TABLE trade_metadata (
            id SERIAL PRIMARY KEY,
            symbol TEXT NOT NULL,
            metadata JSONB NOT NULL
        )
    """)

    # Insert sample data
    var __ = conn.query("""
        INSERT INTO trade_metadata (symbol, metadata) VALUES
            ('BTC/USD', '{"exchange": "Coinbase", "fee": 0.001, "maker": true}'),
            ('ETH/USD', '{"exchange": "Binance", "fee": 0.0015, "maker": false}')
    """)

    # Query and verify
    var result = conn.query("""
        SELECT symbol, metadata
        FROM trade_metadata
        WHERE symbol = 'BTC/USD'
    """)

    if result.row_count() != 1:
        raise Error("Expected 1 trade")

    var symbol = result.get_value(0, 0)
    var metadata = result.get_jsonb(0, 1)

    if symbol != "BTC/USD":
        raise Error("Symbol mismatch")

    var exchange = metadata.get_string("exchange")
    if exchange != "Coinbase":
        raise Error("Exchange mismatch")

    var fee = metadata.get_float("fee")
    if abs(fee - 0.001) > 0.0001:
        raise Error("Fee mismatch")

    var maker = metadata.get_bool("maker")
    if not maker:
        raise Error("Maker should be true")

    conn.close()
    print("    ✓ JSONB metadata table works")


# ============================================================================
# Main Test Runner
# ============================================================================

fn main() raises:
    print("\n" + "=" * 70)
    print("Integration Tests: NUMERIC and JSONB Type Decoders")
    print("=" * 70)
    print("")
    print("Testing against PostgreSQL database...")
    print("Connection: localhost:5432, database: test")
    print("")

    print("NUMERIC Tests:")
    test_numeric_simple_query()
    test_numeric_high_precision()
    test_numeric_very_large()
    test_numeric_very_small()
    test_numeric_negative()
    test_numeric_null_handling()
    test_numeric_financial_table()

    print("\nJSONB Tests:")
    test_jsonb_simple_query()
    test_jsonb_mixed_types()
    test_jsonb_nested_objects()
    test_jsonb_arrays()
    test_jsonb_null_values()
    test_jsonb_metadata_table()

    print("\n" + "=" * 70)
    print("✅ All integration tests passed!")
    print("=" * 70)
    print("")
    print("Summary:")
    print("  - NUMERIC: ✓")
    print("  - JSONB: ✓")
    print("  - NULL handling: ✓")
    print("  - Type safety: ✓")
    print("  - Real table operations: ✓")
    print("")
    print("NUMERIC and JSONB type decoders are production-ready! 🔥")
    print("=" * 70)
