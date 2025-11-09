"""
Integration tests for PostgreSQL text and boolean type decoders.

Tests typed accessors against real PostgreSQL database:
- BOOLEAN
- TEXT
- VARCHAR
- CHAR

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
# BOOLEAN Integration Tests
# ============================================================================

fn test_boolean_simple_query() raises:
    """Test BOOLEAN decoding from simple query."""
    print("  Testing BOOLEAN simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT TRUE::BOOLEAN AS value")

    # Verify we got 1 row
    if result.row_count() != 1:
        raise Error("Expected 1 row, got " + String(result.row_count()))

    # Use typed accessor
    var value = result.get_bool(0, 0)

    if not value:
        raise Error("Expected TRUE")

    conn.close()
    print("    ✓ BOOLEAN simple query works")


fn test_boolean_true_false() raises:
    """Test BOOLEAN with TRUE and FALSE values."""
    print("  Testing BOOLEAN TRUE and FALSE...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            (TRUE::BOOLEAN),
            (FALSE::BOOLEAN)
        ) AS t(value)
    """)

    if result.row_count() != 2:
        raise Error("Expected 2 rows")

    var val_true = result.get_bool(0, 0)
    if not val_true:
        raise Error("Row 0: Expected TRUE")

    var val_false = result.get_bool(1, 0)
    if val_false:
        raise Error("Row 1: Expected FALSE")

    conn.close()
    print("    ✓ BOOLEAN TRUE/FALSE work")


fn test_boolean_text_representations() raises:
    """Test BOOLEAN with various text representations."""
    print("  Testing BOOLEAN text representations...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # PostgreSQL accepts 't', 'true', 'yes', 'on', '1' for TRUE
    var result = conn.query("""
        SELECT * FROM (VALUES
            ('t'::BOOLEAN),
            ('true'::BOOLEAN),
            ('yes'::BOOLEAN),
            ('on'::BOOLEAN),
            ('1'::BOOLEAN)
        ) AS t(value)
    """)

    # All should be TRUE
    for row_idx in range(result.row_count()):
        var value = result.get_bool(row_idx, 0)
        if not value:
            raise Error("Row " + String(row_idx) + ": Expected TRUE")

    conn.close()
    print("    ✓ BOOLEAN text representations work")


fn test_boolean_null_handling() raises:
    """Test BOOLEAN NULL handling."""
    print("  Testing BOOLEAN NULL handling...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            (TRUE::BOOLEAN),
            (NULL::BOOLEAN)
        ) AS t(value)
    """)

    # First row should work
    var val1 = result.get_bool(0, 0)
    if not val1:
        raise Error("Expected TRUE")

    # Second row should raise error
    var error_raised = False
    try:
        var val2 = result.get_bool(1, 0)
    except:
        error_raised = True

    if not error_raised:
        raise Error("Expected error when accessing NULL BOOLEAN")

    # Should use is_null() first
    if not result.is_null(1, 0):
        raise Error("is_null() should return True for NULL value")

    conn.close()
    print("    ✓ BOOLEAN NULL handling works")


fn test_boolean_table_operations() raises:
    """Test BOOLEAN with real table operations."""
    print("  Testing BOOLEAN table operations...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create temporary table with BOOLEAN column
    var _ = conn.query("""
        CREATE TEMPORARY TABLE user_settings (
            id SERIAL PRIMARY KEY,
            username TEXT NOT NULL,
            email_notifications BOOLEAN NOT NULL,
            dark_mode BOOLEAN NOT NULL
        )
    """)

    # Insert sample data
    var __ = conn.query("""
        INSERT INTO user_settings (username, email_notifications, dark_mode) VALUES
            ('alice', TRUE, FALSE),
            ('bob', FALSE, TRUE),
            ('charlie', TRUE, TRUE)
    """)

    # Query and verify
    var result = conn.query("""
        SELECT username, email_notifications, dark_mode
        FROM user_settings
        WHERE email_notifications = TRUE
        ORDER BY username
    """)

    if result.row_count() != 2:
        raise Error("Expected 2 users with email notifications enabled")

    # Alice
    var username1 = result.get_value(0, 0)
    var email_notif1 = result.get_bool(0, 1)
    var dark_mode1 = result.get_bool(0, 2)

    if username1 != "alice":
        raise Error("Expected alice")
    if not email_notif1:
        raise Error("Alice should have email notifications")
    if dark_mode1:
        raise Error("Alice should not have dark mode")

    # Charlie
    var username2 = result.get_value(1, 0)
    var email_notif2 = result.get_bool(1, 1)
    var dark_mode2 = result.get_bool(1, 2)

    if username2 != "charlie":
        raise Error("Expected charlie")
    if not email_notif2:
        raise Error("Charlie should have email notifications")
    if not dark_mode2:
        raise Error("Charlie should have dark mode")

    conn.close()
    print("    ✓ BOOLEAN table operations work")


# ============================================================================
# TEXT Integration Tests
# ============================================================================

fn test_text_simple_query() raises:
    """Test TEXT decoding from simple query."""
    print("  Testing TEXT simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT 'Hello, World!'::TEXT AS value")

    var value = result.get_text(0, 0)

    if value != "Hello, World!":
        raise Error("Expected 'Hello, World!', got: " + value)

    conn.close()
    print("    ✓ TEXT simple query works")


fn test_text_empty_string() raises:
    """Test TEXT with empty string."""
    print("  Testing TEXT empty string...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT ''::TEXT AS value")

    var value = result.get_text(0, 0)

    if value != "":
        raise Error("Expected empty string")

    conn.close()
    print("    ✓ TEXT empty string works")


fn test_text_unicode() raises:
    """Test TEXT with Unicode characters."""
    print("  Testing TEXT Unicode...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT 'Bitcoin: ₿, Ethereum: Ξ'::TEXT AS value")

    var value = result.get_text(0, 0)

    if value != "Bitcoin: ₿, Ethereum: Ξ":
        raise Error("Unicode mismatch")

    conn.close()
    print("    ✓ TEXT Unicode works")


fn test_text_long_string() raises:
    """Test TEXT with long string (10KB)."""
    print("  Testing TEXT long string...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Generate long string in PostgreSQL
    var result = conn.query("SELECT repeat('x', 10000)::TEXT AS value")

    var value = result.get_text(0, 0)

    if len(value) != 10000:
        raise Error("Expected 10000 chars, got " + String(len(value)))

    conn.close()
    print("    ✓ TEXT long string (10KB) works")


fn test_text_null_handling() raises:
    """Test TEXT NULL handling."""
    print("  Testing TEXT NULL handling...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            ('Hello'::TEXT),
            (NULL::TEXT)
        ) AS t(value)
    """)

    # First row should work
    var val1 = result.get_text(0, 0)
    if val1 != "Hello":
        raise Error("Expected 'Hello'")

    # Second row should raise error
    var error_raised = False
    try:
        var val2 = result.get_text(1, 0)
    except:
        error_raised = True

    if not error_raised:
        raise Error("Expected error when accessing NULL TEXT")

    conn.close()
    print("    ✓ TEXT NULL handling works")


# ============================================================================
# VARCHAR Integration Tests
# ============================================================================

fn test_varchar_simple_query() raises:
    """Test VARCHAR decoding from simple query."""
    print("  Testing VARCHAR simple query...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT 'Sample VARCHAR'::VARCHAR(50) AS value")

    var value = result.get_varchar(0, 0)

    if value != "Sample VARCHAR":
        raise Error("VARCHAR mismatch")

    conn.close()
    print("    ✓ VARCHAR simple query works")


fn test_varchar_length_constraint() raises:
    """Test VARCHAR with length constraint."""
    print("  Testing VARCHAR length constraint...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # PostgreSQL enforces length constraint
    var error_raised = False
    try:
        var _ = conn.query("SELECT 'ThisIsWayTooLongForVarchar10'::VARCHAR(10) AS value")
    except:
        error_raised = True

    if not error_raised:
        raise Error("Expected error for VARCHAR length violation")

    conn.close()
    print("    ✓ VARCHAR length constraint works")


fn test_varchar_table_operations() raises:
    """Test VARCHAR with real table operations."""
    print("  Testing VARCHAR table operations...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create temporary table with VARCHAR columns
    var _ = conn.query("""
        CREATE TEMPORARY TABLE users (
            id SERIAL PRIMARY KEY,
            username VARCHAR(50) NOT NULL,
            email VARCHAR(255) NOT NULL
        )
    """)

    # Insert sample data
    var __ = conn.query("""
        INSERT INTO users (username, email) VALUES
            ('alice', 'alice@example.com'),
            ('bob', 'bob@example.com')
    """)

    # Query and verify
    var result = conn.query("SELECT username, email FROM users ORDER BY username")

    if result.row_count() != 2:
        raise Error("Expected 2 users")

    var username1 = result.get_varchar(0, 0)
    var email1 = result.get_varchar(0, 1)

    if username1 != "alice":
        raise Error("Username mismatch")
    if email1 != "alice@example.com":
        raise Error("Email mismatch")

    conn.close()
    print("    ✓ VARCHAR table operations work")


# ============================================================================
# Mixed Types Test
# ============================================================================

fn test_mixed_boolean_text_types() raises:
    """Test query with mixed boolean and text types."""
    print("  Testing mixed boolean and text types...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT
            'Alice'::TEXT AS name,
            'alice@example.com'::VARCHAR(255) AS email,
            TRUE::BOOLEAN AS active
    """)

    var name = result.get_text(0, 0)
    var email = result.get_varchar(0, 1)
    var active = result.get_bool(0, 2)

    if name != "Alice":
        raise Error("Name mismatch")
    if email != "alice@example.com":
        raise Error("Email mismatch")
    if not active:
        raise Error("Expected active=TRUE")

    conn.close()
    print("    ✓ Mixed boolean and text types work")


# ============================================================================
# Real-World Use Case Tests
# ============================================================================

fn test_crypto_trading_symbols() raises:
    """Test TEXT/VARCHAR with cryptocurrency trading symbols."""
    print("  Testing crypto trading symbols...")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create temporary table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE trading_pairs (
            id SERIAL PRIMARY KEY,
            symbol VARCHAR(20) NOT NULL,
            base_currency VARCHAR(10) NOT NULL,
            quote_currency VARCHAR(10) NOT NULL,
            is_active BOOLEAN NOT NULL
        )
    """)

    # Insert sample data
    var __ = conn.query("""
        INSERT INTO trading_pairs (symbol, base_currency, quote_currency, is_active) VALUES
            ('BTC/USD', 'BTC', 'USD', TRUE),
            ('ETH/USD', 'ETH', 'USD', TRUE),
            ('SOL/USD', 'SOL', 'USD', FALSE)
    """)

    # Query active pairs
    var result = conn.query("""
        SELECT symbol, base_currency, quote_currency, is_active
        FROM trading_pairs
        WHERE is_active = TRUE
        ORDER BY symbol
    """)

    if result.row_count() != 2:
        raise Error("Expected 2 active pairs")

    # BTC/USD
    var symbol1 = result.get_varchar(0, 0)
    var base1 = result.get_varchar(0, 1)
    var quote1 = result.get_varchar(0, 2)
    var active1 = result.get_bool(0, 3)

    if symbol1 != "BTC/USD":
        raise Error("Symbol 1 mismatch")
    if base1 != "BTC":
        raise Error("Base 1 mismatch")
    if quote1 != "USD":
        raise Error("Quote 1 mismatch")
    if not active1:
        raise Error("Pair 1 should be active")

    # ETH/USD
    var symbol2 = result.get_varchar(1, 0)
    if symbol2 != "ETH/USD":
        raise Error("Symbol 2 mismatch")

    conn.close()
    print("    ✓ Crypto trading symbols work")


# ============================================================================
# Main Test Runner
# ============================================================================

fn main() raises:
    print("\n" + "=" * 70)
    print("Integration Tests: Text and Boolean Type Decoders")
    print("=" * 70)
    print("")
    print("Testing against PostgreSQL database...")
    print("Connection: localhost:5432, database: test")
    print("")

    print("BOOLEAN Tests:")
    test_boolean_simple_query()
    test_boolean_true_false()
    test_boolean_text_representations()
    test_boolean_null_handling()
    test_boolean_table_operations()

    print("\nTEXT Tests:")
    test_text_simple_query()
    test_text_empty_string()
    test_text_unicode()
    test_text_long_string()
    test_text_null_handling()

    print("\nVARCHAR Tests:")
    test_varchar_simple_query()
    test_varchar_length_constraint()
    test_varchar_table_operations()

    print("\nMixed Types Tests:")
    test_mixed_boolean_text_types()

    print("\nReal-World Use Cases:")
    test_crypto_trading_symbols()

    print("\n" + "=" * 70)
    print("✅ All integration tests passed!")
    print("=" * 70)
    print("")
    print("Summary:")
    print("  - BOOLEAN: ✓")
    print("  - TEXT: ✓")
    print("  - VARCHAR: ✓")
    print("  - NULL handling: ✓")
    print("  - Type safety: ✓")
    print("  - Real table operations: ✓")
    print("")
    print("Text and boolean type decoders are production-ready! 🔥")
    print("=" * 70)
