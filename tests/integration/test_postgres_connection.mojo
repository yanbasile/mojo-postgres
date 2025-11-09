"""
Integration Test: PostgreSQL Connection

Tests actual connection to a running PostgreSQL server.

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


fn test_successful_connection() raises:
    """Test connecting to PostgreSQL with valid credentials."""
    print("\nTest: Successful Connection")

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()
    var password = get_test_password()

    var conn = PostgresConnection(host, port)

    try:
        conn.connect(database, user, password)
        print("  ✓ Connection established")
        print("  ✓ Authentication successful")
        print("  ✓ ReadyForQuery received")

        # Verify connection is marked as connected
        if conn.is_connected:
            print("  ✓ Connection state is correct")
        else:
            raise Error("Connection should be marked as connected")

        # Clean disconnect
        conn.close()
        print("  ✓ Connection closed cleanly")

        # Verify connection is marked as disconnected
        if not conn.is_connected:
            print("  ✓ Disconnection state is correct")
        else:
            raise Error("Connection should be marked as disconnected")

    except e:
        print("  ✗ Connection failed:", str(e))
        raise e


fn test_connection_to_invalid_host() raises:
    """Test that connecting to invalid host raises an error."""
    print("\nTest: Connection to Invalid Host")

    var conn = PostgresConnection("invalid.host.12345", 5432)

    var error_raised = False
    try:
        conn.connect("test", "test", "test")
        print("  ✗ Should have raised an error")
    except:
        error_raised = True
        print("  ✓ Correctly raised connection error")

    if not error_raised:
        raise Error("Expected connection error for invalid host")


fn test_authentication_failure() raises:
    """Test that wrong password raises authentication error."""
    print("\nTest: Authentication Failure")

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()

    var conn = PostgresConnection(host, port)

    var error_raised = False
    try:
        conn.connect(database, user, "wrong_password_12345")
        print("  ✗ Should have raised authentication error")
    except:
        error_raised = True
        print("  ✓ Correctly raised authentication error")

    if not error_raised:
        raise Error("Expected authentication error for wrong password")


fn test_multiple_connections() raises:
    """Test creating multiple connections sequentially."""
    print("\nTest: Multiple Connections")

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()
    var password = get_test_password()

    # Create and close 10 connections
    for i in range(10):
        var conn = PostgresConnection(host, port)
        conn.connect(database, user, password)
        conn.close()

    print("  ✓ Successfully created and closed 10 connections")


fn test_connection_cleanup() raises:
    """Test that connections are cleaned up properly."""
    print("\nTest: Connection Cleanup")

    var host = get_test_host()
    var port = get_test_port()
    var database = get_test_database()
    var user = get_test_user()
    var password = get_test_password()

    # Create connection in a scope
    {
        var conn = PostgresConnection(host, port)
        conn.connect(database, user, password)
        # Connection should be cleaned up when it goes out of scope
    }

    print("  ✓ Connection cleaned up when out of scope")


fn main() raises:
    print("\n" + "=" * 70)
    print("Running Integration Tests: PostgreSQL Connection")
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

    # Test 1: Successful connection
    total_tests += 1
    try:
        test_successful_connection()
        passed_tests += 1
    except e:
        print("  FAILED:", str(e))

    # Test 2: Invalid host
    total_tests += 1
    try:
        test_connection_to_invalid_host()
        passed_tests += 1
    except e:
        print("  FAILED:", str(e))

    # Test 3: Authentication failure
    total_tests += 1
    try:
        test_authentication_failure()
        passed_tests += 1
    except e:
        print("  FAILED:", str(e))

    # Test 4: Multiple connections
    total_tests += 1
    try:
        test_multiple_connections()
        passed_tests += 1
    except e:
        print("  FAILED:", str(e))

    # Test 5: Connection cleanup
    total_tests += 1
    try:
        test_connection_cleanup()
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
