"""
PostgreSQL Array Types Examples.

Demonstrates array type support for efficient handling of multi-value columns.

Array Types Supported:
- INT2[] (SMALLINT[])
- INT4[] (INTEGER[])
- INT8[] (BIGINT[])
- FLOAT4[] (REAL[])
- FLOAT8[] (DOUBLE PRECISION[])
- TEXT[]
- VARCHAR[]
- BOOLEAN[]

Examples:
1. Basic array queries (SELECT with arrays)
2. Array INSERT operations
3. Arrays with NULL elements
4. Multi-dimensional arrays
5. Array operations (length, unnest, contains)
6. Practical use cases (tags, categories, metrics)

Prerequisites:
- PostgreSQL running on localhost:5432
- Database 'test' with user 'test' / password 'test'
"""

from src.protocol.connection import PostgresConnection
from src.types.array_types import build_int4_array_literal, build_text_array_literal, build_bool_array_literal
from collections import List


fn example1_basic_array_select() raises:
    """Example 1: Basic array SELECT operations."""
    print("=" * 70)
    print("Example 1: Basic Array SELECT")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")
    print("✅ Connected to PostgreSQL")

    # Integer array
    print("\n1️⃣  Integer Array (INT4[]):")
    var result1 = conn.query("SELECT ARRAY[1,2,3,4,5]::INT4[]")
    var int_arr = result1.get_int4_array(0, 0)
    print("   Query: SELECT ARRAY[1,2,3,4,5]::INT4[]")
    print("   Result:", int_arr.to_string())
    print("   Length:", int_arr.length())
    print("   First element:", int_arr.get(0))
    print("   Last element:", int_arr.get(int_arr.length() - 1))

    # Text array
    print("\n2️⃣  Text Array (TEXT[]):")
    var result2 = conn.query("SELECT ARRAY['apple', 'banana', 'cherry']::TEXT[]")
    var text_arr = result2.get_text_array(0, 0)
    print("   Query: SELECT ARRAY['apple', 'banana', 'cherry']::TEXT[]")
    print("   Result:", text_arr.to_string())
    print("   Length:", text_arr.length())

    # Boolean array
    print("\n3️⃣  Boolean Array (BOOLEAN[]):")
    var result3 = conn.query("SELECT ARRAY[true, false, true, true]::BOOLEAN[]")
    var bool_arr = result3.get_bool_array(0, 0)
    print("   Query: SELECT ARRAY[true, false, true, true]::BOOLEAN[]")
    print("   Result:", bool_arr.to_string())

    # Float array
    print("\n4️⃣  Float Array (FLOAT8[]):")
    var result4 = conn.query("SELECT ARRAY[1.5, 2.7, 3.14159, 9.99]::FLOAT8[]")
    var float_arr = result4.get_float8_array(0, 0)
    print("   Query: SELECT ARRAY[1.5, 2.7, 3.14159, 9.99]::FLOAT8[]")
    print("   Result:", float_arr.to_string())

    # Bigint array
    print("\n5️⃣  BigInt Array (INT8[]):")
    var result5 = conn.query("SELECT ARRAY[1000000000, 2000000000, 3000000000]::INT8[]")
    var bigint_arr = result5.get_int8_array(0, 0)
    print("   Query: SELECT ARRAY[1000000000, 2000000000, 3000000000]::INT8[]")
    print("   Result:", bigint_arr.to_string())

    conn.close()
    print("\n✅ Example 1 complete!\n")


fn example2_array_insert() raises:
    """Example 2: INSERT with array values."""
    print("=" * 70)
    print("Example 2: Array INSERT Operations")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table with array columns
    print("\n📝 Creating table with array columns...")
    var _ = conn.query("DROP TABLE IF EXISTS products")
    var __ = conn.query("""
        CREATE TABLE products (
            id SERIAL PRIMARY KEY,
            name TEXT,
            tags TEXT[],
            prices FLOAT8[],
            ratings INT4[]
        )
    """)
    print("✅ Table created: products (id, name, tags[], prices[], ratings[])")

    # Insert using array literals
    print("\n📥 Inserting products with arrays...")

    var ___ = conn.query("""
        INSERT INTO products (name, tags, prices, ratings)
        VALUES (
            'Laptop',
            ARRAY['electronics', 'computers', 'portable'],
            ARRAY[999.99, 1299.99, 1499.99],
            ARRAY[5, 4, 5, 5, 4]
        )
    """)
    print("✅ Inserted: Laptop with 3 tags, 3 prices, 5 ratings")

    var ____ = conn.query("""
        INSERT INTO products (name, tags, prices, ratings)
        VALUES (
            'Book',
            ARRAY['education', 'paperback', 'bestseller'],
            ARRAY[19.99, 24.99],
            ARRAY[5, 5, 4, 5]
        )
    """)
    print("✅ Inserted: Book with 3 tags, 2 prices, 4 ratings")

    var _____ = conn.query("""
        INSERT INTO products (name, tags, prices, ratings)
        VALUES (
            'Coffee Maker',
            ARRAY['appliances', 'kitchen', 'small'],
            ARRAY[49.99, 59.99, 69.99, 79.99],
            ARRAY[4, 4, 5, 4, 3]
        )
    """)
    print("✅ Inserted: Coffee Maker with 3 tags, 4 prices, 5 ratings")

    # Query and display results
    print("\n📊 Querying products...")
    var result = conn.query("SELECT id, name, tags, prices, ratings FROM products ORDER BY id")

    print("\nProducts in database:")
    for row in range(result.row_count()):
        var product_id = result.get_int32(row, 0)
        var product_name = result.get_string(row, 1)
        var tags = result.get_text_array(row, 2)
        var prices = result.get_float8_array(row, 3)
        var ratings = result.get_int4_array(row, 4)

        print(f"\n  Product #{product_id}: {product_name}")
        print(f"    Tags: {tags.to_string()}")
        print(f"    Prices: {prices.to_string()}")
        print(f"    Ratings: {ratings.to_string()}")
        print(f"    Avg Rating: {calculate_average(ratings)}")

    # Cleanup
    var ______ = conn.query("DROP TABLE products")

    conn.close()
    print("\n✅ Example 2 complete!\n")


fn calculate_average(arr: Int4Array) -> Float64:
    """Calculate average of integer array."""
    if arr.length() == 0:
        return 0.0

    var sum: Int64 = 0
    for i in range(arr.length()):
        sum += Int64(arr.get(i))

    return Float64(sum) / Float64(arr.length())


fn example3_null_elements() raises:
    """Example 3: Arrays with NULL elements."""
    print("=" * 70)
    print("Example 3: Arrays with NULL Elements")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table with nullable array elements
    print("\n📝 Creating table with array columns...")
    var _ = conn.query("DROP TABLE IF EXISTS measurements")
    var __ = conn.query("""
        CREATE TABLE measurements (
            id SERIAL PRIMARY KEY,
            sensor_name TEXT,
            values INT4[]
        )
    """)
    print("✅ Table created: measurements")

    # Insert with NULL elements
    print("\n📥 Inserting measurements with NULL values...")
    var ___ = conn.query("""
        INSERT INTO measurements (sensor_name, values)
        VALUES ('Temperature', ARRAY[20, 21, NULL, 23, NULL, 25])
    """)
    print("✅ Inserted: Temperature readings with NULLs (missing data)")

    var ____ = conn.query("""
        INSERT INTO measurements (sensor_name, values)
        VALUES ('Humidity', ARRAY[65, NULL, 70, 72, NULL])
    """)
    print("✅ Inserted: Humidity readings with NULLs")

    # Query and display
    print("\n📊 Querying measurements...")
    var result = conn.query("SELECT sensor_name, values FROM measurements ORDER BY id")

    for row in range(result.row_count()):
        var sensor = result.get_string(row, 0)
        var values = result.get_int4_array(row, 1)

        print(f"\n  {sensor}:")
        print(f"    Values: {values.to_string()}")
        print(f"    Has NULLs: {values.has_nulls}")
        print(f"    Length: {values.length()}")

    # Cleanup
    var _____ = conn.query("DROP TABLE measurements")

    conn.close()
    print("\n✅ Example 3 complete!\n")


fn example4_multi_dimensional_arrays() raises:
    """Example 4: Multi-dimensional arrays."""
    print("=" * 70)
    print("Example 4: Multi-Dimensional Arrays")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # 2D array (matrix)
    print("\n1️⃣  2D Integer Array (Matrix):")
    var result1 = conn.query("SELECT ARRAY[[1,2,3],[4,5,6],[7,8,9]]::INT4[]")
    print("   Query: SELECT ARRAY[[1,2,3],[4,5,6],[7,8,9]]::INT4[]")
    print("   Note: PostgreSQL flattens multi-dimensional arrays in text format")
    var matrix = result1.get_value(0, 0)
    print("   Raw value:", matrix)

    # 2D text array
    print("\n2️⃣  2D Text Array:")
    var result2 = conn.query("SELECT ARRAY[['a','b'],['c','d']]::TEXT[]")
    print("   Query: SELECT ARRAY[['a','b'],['c','d']]::TEXT[]")
    var text_matrix = result2.get_value(0, 0)
    print("   Raw value:", text_matrix)

    conn.close()
    print("\n✅ Example 4 complete!\n")


fn example5_array_operations() raises:
    """Example 5: PostgreSQL array operations."""
    print("=" * 70)
    print("Example 5: Array Operations")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # array_length
    print("\n1️⃣  array_length():")
    var result1 = conn.query("SELECT array_length(ARRAY[1,2,3,4,5], 1)")
    var length = result1.get_int32(0, 0)
    print("   Query: SELECT array_length(ARRAY[1,2,3,4,5], 1)")
    print("   Length:", length)

    # array_append
    print("\n2️⃣  array_append():")
    var result2 = conn.query("SELECT array_append(ARRAY[1,2,3], 4)")
    var appended = result2.get_int4_array(0, 0)
    print("   Query: SELECT array_append(ARRAY[1,2,3], 4)")
    print("   Result:", appended.to_string())

    # array_prepend
    print("\n3️⃣  array_prepend():")
    var result3 = conn.query("SELECT array_prepend(0, ARRAY[1,2,3])")
    var prepended = result3.get_int4_array(0, 0)
    print("   Query: SELECT array_prepend(0, ARRAY[1,2,3])")
    print("   Result:", prepended.to_string())

    # array_cat (concatenate)
    print("\n4️⃣  array_cat() - Concatenate arrays:")
    var result4 = conn.query("SELECT array_cat(ARRAY[1,2,3], ARRAY[4,5,6])")
    var concatenated = result4.get_int4_array(0, 0)
    print("   Query: SELECT array_cat(ARRAY[1,2,3], ARRAY[4,5,6])")
    print("   Result:", concatenated.to_string())

    # ANY operator (check if value in array)
    print("\n5️⃣  ANY operator - Check if value in array:")
    var result5 = conn.query("SELECT 3 = ANY(ARRAY[1,2,3,4,5])")
    var contains = result5.get_bool(0, 0)
    print("   Query: SELECT 3 = ANY(ARRAY[1,2,3,4,5])")
    print("   Contains 3:", contains)

    # unnest (expand array to rows)
    print("\n6️⃣  unnest() - Expand array to rows:")
    var result6 = conn.query("SELECT unnest(ARRAY['apple', 'banana', 'cherry'])")
    print("   Query: SELECT unnest(ARRAY['apple', 'banana', 'cherry'])")
    print("   Rows returned:", result6.row_count())
    for row in range(result6.row_count()):
        print("     -", result6.get_string(row, 0))

    # array_agg (aggregate values into array)
    print("\n7️⃣  array_agg() - Aggregate values into array:")
    var result7 = conn.query("SELECT array_agg(x) FROM generate_series(1, 5) AS x")
    var aggregated = result7.get_int4_array(0, 0)
    print("   Query: SELECT array_agg(x) FROM generate_series(1, 5) AS x")
    print("   Result:", aggregated.to_string())

    conn.close()
    print("\n✅ Example 5 complete!\n")


fn example6_practical_use_cases() raises:
    """Example 6: Practical use cases for arrays."""
    print("=" * 70)
    print("Example 6: Practical Use Cases")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Use Case 1: Tags/Categories
    print("\n📌 Use Case 1: Tags and Categories")
    var _ = conn.query("DROP TABLE IF EXISTS blog_posts")
    var __ = conn.query("""
        CREATE TABLE blog_posts (
            id SERIAL PRIMARY KEY,
            title TEXT,
            tags TEXT[]
        )
    """)

    var ___ = conn.query("""
        INSERT INTO blog_posts (title, tags) VALUES
        ('Intro to PostgreSQL', ARRAY['database', 'tutorial', 'postgresql']),
        ('Mojo Programming', ARRAY['mojo', 'programming', 'tutorial']),
        ('Array Types Guide', ARRAY['postgresql', 'arrays', 'database'])
    """)

    print("✅ Created blog_posts table with tags")

    # Find posts with specific tag
    var result1 = conn.query("SELECT title, tags FROM blog_posts WHERE 'postgresql' = ANY(tags)")
    print("\n📝 Posts tagged 'postgresql':")
    for row in range(result1.row_count()):
        var title = result1.get_string(row, 0)
        var tags = result1.get_text_array(row, 1)
        print(f"   - {title}")
        print(f"     Tags: {tags.to_string()}")

    # Use Case 2: Time-series data
    print("\n📊 Use Case 2: Time-Series Metrics")
    var ____ = conn.query("DROP TABLE IF EXISTS server_metrics")
    var _____ = conn.query("""
        CREATE TABLE server_metrics (
            id SERIAL PRIMARY KEY,
            server_name TEXT,
            cpu_usage FLOAT8[],
            memory_usage FLOAT8[],
            hour INT4
        )
    """)

    var ______ = conn.query("""
        INSERT INTO server_metrics (server_name, cpu_usage, memory_usage, hour) VALUES
        ('web-01', ARRAY[45.2, 50.1, 48.9, 52.3, 49.7], ARRAY[60.1, 62.3, 61.8, 63.2, 62.9], 1),
        ('web-02', ARRAY[38.5, 40.2, 39.8, 41.1, 40.5], ARRAY[55.3, 56.1, 55.9, 57.2, 56.8], 1)
    """)

    print("✅ Created server_metrics table with array metrics")

    var result2 = conn.query("SELECT server_name, cpu_usage, memory_usage FROM server_metrics")
    print("\n💻 Server Metrics (5-minute intervals):")
    for row in range(result2.row_count()):
        var server = result2.get_string(row, 0)
        var cpu = result2.get_float8_array(row, 1)
        var memory = result2.get_float8_array(row, 2)

        print(f"\n   Server: {server}")
        print(f"     CPU Usage: {cpu.to_string()}")
        print(f"     Memory Usage: {memory.to_string()}")
        print(f"     Avg CPU: {calculate_float_average(cpu):.1f}%")
        print(f"     Avg Memory: {calculate_float_average(memory):.1f}%")

    # Use Case 3: Permissions/Roles
    print("\n🔐 Use Case 3: User Permissions")
    var _______ = conn.query("DROP TABLE IF EXISTS users")
    var ________ = conn.query("""
        CREATE TABLE users (
            id SERIAL PRIMARY KEY,
            username TEXT,
            permissions TEXT[]
        )
    """)

    var _________ = conn.query("""
        INSERT INTO users (username, permissions) VALUES
        ('alice', ARRAY['read', 'write', 'delete']),
        ('bob', ARRAY['read', 'write']),
        ('charlie', ARRAY['read'])
    """)

    var result3 = conn.query("SELECT username, permissions FROM users ORDER BY id")
    print("\n👥 User Permissions:")
    for row in range(result3.row_count()):
        var username = result3.get_string(row, 0)
        var perms = result3.get_text_array(row, 1)
        print(f"   {username}: {perms.to_string()}")

    # Cleanup
    var __________ = conn.query("DROP TABLE blog_posts")
    var ___________ = conn.query("DROP TABLE server_metrics")
    var ____________ = conn.query("DROP TABLE users")

    conn.close()
    print("\n✅ Example 6 complete!\n")


fn calculate_float_average(arr: Float8Array) -> Float64:
    """Calculate average of float array."""
    if arr.length() == 0:
        return 0.0

    var sum: Float64 = 0.0
    for i in range(arr.length()):
        sum += arr.get(i)

    return sum / Float64(arr.length())


fn example7_array_literal_builders() raises:
    """Example 7: Using array literal builder functions."""
    print("=" * 70)
    print("Example 7: Array Literal Builders")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    print("\n🔧 Building SQL array literals from Mojo Lists...")

    # Build INT4[] literal
    var int_list = List[Int32]()
    int_list.append(10)
    int_list.append(20)
    int_list.append(30)
    var int_literal = build_int4_array_literal(int_list)
    print(f"\n1️⃣  INT4[] Literal: {int_literal}")

    var query1 = "SELECT " + int_literal + "::INT4[]"
    var result1 = conn.query(query1)
    var arr1 = result1.get_int4_array(0, 0)
    print(f"   Query: {query1}")
    print(f"   Result: {arr1.to_string()}")

    # Build TEXT[] literal
    var text_list = List[String]()
    text_list.append("hello")
    text_list.append("world")
    text_list.append("it's working")
    var text_literal = build_text_array_literal(text_list)
    print(f"\n2️⃣  TEXT[] Literal: {text_literal}")

    var query2 = "SELECT " + text_literal + "::TEXT[]"
    var result2 = conn.query(query2)
    var arr2 = result2.get_text_array(0, 0)
    print(f"   Query: {query2}")
    print(f"   Result: {arr2.to_string()}")

    # Build BOOLEAN[] literal
    var bool_list = List[Bool]()
    bool_list.append(True)
    bool_list.append(False)
    bool_list.append(True)
    var bool_literal = build_bool_array_literal(bool_list)
    print(f"\n3️⃣  BOOLEAN[] Literal: {bool_literal}")

    var query3 = "SELECT " + bool_literal + "::BOOLEAN[]"
    var result3 = conn.query(query3)
    var arr3 = result3.get_bool_array(0, 0)
    print(f"   Query: {query3}")
    print(f"   Result: {arr3.to_string()}")

    print("\n✅ Array literal builders simplify dynamic query generation!")

    conn.close()
    print("\n✅ Example 7 complete!\n")


fn main() raises:
    print("\n")
    print("🔥 PostgreSQL Array Types Examples")
    print("Multi-Value Column Support")
    print("\n")

    # Run examples
    example1_basic_array_select()
    example2_array_insert()
    example3_null_elements()
    example4_multi_dimensional_arrays()
    example5_array_operations()
    example6_practical_use_cases()
    example7_array_literal_builders()

    print("=" * 70)
    print("🎉 All examples completed successfully!")
    print("=" * 70)
    print("\n💡 Key Takeaways:")
    print("   - Arrays store multiple values in a single column")
    print("   - Support for INT[], FLOAT[], TEXT[], BOOLEAN[] types")
    print("   - NULL elements are supported in arrays")
    print("   - Rich set of array operations (append, concatenate, unnest)")
    print("   - Perfect for tags, categories, metrics, permissions")
    print("\n💡 Use Cases:")
    print("   - Tags and categories (blog posts, products)")
    print("   - Time-series data (metrics, measurements)")
    print("   - Permissions and roles (user management)")
    print("   - Multi-value attributes (phone numbers, emails)")
    print("   - Historical data (price history, status changes)")
    print("\n💡 Performance Benefits:")
    print("   - Reduce JOIN complexity")
    print("   - Store related data together")
    print("   - Efficient queries with ANY, ALL operators")
    print("   - Atomic updates of multi-value data")
    print("\n")
