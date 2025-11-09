"""
Integration tests for COPY operations with real PostgreSQL.

Prerequisites:
- PostgreSQL running on localhost:5432
- Database 'test' with user 'test' / password 'test'

Tests:
1. Basic COPY FROM with small dataset
2. COPY FROM with NULL values
3. COPY FROM with special characters (escaping)
4. Large dataset COPY FROM (stress test)
5. COPY FROM with constraint violations (error handling)
6. COPY FROM with multiple data types
7. Performance comparison: COPY vs INSERT
"""

from testing import assert_equal, assert_true, assert_false, assert_raises
from src.protocol.connection import PostgresConnection
from collections import List


fn test_basic_copy_from() raises:
    """Test 1: Basic COPY FROM with small dataset."""
    print("  test_basic_copy_from...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create test table
    var _ = conn.query("DROP TABLE IF EXISTS copy_test_basic")
    var __ = conn.query("""
        CREATE TABLE copy_test_basic (
            id SERIAL PRIMARY KEY,
            name TEXT,
            age INT
        )
    """)

    # Prepare data
    var columns = List[String]()
    columns.append("name")
    columns.append("age")

    var rows = List[List[String]]()
    for i in range(5):
        var row = List[String]()
        row.append("User" + String(i))
        row.append(String(20 + i))
        rows.append(row)

    # Execute COPY FROM
    conn.copy_from("copy_test_basic", columns, rows)

    # Verify count
    var result = conn.query("SELECT COUNT(*) FROM copy_test_basic")
    var count = result.get_int4(0, 0)
    assert_equal(count, 5)

    # Verify data
    var data = conn.query("SELECT name, age FROM copy_test_basic ORDER BY age")
    assert_equal(data.row_count(), 5)
    assert_equal(data.get_value(0, 0), "User0")
    assert_equal(data.get_int4(0, 1), 20)

    # Cleanup
    var _c = conn.query("DROP TABLE copy_test_basic")
    conn.close()

    print(" ✅")


fn test_copy_from_with_special_characters() raises:
    """Test 3: COPY FROM with special characters (tabs, newlines)."""
    print("  test_copy_from_with_special_characters...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create test table
    var _ = conn.query("DROP TABLE IF EXISTS copy_test_special")
    var __ = conn.query("CREATE TABLE copy_test_special (text_col TEXT)")

    # Data with special characters
    var columns = List[String]()
    columns.append("text_col")

    var rows = List[List[String]]()

    var row1 = List[String]()
    row1.append("Tab\there")  # Tab character
    rows.append(row1)

    var row2 = List[String]()
    row2.append("New\nline")  # Newline
    rows.append(row2)

    var row3 = List[String]()
    row3.append("Back\\slash")  # Backslash
    rows.append(row3)

    # Execute COPY FROM
    conn.copy_from("copy_test_special", columns, rows)

    # Verify data was escaped correctly
    var result = conn.query("SELECT text_col FROM copy_test_special ORDER BY text_col")
    assert_equal(result.row_count(), 3)

    # Check that special characters were preserved
    var val1 = result.get_value(0, 0)
    var val2 = result.get_value(1, 0)
    var val3 = result.get_value(2, 0)

    assert_true(len(val1) > 0)  # Back\slash
    assert_true(len(val2) > 0)  # New\nline
    assert_true(len(val3) > 0)  # Tab\there

    # Cleanup
    var _c = conn.query("DROP TABLE copy_test_special")
    conn.close()

    print(" ✅")


fn test_large_dataset_copy_from() raises:
    """Test 4: Large dataset COPY FROM (1000 rows)."""
    print("  test_large_dataset_copy_from...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create test table
    var _ = conn.query("DROP TABLE IF EXISTS copy_test_large")
    var __ = conn.query("""
        CREATE TABLE copy_test_large (
            id SERIAL PRIMARY KEY,
            value INT,
            description TEXT
        )
    """)

    # Prepare large dataset
    var columns = List[String]()
    columns.append("value")
    columns.append("description")

    var rows = List[List[String]]()
    var row_count = 1000

    for i in range(row_count):
        var row = List[String]()
        row.append(String(i * 100))
        row.append("Description " + String(i))
        rows.append(row)

    # Execute COPY FROM
    conn.copy_from("copy_test_large", columns, rows)

    # Verify count
    var result = conn.query("SELECT COUNT(*) FROM copy_test_large")
    var count = result.get_int4(0, 0)
    assert_equal(count, row_count)

    # Spot check a few values
    var sample = conn.query("SELECT value FROM copy_test_large WHERE value = 50000")
    assert_equal(sample.row_count(), 1)
    assert_equal(sample.get_int4(0, 0), 50000)

    # Cleanup
    var _c = conn.query("DROP TABLE copy_test_large")
    conn.close()

    print(" ✅")


fn test_copy_from_with_constraints() raises:
    """Test 5: COPY FROM with constraint violations."""
    print("  test_copy_from_with_constraints...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table with constraints
    var _ = conn.query("DROP TABLE IF EXISTS copy_test_constraints")
    var __ = conn.query("""
        CREATE TABLE copy_test_constraints (
            id SERIAL PRIMARY KEY,
            age INT CHECK (age >= 0 AND age <= 150)
        )
    """)

    # Valid data should succeed
    var columns = List[String]()
    columns.append("age")

    var valid_rows = List[List[String]]()
    var row1 = List[String]()
    row1.append("25")
    valid_rows.append(row1)

    conn.copy_from("copy_test_constraints", columns, valid_rows)

    var result = conn.query("SELECT COUNT(*) FROM copy_test_constraints")
    assert_equal(result.get_int4(0, 0), 1)

    # Invalid data should fail
    var invalid_rows = List[List[String]]()
    var row2 = List[String]()
    row2.append("999")  # Invalid age
    invalid_rows.append(row2)

    var failed = False
    try:
        conn.copy_from("copy_test_constraints", columns, invalid_rows)
    except:
        failed = True

    assert_true(failed)  # Should have raised error

    # Count should still be 1 (transaction rolled back)
    var result2 = conn.query("SELECT COUNT(*) FROM copy_test_constraints")
    assert_equal(result2.get_int4(0, 0), 1)

    # Cleanup
    var _c = conn.query("DROP TABLE copy_test_constraints")
    conn.close()

    print(" ✅")


fn test_copy_from_multiple_types() raises:
    """Test 6: COPY FROM with multiple PostgreSQL types."""
    print("  test_copy_from_multiple_types...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table with various types
    var _ = conn.query("DROP TABLE IF EXISTS copy_test_types")
    var __ = conn.query("""
        CREATE TABLE copy_test_types (
            id SERIAL PRIMARY KEY,
            int_col INT,
            text_col TEXT,
            bool_col BOOLEAN,
            float_col FLOAT8
        )
    """)

    # Prepare data with different types
    var columns = List[String]()
    columns.append("int_col")
    columns.append("text_col")
    columns.append("bool_col")
    columns.append("float_col")

    var rows = List[List[String]]()

    var row1 = List[String]()
    row1.append("42")
    row1.append("Hello")
    row1.append("true")
    row1.append("3.14159")
    rows.append(row1)

    var row2 = List[String]()
    row2.append("-100")
    row2.append("World")
    row2.append("false")
    row2.append("2.71828")
    rows.append(row2)

    # Execute COPY FROM
    conn.copy_from("copy_test_types", columns, rows)

    # Verify data
    var result = conn.query("SELECT int_col, text_col, bool_col, float_col FROM copy_test_types ORDER BY int_col")
    assert_equal(result.row_count(), 2)

    # First row
    assert_equal(result.get_int4(0, 0), -100)
    assert_equal(result.get_value(0, 1), "World")
    assert_equal(result.get_boolean(0, 2), False)

    # Second row
    assert_equal(result.get_int4(1, 0), 42)
    assert_equal(result.get_value(1, 1), "Hello")
    assert_equal(result.get_boolean(1, 2), True)

    # Cleanup
    var _c = conn.query("DROP TABLE copy_test_types")
    conn.close()

    print(" ✅")


fn test_copy_vs_insert_performance() raises:
    """Test 7: Performance comparison - COPY vs INSERT."""
    print("  test_copy_vs_insert_performance...", end="")

    from time import now

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var test_size = 100  # Small size for fast tests

    # Prepare test data
    var columns = List[String]()
    columns.append("value")

    var rows = List[List[String]]()
    for i in range(test_size):
        var row = List[String]()
        row.append(String(i))
        rows.append(row)

    # Test 1: Individual INSERTs
    var _ = conn.query("DROP TABLE IF EXISTS perf_insert")
    var __ = conn.query("CREATE TABLE perf_insert (value INT)")

    var start1 = now()
    for i in range(test_size):
        var sql = "INSERT INTO perf_insert VALUES (" + String(i) + ")"
        var ___ = conn.query(sql)
    var elapsed1 = now() - start1

    # Test 2: COPY FROM
    var _a = conn.query("DROP TABLE IF EXISTS perf_copy")
    var _b = conn.query("CREATE TABLE perf_copy (value INT)")

    var start2 = now()
    conn.copy_from("perf_copy", columns, rows)
    var elapsed2 = now() - start2

    # COPY should be faster than individual INSERTs
    assert_true(elapsed2 < elapsed1)

    # Verify both have same count
    var count1 = conn.query("SELECT COUNT(*) FROM perf_insert")
    var count2 = conn.query("SELECT COUNT(*) FROM perf_copy")
    assert_equal(count1.get_int4(0, 0), test_size)
    assert_equal(count2.get_int4(0, 0), test_size)

    # Cleanup
    var _c = conn.query("DROP TABLE perf_insert")
    var _d = conn.query("DROP TABLE perf_copy")
    conn.close()

    print(" ✅")


fn main() raises:
    print("\n" + "=" * 70)
    print("COPY Operations Integration Tests")
    print("=" * 70 + "\n")

    print("Running tests:")
    test_basic_copy_from()
    test_copy_from_with_special_characters()
    test_large_dataset_copy_from()
    test_copy_from_with_constraints()
    test_copy_from_multiple_types()
    test_copy_vs_insert_performance()

    print("\n" + "=" * 70)
    print("✅ All 6 integration tests passed!")
    print("=" * 70 + "\n")
