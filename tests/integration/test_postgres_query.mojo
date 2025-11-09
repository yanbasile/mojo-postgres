"""
Integration Test: PostgreSQL Simple Query Protocol

Tests actual query execution against a running PostgreSQL server.

Prerequisites:
- PostgreSQL must be running (see README.md for setup)
- Default connection: localhost:5432, user=test, password=test, database=test
"""

from src.protocol.connection import PostgresConnection
from sys import env_get


# Get connection parameters from environment or use defaults
fn get_test_host() -> String:
    try:
        return env_get("PGHOST")
    except:
        return "localhost"


fn get_test_port() -> Int:
    try:
        return int(env_get("PGPORT"))
    except:
        return 5432


fn get_test_database() -> String:
    try:
        return env_get("PGDATABASE")
    except:
        return "test"


fn get_test_user() -> String:
    try:
        return env_get("PGUSER")
    except:
        return "test"


fn get_test_password() -> String:
    try:
        return env_get("PGPASSWORD")
    except:
        return "test"


fn test_simple_select() raises:
    """Test simple SELECT query."""
    print("\nTest: Simple SELECT")

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()
    var password = get_test_password()

    var conn = PostgresConnection(host, port)
    conn.connect(database, user, password)

    # Execute simple query
    var result = conn.query("SELECT 1 AS num, 'hello' AS text")

    print("  ✓ Query executed successfully")
    print("  ✓ Columns:", String(result.column_count()))
    print("  ✓ Rows:", String(result.row_count()))

    # Verify results
    if result.column_count() != 2:
        raise Error("Expected 2 columns, got " + String(result.column_count()))

    if result.row_count() != 1:
        raise Error("Expected 1 row, got " + String(result.row_count()))

    print("  ✓ Column names:", result.get_column_name(0), ",", result.get_column_name(1))
    print("  ✓ Values:", result.get_value(0, 0), ",", result.get_value(0, 1))

    conn.close()
    print("  ✓ Test passed")


fn test_multiple_rows() raises:
    """Test query returning multiple rows."""
    print("\nTest: Multiple Rows")

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()
    var password = get_test_password()

    var conn = PostgresConnection(host, port)
    conn.connect(database, user, password)

    # Query with multiple rows using VALUES
    var result = conn.query("""
        SELECT * FROM (VALUES
            (1, 'Alice'),
            (2, 'Bob'),
            (3, 'Charlie')
        ) AS t(id, name)
    """)

    print("  ✓ Query executed")
    print("  ✓ Rows:", String(result.row_count()))

    if result.row_count() != 3:
        raise Error("Expected 3 rows, got " + String(result.row_count()))

    # Verify data
    if result.get_value(0, 0) != "1" or result.get_value(0, 1) != "Alice":
        raise Error("Row 0 data mismatch")

    if result.get_value(1, 0) != "2" or result.get_value(1, 1) != "Bob":
        raise Error("Row 1 data mismatch")

    if result.get_value(2, 0) != "3" or result.get_value(2, 1) != "Charlie":
        raise Error("Row 2 data mismatch")

    print("  ✓ All rows verified")

    conn.close()
    print("  ✓ Test passed")


fn test_null_values() raises:
    """Test handling of NULL values."""
    print("\nTest: NULL Values")

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()
    var password = get_test_password()

    var conn = PostgresConnection(host, port)
    conn.connect(database, user, password)

    # Query with NULL values
    var result = conn.query("SELECT 1 AS num, NULL AS empty, 'text' AS txt")

    print("  ✓ Query executed")

    # Check NULL detection
    if result.is_null(0, 0):
        raise Error("Column 0 should not be NULL")

    if not result.is_null(0, 1):
        raise Error("Column 1 should be NULL")

    if result.is_null(0, 2):
        raise Error("Column 2 should not be NULL")

    print("  ✓ NULL detection works")

    # Try to get NULL value (should raise error)
    var got_error = False
    try:
        var value = result.get_value(0, 1)
    except:
        got_error = True

    if not got_error:
        raise Error("Expected error when getting NULL value")

    print("  ✓ NULL value error handling works")

    conn.close()
    print("  ✓ Test passed")


fn test_empty_result() raises:
    """Test query with no rows."""
    print("\nTest: Empty Result")

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()
    var password = get_test_password()

    var conn = PostgresConnection(host, port)
    conn.connect(database, user, password)

    # Query that returns no rows
    var result = conn.query("SELECT 1 AS num WHERE FALSE")

    print("  ✓ Query executed")

    if result.row_count() != 0:
        raise Error("Expected 0 rows, got " + String(result.row_count()))

    if result.column_count() != 1:
        raise Error("Expected 1 column in metadata")

    print("  ✓ Empty result handled correctly")

    conn.close()
    print("  ✓ Test passed")


fn test_various_types() raises:
    """Test various PostgreSQL data types as text."""
    print("\nTest: Various Data Types")

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()
    var password = get_test_password()

    var conn = PostgresConnection(host, port)
    conn.connect(database, user, password)

    # Query with various types
    var result = conn.query("""
        SELECT
            42::INT4 AS int_val,
            3.14159::FLOAT8 AS float_val,
            TRUE::BOOL AS bool_val,
            'Hello, World!'::TEXT AS text_val,
            '2024-01-15'::DATE AS date_val
    """)

    print("  ✓ Query executed")
    print("  ✓ Columns:", String(result.column_count()))

    if result.column_count() != 5:
        raise Error("Expected 5 columns")

    # All values come as text in Simple Query Protocol
    print("  ✓ INT4:", result.get_value(0, 0))
    print("  ✓ FLOAT8:", result.get_value(0, 1))
    print("  ✓ BOOL:", result.get_value(0, 2))
    print("  ✓ TEXT:", result.get_value(0, 3))
    print("  ✓ DATE:", result.get_value(0, 4))

    conn.close()
    print("  ✓ Test passed")


fn test_query_error() raises:
    """Test handling of query errors."""
    print("\nTest: Query Error Handling")

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()
    var password = get_test_password()

    var conn = PostgresConnection(host, port)
    conn.connect(database, user, password)

    # Execute invalid SQL
    var got_error = False
    try:
        var result = conn.query("SELECT * FROM nonexistent_table_12345")
    except e:
        got_error = True
        print("  ✓ Caught error:", str(e))

    if not got_error:
        raise Error("Expected error for invalid query")

    print("  ✓ Error handling works")

    # Connection should still be usable
    var result2 = conn.query("SELECT 1")
    if result2.row_count() != 1:
        raise Error("Connection should still work after error")

    print("  ✓ Connection still usable after error")

    conn.close()
    print("  ✓ Test passed")


fn test_multiple_queries() raises:
    """Test executing multiple queries on same connection."""
    print("\nTest: Multiple Queries")

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()
    var password = get_test_password()

    var conn = PostgresConnection(host, port)
    conn.connect(database, user, password)

    # Execute 5 queries
    for i in range(5):
        var result = conn.query("SELECT " + String(i) + " AS num")

        if result.row_count() != 1:
            raise Error("Query " + String(i) + " failed")

        if result.get_value(0, 0) != String(i):
            raise Error("Query " + String(i) + " wrong value")

        print("  ✓ Query", String(i), "passed")

    conn.close()
    print("  ✓ Test passed")


fn test_command_complete() raises:
    """Test CommandComplete parsing for different commands."""
    print("\nTest: CommandComplete")

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()
    var password = get_test_password()

    var conn = PostgresConnection(host, port)
    conn.connect(database, user, password)

    # SELECT - rows returned
    var result1 = conn.query("SELECT 1 UNION SELECT 2 UNION SELECT 3")
    print("  ✓ SELECT tag:", result1.command_tag)
    print("  ✓ Rows affected:", String(result1.rows_affected))

    if result1.rows_affected != 3:
        raise Error("Expected 3 rows for SELECT")

    conn.close()
    print("  ✓ Test passed")


fn main() raises:
    print("\n" + "=" * 70)
    print("Running Integration Tests: PostgreSQL Query Protocol")
    print("=" * 70)

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()

    print("\nConnection Configuration:")
    print("  Host:     ", host)
    print("  Port:     ", String(port))
    print("  Database: ", database)
    print("  User:     ", user)
    print("\n" + "=" * 70)

    # Run tests
    var total_tests = 0
    var passed_tests = 0

    # Test 1: Simple SELECT
    total_tests += 1
    try:
        test_simple_select()
        passed_tests += 1
    except e:
        print("  FAILED:", str(e))

    # Test 2: Multiple rows
    total_tests += 1
    try:
        test_multiple_rows()
        passed_tests += 1
    except e:
        print("  FAILED:", str(e))

    # Test 3: NULL values
    total_tests += 1
    try:
        test_null_values()
        passed_tests += 1
    except e:
        print("  FAILED:", str(e))

    # Test 4: Empty result
    total_tests += 1
    try:
        test_empty_result()
        passed_tests += 1
    except e:
        print("  FAILED:", str(e))

    # Test 5: Various types
    total_tests += 1
    try:
        test_various_types()
        passed_tests += 1
    except e:
        print("  FAILED:", str(e))

    # Test 6: Query errors
    total_tests += 1
    try:
        test_query_error()
        passed_tests += 1
    except e:
        print("  FAILED:", str(e))

    # Test 7: Multiple queries
    total_tests += 1
    try:
        test_multiple_queries()
        passed_tests += 1
    except e:
        print("  FAILED:", str(e))

    # Test 8: CommandComplete
    total_tests += 1
    try:
        test_command_complete()
        passed_tests += 1
    except e:
        print("  FAILED:", str(e))

    # Summary
    print("\n" + "=" * 70)
    print("Test Summary")
    print("=" * 70)
    print("Total:  ", String(total_tests))
    print("Passed: ", String(passed_tests))
    print("Failed: ", String(total_tests - passed_tests))

    if passed_tests == total_tests:
        print("\n✅ All integration tests passed!")
    else:
        print("\n❌ Some tests failed")
        raise Error("Integration tests failed")

    print("=" * 70)
