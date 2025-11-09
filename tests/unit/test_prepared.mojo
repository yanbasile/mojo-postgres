"""
Unit tests for Prepared Statements.

Tests the PreparedStatement struct and statement caching.

Test Categories:
1. PreparedStatement creation
2. Parameter binding
3. Query building
4. Statement caching
5. Helper functions
6. Error handling
"""

from testing import assert_equal, assert_true, assert_false
from src.protocol.prepared import (
    PreparedStatement,
    StatementCache,
    count_placeholders,
    validate_parameter_count,
)
from src.protocol.connection import PostgresConnection


# ============================================================================
# Test 1: PreparedStatement Creation Tests
# ============================================================================

fn test_prepared_statement_creation() raises:
    """Test 1.1: PreparedStatement creation."""
    print("  test_prepared_statement_creation...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var sql = "SELECT * FROM users WHERE id = $1"
    var stmt = PreparedStatement(conn, sql)

    assert_equal(stmt.sql, sql)
    assert_equal(stmt.is_prepared, False)
    assert_equal(stmt.is_closed, False)

    print(" ✅")


fn test_prepared_statement_with_name() raises:
    """Test 1.2: PreparedStatement with custom name."""
    print("  test_prepared_statement_with_name...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var sql = "SELECT * FROM users WHERE id = $1"
    var stmt = PreparedStatement(conn, sql, "my_statement")

    assert_equal(stmt.statement_name, "my_statement")

    print(" ✅")


# ============================================================================
# Test 2: Parameter Binding Tests
# ============================================================================

fn test_bind_string() raises:
    """Test 2.1: Bind string parameter."""
    print("  test_bind_string...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE name = $1")

    stmt.bind(0, "Alice")
    assert_equal(len(stmt.parameters), 1)
    assert_equal(stmt.parameters[0], "Alice")

    print(" ✅")


fn test_bind_int() raises:
    """Test 2.2: Bind integer parameter."""
    print("  test_bind_int...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE age = $1")

    stmt.bind_int(0, 30)
    assert_equal(stmt.parameters[0], "30")

    print(" ✅")


fn test_bind_float() raises:
    """Test 2.3: Bind float parameter."""
    print("  test_bind_float...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM products WHERE price = $1")

    stmt.bind_float(0, 19.99)
    assert_equal(stmt.parameters[0], "19.99")

    print(" ✅")


fn test_bind_bool() raises:
    """Test 2.4: Bind boolean parameter."""
    print("  test_bind_bool...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE active = $1")

    stmt.bind_bool(0, True)
    assert_equal(stmt.parameters[0], "true")

    stmt.bind_bool(0, False)
    assert_equal(stmt.parameters[0], "false")

    print(" ✅")


fn test_bind_null() raises:
    """Test 2.5: Bind NULL parameter."""
    print("  test_bind_null...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE email = $1")

    stmt.bind_null(0)
    assert_equal(stmt.parameters[0], "NULL")

    print(" ✅")


fn test_bind_multiple_parameters() raises:
    """Test 2.6: Bind multiple parameters."""
    print("  test_bind_multiple_parameters...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE name = $1 AND age = $2 AND active = $3")

    stmt.bind(0, "Bob")
    stmt.bind_int(1, 25)
    stmt.bind_bool(2, True)

    assert_equal(len(stmt.parameters), 3)
    assert_equal(stmt.parameters[0], "Bob")
    assert_equal(stmt.parameters[1], "25")
    assert_equal(stmt.parameters[2], "true")

    print(" ✅")


# ============================================================================
# Test 3: Query Building Tests
# ============================================================================

fn test_build_query_single_param() raises:
    """Test 3.1: Build query with single parameter."""
    print("  test_build_query_single_param...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE id = $1")
    stmt.bind(0, "123")

    var query = stmt._build_query()
    assert_true("'123'" in query)
    assert_false("$1" in query)

    print(" ✅")


fn test_build_query_multiple_params() raises:
    """Test 3.2: Build query with multiple parameters."""
    print("  test_build_query_multiple_params...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE name = $1 AND age = $2")
    stmt.bind(0, "Alice")
    stmt.bind_int(1, 30)

    var query = stmt._build_query()
    assert_true("'Alice'" in query)
    assert_true("'30'" in query)

    print(" ✅")


fn test_build_query_with_null() raises:
    """Test 3.3: Build query with NULL parameter."""
    print("  test_build_query_with_null...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE email = $1")
    stmt.bind_null(0)

    var query = stmt._build_query()
    assert_true("NULL" in query)
    assert_false("$1" in query)

    print(" ✅")


fn test_escape_string() raises:
    """Test 3.4: String escaping."""
    print("  test_escape_string...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE name = $1")

    # Test escaping single quotes
    var escaped = stmt._escape_string("O'Brien")
    assert_equal(escaped, "O''Brien")

    print(" ✅")


fn test_build_query_with_quotes() raises:
    """Test 3.5: Build query with string containing quotes."""
    print("  test_build_query_with_quotes...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE name = $1")
    stmt.bind(0, "O'Brien")

    var query = stmt._build_query()
    assert_true("O''Brien" in query)  # Should escape single quote

    print(" ✅")


# ============================================================================
# Test 4: Statement Cache Tests
# ============================================================================

fn test_statement_cache_creation() raises:
    """Test 4.1: Statement cache creation."""
    print("  test_statement_cache_creation...", end="")

    var cache = StatementCache(100)
    assert_equal(cache.max_size, 100)
    assert_equal(cache.size(), 0)

    print(" ✅")


fn test_statement_cache_add() raises:
    """Test 4.2: Add statements to cache."""
    print("  test_statement_cache_add...", end="")

    var cache = StatementCache(10)

    var sql1 = "SELECT * FROM users WHERE id = $1"
    cache.add(sql1)
    assert_equal(cache.size(), 1)
    assert_true(cache.contains(sql1))

    print(" ✅")


fn test_statement_cache_contains() raises:
    """Test 4.3: Check if statement is cached."""
    print("  test_statement_cache_contains...", end="")

    var cache = StatementCache(10)

    var sql1 = "SELECT * FROM users WHERE id = $1"
    var sql2 = "SELECT * FROM products WHERE id = $1"

    cache.add(sql1)

    assert_true(cache.contains(sql1))
    assert_false(cache.contains(sql2))

    print(" ✅")


fn test_statement_cache_duplicate() raises:
    """Test 4.4: Adding duplicate statement."""
    print("  test_statement_cache_duplicate...", end="")

    var cache = StatementCache(10)

    var sql = "SELECT * FROM users WHERE id = $1"
    cache.add(sql)
    cache.add(sql)  # Add same statement again

    assert_equal(cache.size(), 1)  # Size should not increase

    print(" ✅")


fn test_statement_cache_clear() raises:
    """Test 4.5: Clear cache."""
    print("  test_statement_cache_clear...", end="")

    var cache = StatementCache(10)

    cache.add("SELECT * FROM users WHERE id = $1")
    cache.add("SELECT * FROM products WHERE id = $1")
    cache.add("SELECT * FROM orders WHERE id = $1")

    assert_equal(cache.size(), 3)

    cache.clear()
    assert_equal(cache.size(), 0)

    print(" ✅")


# ============================================================================
# Test 5: Helper Functions Tests
# ============================================================================

fn test_count_placeholders_none() raises:
    """Test 5.1: Count placeholders with none."""
    print("  test_count_placeholders_none...", end="")

    var sql = "SELECT * FROM users"
    var count = count_placeholders(sql)
    assert_equal(count, 0)

    print(" ✅")


fn test_count_placeholders_single() raises:
    """Test 5.2: Count placeholders with single."""
    print("  test_count_placeholders_single...", end="")

    var sql = "SELECT * FROM users WHERE id = $1"
    var count = count_placeholders(sql)
    assert_equal(count, 1)

    print(" ✅")


fn test_count_placeholders_multiple() raises:
    """Test 5.3: Count placeholders with multiple."""
    print("  test_count_placeholders_multiple...", end="")

    var sql = "SELECT * FROM users WHERE name = $1 AND age = $2 AND active = $3"
    var count = count_placeholders(sql)
    assert_equal(count, 3)

    print(" ✅")


fn test_count_placeholders_repeated() raises:
    """Test 5.4: Count placeholders with repeated parameter."""
    print("  test_count_placeholders_repeated...", end="")

    var sql = "SELECT * FROM users WHERE id = $1 OR parent_id = $1"
    var count = count_placeholders(sql)
    assert_equal(count, 2)  # Counts both occurrences

    print(" ✅")


fn test_validate_parameter_count_match() raises:
    """Test 5.5: Validate matching parameter count."""
    print("  test_validate_parameter_count_match...", end="")

    var sql = "SELECT * FROM users WHERE name = $1 AND age = $2"
    validate_parameter_count(sql, 2)  # Should not raise

    print(" ✅")


fn test_validate_parameter_count_mismatch() raises:
    """Test 5.6: Validate mismatching parameter count."""
    print("  test_validate_parameter_count_mismatch...", end="")

    var sql = "SELECT * FROM users WHERE name = $1"
    var raised = False

    try:
        validate_parameter_count(sql, 2)  # Should raise
    except:
        raised = True

    assert_true(raised)

    print(" ✅")


# ============================================================================
# Test 6: Statement Reset Tests
# ============================================================================

fn test_statement_reset() raises:
    """Test 6.1: Reset statement parameters."""
    print("  test_statement_reset...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE name = $1 AND age = $2")

    # Bind parameters
    stmt.bind(0, "Alice")
    stmt.bind_int(1, 30)
    assert_equal(len(stmt.parameters), 2)

    # Reset
    stmt.reset()
    assert_equal(len(stmt.parameters), 0)

    print(" ✅")


fn test_statement_reuse_after_reset() raises:
    """Test 6.2: Reuse statement after reset."""
    print("  test_statement_reuse_after_reset...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE id = $1")

    # First use
    stmt.bind(0, "123")
    var query1 = stmt._build_query()
    assert_true("'123'" in query1)

    # Reset and reuse
    stmt.reset()
    stmt.bind(0, "456")
    var query2 = stmt._build_query()
    assert_true("'456'" in query2)
    assert_false("'123'" in query2)

    print(" ✅")


# ============================================================================
# Test 7: Statement Close Tests
# ============================================================================

fn test_statement_close() raises:
    """Test 7.1: Close statement."""
    print("  test_statement_close...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE id = $1")

    assert_false(stmt.is_closed)
    stmt.close()
    assert_true(stmt.is_closed)

    print(" ✅")


fn test_statement_close_idempotent() raises:
    """Test 7.2: Closing statement multiple times."""
    print("  test_statement_close_idempotent...", end="")

    var conn = PostgresConnection("localhost", 5432)
    var stmt = PreparedStatement(conn, "SELECT * FROM users WHERE id = $1")

    stmt.close()
    stmt.close()  # Should not raise
    assert_true(stmt.is_closed)

    print(" ✅")


fn main() raises:
    print("\n" + "=" * 70)
    print("Prepared Statements Unit Tests")
    print("=" * 70 + "\n")

    print("Test 1: PreparedStatement Creation Tests")
    test_prepared_statement_creation()
    test_prepared_statement_with_name()

    print("\nTest 2: Parameter Binding Tests")
    test_bind_string()
    test_bind_int()
    test_bind_float()
    test_bind_bool()
    test_bind_null()
    test_bind_multiple_parameters()

    print("\nTest 3: Query Building Tests")
    test_build_query_single_param()
    test_build_query_multiple_params()
    test_build_query_with_null()
    test_escape_string()
    test_build_query_with_quotes()

    print("\nTest 4: Statement Cache Tests")
    test_statement_cache_creation()
    test_statement_cache_add()
    test_statement_cache_contains()
    test_statement_cache_duplicate()
    test_statement_cache_clear()

    print("\nTest 5: Helper Functions Tests")
    test_count_placeholders_none()
    test_count_placeholders_single()
    test_count_placeholders_multiple()
    test_count_placeholders_repeated()
    test_validate_parameter_count_match()
    test_validate_parameter_count_mismatch()

    print("\nTest 6: Statement Reset Tests")
    test_statement_reset()
    test_statement_reuse_after_reset()

    print("\nTest 7: Statement Close Tests")
    test_statement_close()
    test_statement_close_idempotent()

    print("\n" + "=" * 70)
    print("✅ All 29 tests passed!")
    print("=" * 70 + "\n")
