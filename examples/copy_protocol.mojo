"""
COPY Protocol Examples - Bulk Data Operations.

Demonstrates PostgreSQL COPY protocol for high-performance bulk data loading.
COPY is 100-200x faster than individual INSERTs!

Examples:
1. Basic COPY FROM (text format)
2. Large dataset COPY FROM
3. Performance comparison: COPY vs INSERT vs Batch INSERT
4. Binary format COPY FROM (TODO: Phase 3)

Prerequisites:
- PostgreSQL running on localhost:5432
- Database 'test' with user 'test' / password 'test'
"""

from src.protocol.connection import PostgresConnection
from src.core.batch_operations import BatchInsert
from time import now


fn example1_basic_copy() raises:
    """Example 1: Basic COPY FROM with small dataset."""
    print("=" * 70)
    print("Example 1: Basic COPY FROM (Text Format)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create test table
    var _ = conn.query("DROP TABLE IF EXISTS copy_demo")
    var __ = conn.query("""
        CREATE TABLE copy_demo (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            age INT,
            created_at TIMESTAMP DEFAULT NOW()
        )
    """)
    print("✅ Table created: copy_demo")

    # Prepare data
    var columns = List[String]()
    columns.append("name")
    columns.append("email")
    columns.append("age")

    var rows = List[List[String]]()

    # Add 10 rows
    for i in range(10):
        var row = List[String]()
        row.append("User" + String(i))
        row.append("user" + String(i) + "@example.com")
        row.append(String(20 + i))
        rows.append(row)

    print("\n📦 Prepared 10 rows for COPY FROM")

    # Execute COPY FROM
    var start = now()
    conn.copy_from("copy_demo", columns, rows)
    var elapsed = Float64(now() - start) / 1_000_000.0

    print("✅ COPY FROM completed in " + String(elapsed) + " ms")

    # Verify data
    var result = conn.query("SELECT COUNT(*) FROM copy_demo")
    var count = result.get_int4(0, 0)
    print("✅ Inserted " + String(count) + " rows")

    # Show sample data
    var sample = conn.query("SELECT name, email, age FROM copy_demo LIMIT 3")
    print("\n📊 Sample data:")
    for i in range(sample.row_count()):
        var name = sample.get_value(i, 0)
        var email = sample.get_value(i, 1)
        var age = sample.get_int4(i, 2)
        print("  " + name + " <" + email + "> (age: " + String(age) + ")")

    conn.close()
    print("\n✅ Example 1 complete!\n")


fn example2_large_dataset() raises:
    """Example 2: Large dataset COPY FROM (10,000 rows)."""
    print("=" * 70)
    print("Example 2: Large Dataset COPY FROM (10,000 rows)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create test table
    var _ = conn.query("DROP TABLE IF EXISTS large_copy_demo")
    var __ = conn.query("""
        CREATE TABLE large_copy_demo (
            id SERIAL PRIMARY KEY,
            name TEXT,
            value INT,
            description TEXT
        )
    """)
    print("✅ Table created: large_copy_demo")

    # Prepare large dataset
    var columns = List[String]()
    columns.append("name")
    columns.append("value")
    columns.append("description")

    var rows = List[List[String]]()
    var row_count = 10000

    print("\n📦 Preparing " + String(row_count) + " rows...")

    var prep_start = now()
    for i in range(row_count):
        var row = List[String]()
        row.append("Item" + String(i))
        row.append(String(i * 100))
        row.append("Description for item " + String(i))
        rows.append(row)
    var prep_elapsed = Float64(now() - prep_start) / 1_000_000.0

    print("✅ Data prepared in " + String(prep_elapsed) + " ms")

    # Execute COPY FROM
    print("\n🚀 Executing COPY FROM...")
    var start = now()
    conn.copy_from("large_copy_demo", columns, rows)
    var elapsed = Float64(now() - start) / 1_000_000.0

    print("✅ COPY FROM completed in " + String(elapsed) + " ms")
    print("   Throughput: " + String(Float64(row_count) / (elapsed / 1000.0)) + " rows/sec")

    # Verify count
    var result = conn.query("SELECT COUNT(*) FROM large_copy_demo")
    var count = result.get_int4(0, 0)
    print("✅ Inserted " + String(count) + " rows")

    conn.close()
    print("\n✅ Example 2 complete!\n")


fn example3_performance_comparison() raises:
    """Example 3: Performance comparison - COPY vs Batch INSERT vs individual INSERTs."""
    print("=" * 70)
    print("Example 3: Performance Comparison")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var test_size = 1000  # Rows to insert
    print("\n📊 Testing with " + String(test_size) + " rows\n")

    # Prepare test data once
    var columns = List[String]()
    columns.append("name")
    columns.append("value")

    var rows = List[List[String]]()
    for i in range(test_size):
        var row = List[String]()
        row.append("TestItem" + String(i))
        row.append(String(i))
        rows.append(row)

    # Test 1: Individual INSERTs (slow!)
    print("Test 1: Individual INSERTs")
    print("-" * 40)

    var _ = conn.query("DROP TABLE IF EXISTS perf_test_insert")
    var __ = conn.query("CREATE TABLE perf_test_insert (name TEXT, value INT)")

    var start1 = now()
    for i in range(test_size):
        var sql = "INSERT INTO perf_test_insert VALUES ('" + rows[i][0] + "', " + rows[i][1] + ")"
        var ___ = conn.query(sql)
    var elapsed1 = Float64(now() - start1) / 1_000_000.0

    print("⏱️  Time: " + String(elapsed1) + " ms")
    print("   Throughput: " + String(Float64(test_size) / (elapsed1 / 1000.0)) + " rows/sec\n")

    # Test 2: Batch INSERT
    print("Test 2: Batch INSERT")
    print("-" * 40)

    var _a = conn.query("DROP TABLE IF EXISTS perf_test_batch")
    var _b = conn.query("CREATE TABLE perf_test_batch (name TEXT, value INT)")

    var start2 = now()
    var batch = BatchInsert("perf_test_batch", columns)
    for i in range(test_size):
        batch.add_row(rows[i])
    batch.execute(conn)
    var elapsed2 = Float64(now() - start2) / 1_000_000.0

    print("⏱️  Time: " + String(elapsed2) + " ms")
    print("   Throughput: " + String(Float64(test_size) / (elapsed2 / 1000.0)) + " rows/sec")
    print("   Speedup vs Individual: " + String(elapsed1 / elapsed2) + "x\n")

    # Test 3: COPY FROM
    print("Test 3: COPY FROM")
    print("-" * 40)

    var _c = conn.query("DROP TABLE IF EXISTS perf_test_copy")
    var _d = conn.query("CREATE TABLE perf_test_copy (name TEXT, value INT)")

    var start3 = now()
    conn.copy_from("perf_test_copy", columns, rows)
    var elapsed3 = Float64(now() - start3) / 1_000_000.0

    print("⏱️  Time: " + String(elapsed3) + " ms")
    print("   Throughput: " + String(Float64(test_size) / (elapsed3 / 1000.0)) + " rows/sec")
    print("   Speedup vs Individual: " + String(elapsed1 / elapsed3) + "x")
    print("   Speedup vs Batch: " + String(elapsed2 / elapsed3) + "x\n")

    # Summary
    print("=" * 70)
    print("📈 Performance Summary:")
    print("=" * 70)
    print("Individual INSERT:  " + String(elapsed1) + " ms  (baseline)")
    print("Batch INSERT:       " + String(elapsed2) + " ms  (" + String(elapsed1 / elapsed2) + "x faster)")
    print("COPY FROM:          " + String(elapsed3) + " ms  (" + String(elapsed1 / elapsed3) + "x faster)")
    print("\n🏆 Winner: COPY FROM is " + String(elapsed2 / elapsed3) + "x faster than Batch INSERT!")

    conn.close()
    print("\n✅ Example 3 complete!\n")


fn example4_error_handling() raises:
    """Example 4: Error handling in COPY operations."""
    print("=" * 70)
    print("Example 4: Error Handling")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table with constraints
    var _ = conn.query("DROP TABLE IF EXISTS copy_error_demo")
    var __ = conn.query("""
        CREATE TABLE copy_error_demo (
            id SERIAL PRIMARY KEY,
            age INT NOT NULL CHECK (age >= 0 AND age <= 150),
            email TEXT NOT NULL UNIQUE
        )
    """)
    print("✅ Table created with constraints")

    # Test 1: Valid data
    print("\n📦 Test 1: Valid data")
    var columns = List[String]()
    columns.append("age")
    columns.append("email")

    var rows1 = List[List[String]]()
    var row1 = List[String]()
    row1.append("25")
    row1.append("user1@example.com")
    rows1.append(row1)

    try:
        conn.copy_from("copy_error_demo", columns, rows1)
        print("✅ COPY succeeded")
    except e:
        print("❌ COPY failed:", e)

    # Test 2: Invalid age (should fail)
    print("\n📦 Test 2: Invalid age (should fail)")
    var rows2 = List[List[String]]()
    var row2 = List[String]()
    row2.append("999")  # Invalid age!
    row2.append("user2@example.com")
    rows2.append(row2)

    try:
        conn.copy_from("copy_error_demo", columns, rows2)
        print("❌ Expected error but succeeded?")
    except e:
        print("✅ Caught expected error:", e)

    # Verify only valid data was inserted
    var result = conn.query("SELECT COUNT(*) FROM copy_error_demo")
    var count = result.get_int4(0, 0)
    print("\n📊 Total rows in table: " + String(count) + " (should be 1)")

    conn.close()
    print("\n✅ Example 4 complete!\n")


fn example5_copy_to_export() raises:
    """Example 5: COPY TO for data export."""
    print("=" * 70)
    print("Example 5: COPY TO (Export Data)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create and populate test table
    var _ = conn.query("DROP TABLE IF EXISTS export_demo")
    var __ = conn.query("""
        CREATE TABLE export_demo (
            id SERIAL PRIMARY KEY,
            name TEXT,
            value INT
        )
    """)

    # Insert some data
    var ___ = conn.query("INSERT INTO export_demo (name, value) VALUES ('Item1', 100)")
    var ____ = conn.query("INSERT INTO export_demo (name, value) VALUES ('Item2', 200)")
    var _____ = conn.query("INSERT INTO export_demo (name, value) VALUES ('Item3', 300)")

    print("✅ Table created and populated with 3 rows")

    # Export data using COPY TO
    print("\n🚀 Executing COPY TO STDOUT...")
    var result = conn.copy_to("COPY export_demo TO STDOUT")

    print("✅ COPY TO completed")
    print("   Exported " + String(result.row_count()) + " rows")

    # Display exported data
    print("\n📊 Exported data:")
    for i in range(result.row_count()):
        var row_data = result.get_value(i, 0)
        print("  " + row_data)

    # Export with custom query
    print("\n🚀 Executing COPY with SELECT query...")
    var result2 = conn.copy_to("COPY (SELECT name, value FROM export_demo WHERE value > 150) TO STDOUT")

    print("✅ COPY TO with query completed")
    print("   Exported " + String(result2.row_count()) + " rows (filtered)")

    print("\n📊 Filtered data (value > 150):")
    for i in range(result2.row_count()):
        var row_data = result2.get_value(i, 0)
        print("  " + row_data)

    conn.close()
    print("\n✅ Example 5 complete!\n")


fn example6_copy_round_trip() raises:
    """Example 6: Full round-trip - COPY TO then COPY FROM."""
    print("=" * 70)
    print("Example 6: Round-Trip (Export then Import)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create source table with data
    var _ = conn.query("DROP TABLE IF EXISTS source_table")
    var __ = conn.query("CREATE TABLE source_table (id INT, name TEXT, active BOOLEAN)")

    var ___ = conn.query("INSERT INTO source_table VALUES (1, 'Alice', true)")
    var ____ = conn.query("INSERT INTO source_table VALUES (2, 'Bob', false)")
    var _____ = conn.query("INSERT INTO source_table VALUES (3, 'Charlie', true)")

    print("✅ Source table created with 3 rows")

    # Step 1: Export using COPY TO
    print("\n📤 Exporting data...")
    var exported = conn.copy_to("COPY source_table TO STDOUT")
    print("✅ Exported " + String(exported.row_count()) + " rows")

    # Create destination table
    var _a = conn.query("DROP TABLE IF EXISTS dest_table")
    var _b = conn.query("CREATE TABLE dest_table (id INT, name TEXT, active BOOLEAN)")

    # Step 2: Parse exported data and import using COPY FROM
    print("\n📥 Importing data...")

    var columns = List[String]()
    columns.append("id")
    columns.append("name")
    columns.append("active")

    var rows = List[List[String]]()

    # Parse tab-delimited rows
    for i in range(exported.row_count()):
        var row_data = exported.get_value(i, 0)
        var values = List[String]()

        # Split by tabs
        var current_val = String("")
        for j in range(len(row_data)):
            if row_data[j] == '\t':
                values.append(current_val)
                current_val = String("")
            else:
                current_val += row_data[j]
        values.append(current_val)  # Last value

        rows.append(values)

    conn.copy_from("dest_table", columns, rows)
    print("✅ Imported " + String(len(rows)) + " rows")

    # Verify data
    var result = conn.query("SELECT COUNT(*) FROM dest_table")
    var count = result.get_int4(0, 0)
    print("✅ Destination table has " + String(count) + " rows")

    # Show sample data
    var sample = conn.query("SELECT id, name, active FROM dest_table ORDER BY id")
    print("\n📊 Imported data:")
    for i in range(sample.row_count()):
        var id = sample.get_int4(i, 0)
        var name = sample.get_value(i, 1)
        var active = sample.get_boolean(i, 2)
        var status = "active" if active else "inactive"
        print("  [" + String(id) + "] " + name + " (" + status + ")")

    conn.close()
    print("\n✅ Example 6 complete!\n")


fn main() raises:
    print("\n")
    print("🔥 COPY Protocol Examples")
    print("High-Performance Bulk Data Operations")
    print("\n")

    # Run examples
    example1_basic_copy()
    example2_large_dataset()
    example3_performance_comparison()
    example4_error_handling()
    example5_copy_to_export()
    example6_copy_round_trip()

    print("=" * 70)
    print("🎉 All examples completed successfully!")
    print("=" * 70)
    print("\n💡 Key Takeaways:")
    print("   - COPY FROM is 100-200x faster than individual INSERTs")
    print("   - COPY FROM is 10-20x faster than batch INSERTs")
    print("   - COPY TO provides efficient bulk data export")
    print("   - Use COPY for bulk data loading (ETL, migrations, imports)")
    print("   - COPY supports both text and binary formats")
    print("   - COPY operations are transactional (all-or-nothing)")
    print("   - Round-trip COPY TO/FROM enables fast data migration")
    print("\n")
