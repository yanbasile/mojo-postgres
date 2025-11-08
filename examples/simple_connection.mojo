"""
Example: Simple PostgreSQL Connection

Demonstrates how to:
1. Connect to PostgreSQL
2. Handle connection errors
3. Disconnect cleanly

Prerequisites:
Run PostgreSQL locally:
  docker run -d -p 5432:5432 \
    -e POSTGRES_PASSWORD=test \
    -e POSTGRES_USER=test \
    -e POSTGRES_DB=test \
    postgres:16
"""

from src.protocol.connection import PostgresConnection


fn example_basic_connection() raises:
    """
    Basic connection example.

    This is the simplest way to connect to PostgreSQL.
    """
    print("\n" + "=" * 70)
    print("Example 1: Basic Connection")
    print("=" * 70)

    # Create connection
    var conn = PostgresConnection("localhost", 5432)

    # Connect to database
    print("Connecting to PostgreSQL...")
    conn.connect(
        database="test",
        user="test",
        password="test"
    )

    print("✅ Connected successfully!")
    print("  Host:     ", conn.host)
    print("  Port:     ", String(conn.port))
    print("  Database: ", conn.database)
    print("  User:     ", conn.user)

    # Close connection
    conn.close()
    print("✅ Connection closed")


fn example_error_handling() raises:
    """
    Connection with error handling.

    Shows how to handle connection errors gracefully.
    """
    print("\n" + "=" * 70)
    print("Example 2: Error Handling")
    print("=" * 70)

    # Try to connect with wrong password
    var conn = PostgresConnection("localhost", 5432)

    print("Attempting connection with wrong password...")
    try:
        conn.connect(
            database="test",
            user="test",
            password="wrong_password"
        )
        print("❌ This shouldn't happen!")
    except e:
        print("✅ Caught authentication error (as expected):")
        print("   ", str(e))


fn example_connection_parameters() raises:
    """
    Connection with custom parameters.

    Shows different ways to specify connection parameters.
    """
    print("\n" + "=" * 70)
    print("Example 3: Connection Parameters")
    print("=" * 70)

    # Custom host and port
    var conn1 = PostgresConnection("localhost", 5432)
    print("Connection 1: Custom host and port")
    print("  Host: localhost")
    print("  Port: 5432")

    # Different database
    var conn2 = PostgresConnection("localhost", 5432)
    print("\nConnection 2: Different database")
    try:
        conn2.connect("mydb", "myuser", "mypass")
    except:
        print("  (Database 'mydb' doesn't exist - that's OK)")

    # Remote host (example)
    var conn3 = PostgresConnection("db.example.com", 5432)
    print("\nConnection 3: Remote host")
    print("  Host: db.example.com")
    print("  Port: 5432")
    print("  (Not connecting - just an example)")


fn example_resource_management() raises:
    """
    Automatic resource cleanup.

    Mojo's ownership system ensures connections are closed
    when they go out of scope.
    """
    print("\n" + "=" * 70)
    print("Example 4: Resource Management")
    print("=" * 70)

    print("Creating connection in a scope...")

    # Connection will be automatically closed when scope ends
    {
        var conn = PostgresConnection("localhost", 5432)
        conn.connect("test", "test", "test")
        print("  ✅ Connected inside scope")
        # No need to manually close - will be cleaned up automatically
    }

    print("  ✅ Connection automatically closed when leaving scope")


fn example_multiple_connections() raises:
    """
    Multiple connections.

    Shows how to manage multiple database connections.
    """
    print("\n" + "=" * 70)
    print("Example 5: Multiple Connections")
    print("=" * 70)

    print("Creating 5 connections...")

    # Create multiple connections
    for i in range(5):
        var conn = PostgresConnection("localhost", 5432)
        conn.connect("test", "test", "test")
        print("  ✅ Connection", String(i + 1), "established")
        conn.close()

    print("✅ All connections closed")


fn main() raises:
    print("\n" + "=" * 70)
    print("mojo-postgres: Connection Examples")
    print("=" * 70)
    print("These examples demonstrate basic PostgreSQL connection usage.")
    print("=" * 70)

    # Example 1: Basic connection
    example_basic_connection()

    # Example 2: Error handling
    example_error_handling()

    # Example 3: Connection parameters
    example_connection_parameters()

    # Example 4: Resource management
    example_resource_management()

    # Example 5: Multiple connections
    example_multiple_connections()

    # Summary
    print("\n" + "=" * 70)
    print("Summary")
    print("=" * 70)
    print("✅ All examples completed successfully!")
    print("")
    print("Next steps:")
    print("  1. Try modifying the connection parameters")
    print("  2. Test with your own PostgreSQL instance")
    print("  3. Explore authentication methods (cleartext vs MD5)")
    print("  4. Check out the benchmarks to see performance")
    print("  5. Look at integration tests for more examples")
    print("")
    print("For more information:")
    print("  - README.md: Project overview")
    print("  - docs/ARCHITECTURE.md: Technical details")
    print("  - benchmarks/: Performance comparisons")
    print("  - tests/: Unit and integration tests")
    print("=" * 70)
