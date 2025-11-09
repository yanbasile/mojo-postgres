"""
Example: PostgreSQL Simple Query Protocol

Demonstrates how to:
1. Execute SELECT queries
2. Handle query results
3. Work with different data types
4. Handle NULL values
5. Execute INSERT/UPDATE/DELETE
6. Handle query errors

Prerequisites:
Run PostgreSQL locally:
  docker run -d -p 5432:5432 \
    -e POSTGRES_PASSWORD=test \
    -e POSTGRES_USER=test \
    -e POSTGRES_DB=test \
    postgres:16
"""

from src.protocol.connection import PostgresConnection


fn example_simple_select() raises:
    """Example 1: Simple SELECT query."""
    print("\n" + "=" * 70)
    print("Example 1: Simple SELECT")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Execute query
    var result = conn.query("SELECT 1 AS num, 'Hello, Mojo!' AS text")

    print("Query executed successfully!")
    print("Columns: ", String(result.column_count()))
    print("Rows:    ", String(result.row_count()))
    print("")

    # Access column metadata
    print("Column names:")
    for i in range(result.column_count()):
        print("  [", String(i), "] ", result.get_column_name(i))

    print("")

    # Access data
    print("Data:")
    for row_idx in range(result.row_count()):
        print("  Row", String(row_idx), ":")
        for col_idx in range(result.column_count()):
            if result.is_null(row_idx, col_idx):
                print("    ", result.get_column_name(col_idx), ": NULL")
            else:
                print("    ", result.get_column_name(col_idx), ": ", result.get_value(row_idx, col_idx))

    conn.close()
    print("\n Example 1 complete")


fn example_multiple_rows() raises:
    """Example 2: Query with multiple rows."""
    print("\n" + "=" * 70)
    print("Example 2: Multiple Rows")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query that returns multiple rows
    var result = conn.query("""
        SELECT * FROM (VALUES
            (1, 'Alice', 'Engineer'),
            (2, 'Bob', 'Designer'),
            (3, 'Charlie', 'Manager')
        ) AS users(id, name, role)
    """)

    print("Retrieved", String(result.row_count()), "users")
    print("")

    # Print results in table format
    print("ID  | Name    | Role")
    print("----+---------+-----------")
    for row_idx in range(result.row_count()):
        var id = result.get_value(row_idx, 0)
        var name = result.get_value(row_idx, 1)
        var role = result.get_value(row_idx, 2)
        print(id, "   | ", name, " | ", role)

    conn.close()
    print("\n Example 2 complete")


fn example_data_types() raises:
    """Example 3: Working with different data types."""
    print("\n" + "=" * 70)
    print("Example 3: Data Types")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query with various PostgreSQL types
    # Note: In Simple Query Protocol, all values come back as text
    var result = conn.query("""
        SELECT
            42::INT4 AS integer,
            3.14159::FLOAT8 AS float,
            TRUE::BOOL AS boolean,
            'Hello'::TEXT AS text,
            '2024-01-15'::DATE AS date,
            '{"key": "value"}'::JSONB AS json
    """)

    print("PostgreSQL types (as text in Simple Query Protocol):")
    print("")

    for i in range(result.column_count()):
        var col_name = result.get_column_name(i)
        var col_value = result.get_value(0, i)
        print("  ", col_name, ": ", col_value)

    print("")
    print("Note: In Simple Query Protocol, all values are returned as text.")
    print("Extended Query Protocol (Phase 2) will support binary formats.")

    conn.close()
    print("\n Example 3 complete")


fn example_null_handling() raises:
    """Example 4: Handling NULL values."""
    print("\n" + "=" * 70)
    print("Example 4: NULL Values")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query with NULL values
    var result = conn.query("""
        SELECT * FROM (VALUES
            (1, 'Alice', 'alice@example.com'),
            (2, 'Bob', NULL),
            (3, 'Charlie', 'charlie@example.com')
        ) AS users(id, name, email)
    """)

    print("User data (some emails are NULL):")
    print("")

    for row_idx in range(result.row_count()):
        var id = result.get_value(row_idx, 0)
        var name = result.get_value(row_idx, 1)

        print("User #", id, " - ", name)

        # Check if email is NULL before accessing
        if result.is_null(row_idx, 2):
            print("  Email: <not provided>")
        else:
            print("  Email:", result.get_value(row_idx, 2))

    conn.close()
    print("\n Example 4 complete")


fn example_insert_update_delete() raises:
    """Example 5: INSERT, UPDATE, DELETE operations."""
    print("\n" + "=" * 70)
    print("Example 5: Data Modification")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create a temporary table
    var create_result = conn.query("""
        CREATE TEMPORARY TABLE demo_users (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            active BOOLEAN DEFAULT TRUE
        )
    """)
    print(" Created temporary table:", create_result.command_tag)

    # INSERT
    var insert_result = conn.query("""
        INSERT INTO demo_users (name) VALUES ('Alice'), ('Bob'), ('Charlie')
    """)
    print(" Inserted rows:", String(insert_result.rows_affected))

    # SELECT to verify
    var select_result = conn.query("SELECT * FROM demo_users")
    print(" Users in table:", String(select_result.row_count()))

    # UPDATE
    var update_result = conn.query("UPDATE demo_users SET active = FALSE WHERE name = 'Bob'")
    print(" Updated rows:", String(update_result.rows_affected))

    # DELETE
    var delete_result = conn.query("DELETE FROM demo_users WHERE name = 'Charlie'")
    print(" Deleted rows:", String(delete_result.rows_affected))

    # Final SELECT
    var final_result = conn.query("SELECT name, active FROM demo_users")
    print(" Final users:")
    for row_idx in range(final_result.row_count()):
        print("  -", final_result.get_value(row_idx, 0), "(active:", final_result.get_value(row_idx, 1), ")")

    conn.close()
    print("\n Example 5 complete")


fn example_error_handling() raises:
    """Example 6: Error handling."""
    print("\n" + "=" * 70)
    print("Example 6: Error Handling")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Try an invalid query
    print("Attempting invalid query...")
    try:
        var result = conn.query("SELECT * FROM nonexistent_table")
        print("L This shouldn't happen!")
    except e:
        print(" Caught error:", str(e))

    # Connection should still work
    print("\nTrying valid query after error...")
    var result = conn.query("SELECT 'Connection still works!' AS message")
    print("", result.get_value(0, 0))

    conn.close()
    print("\n Example 6 complete")


fn main() raises:
    print("\n" + "=" * 70)
    print("mojo-postgres: Simple Query Examples")
    print("=" * 70)
    print("These examples demonstrate PostgreSQL query execution.")
    print("=" * 70)

    # Run examples
    example_simple_select()
    example_multiple_rows()
    example_data_types()
    example_null_handling()
    example_insert_update_delete()
    example_error_handling()

    # Summary
    print("\n" + "=" * 70)
    print("Summary")
    print("=" * 70)
    print(" All examples completed successfully!")
    print("")
    print("You've learned how to:")
    print("  1. Execute SELECT queries")
    print("  2. Handle multiple rows")
    print("  3. Work with different data types")
    print("  4. Handle NULL values")
    print("  5. Execute INSERT/UPDATE/DELETE")
    print("  6. Handle query errors")
    print("")
    print("Next steps:")
    print("  - Check out benchmarks/ for performance testing")
    print("  - See ROADMAP.md for upcoming features")
    print("")
    print("For production use:")
    print("     Use connection pooling (Phase 2)")
    print("     Use prepared statements (Phase 2)")
    print("     Enable SSL/TLS for remote connections (Phase 2)")
    print("=" * 70)
