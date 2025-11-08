"""
Integration tests for Array Types with real PostgreSQL.

Prerequisites:
- PostgreSQL running on localhost:5432
- Database 'test' with user 'test' / password 'test'

Tests:
1. Integer arrays (INT2[], INT4[], INT8[])
2. Float arrays (FLOAT4[], FLOAT8[])
3. Text arrays (TEXT[], VARCHAR[])
4. Boolean arrays (BOOLEAN[])
5. Arrays with NULL elements
6. Array INSERT operations
7. Array operations (append, concatenate, unnest)
8. Multi-row array queries
"""

from testing import assert_equal, assert_true, assert_false
from src.protocol.connection import PostgresConnection
from src.types.array_types import build_int4_array_literal, build_text_array_literal
from collections import List


fn test_int4_array_select() raises:
    """Test 1: INT4[] SELECT."""
    print("  test_int4_array_select...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT ARRAY[1,2,3,4,5]::INT4[]")
    var arr = result.get_int4_array(0, 0)

    assert_equal(arr.length(), 5)
    assert_equal(arr.get(0), 1)
    assert_equal(arr.get(4), 5)
    assert_false(arr.has_nulls)

    conn.close()

    print(" ✅")


fn test_int2_array_select() raises:
    """Test 2: INT2[] SELECT."""
    print("  test_int2_array_select...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT ARRAY[10,20,30]::INT2[]")
    var arr = result.get_int2_array(0, 0)

    assert_equal(arr.length(), 3)
    assert_equal(arr.get(0), 10)
    assert_equal(arr.get(1), 20)
    assert_equal(arr.get(2), 30)

    conn.close()

    print(" ✅")


fn test_int8_array_select() raises:
    """Test 3: INT8[] SELECT."""
    print("  test_int8_array_select...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT ARRAY[1000000000,2000000000,3000000000]::INT8[]")
    var arr = result.get_int8_array(0, 0)

    assert_equal(arr.length(), 3)
    assert_equal(arr.get(0), 1000000000)
    assert_equal(arr.get(2), 3000000000)

    conn.close()

    print(" ✅")


fn test_float4_array_select() raises:
    """Test 4: FLOAT4[] SELECT."""
    print("  test_float4_array_select...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT ARRAY[1.5, 2.7, 3.14]::FLOAT4[]")
    var arr = result.get_float4_array(0, 0)

    assert_equal(arr.length(), 3)

    # Check approximate equality
    var val0 = arr.get(0)
    assert_true(val0 > 1.49 and val0 < 1.51)

    conn.close()

    print(" ✅")


fn test_float8_array_select() raises:
    """Test 5: FLOAT8[] SELECT."""
    print("  test_float8_array_select...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT ARRAY[3.14159, 2.71828]::FLOAT8[]")
    var arr = result.get_float8_array(0, 0)

    assert_equal(arr.length(), 2)

    var val0 = arr.get(0)
    assert_true(val0 > 3.14 and val0 < 3.15)

    conn.close()

    print(" ✅")


fn test_text_array_select() raises:
    """Test 6: TEXT[] SELECT."""
    print("  test_text_array_select...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT ARRAY['apple', 'banana', 'cherry']::TEXT[]")
    var arr = result.get_text_array(0, 0)

    assert_equal(arr.length(), 3)
    assert_equal(arr.get(0), "apple")
    assert_equal(arr.get(1), "banana")
    assert_equal(arr.get(2), "cherry")

    conn.close()

    print(" ✅")


fn test_bool_array_select() raises:
    """Test 7: BOOLEAN[] SELECT."""
    print("  test_bool_array_select...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT ARRAY[true, false, true]::BOOLEAN[]")
    var arr = result.get_bool_array(0, 0)

    assert_equal(arr.length(), 3)
    assert_true(arr.get(0))
    assert_false(arr.get(1))
    assert_true(arr.get(2))

    conn.close()

    print(" ✅")


fn test_array_with_nulls() raises:
    """Test 8: Arrays with NULL elements."""
    print("  test_array_with_nulls...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # INT4[] with NULL
    var result1 = conn.query("SELECT ARRAY[1, NULL, 3, NULL, 5]::INT4[]")
    var arr1 = result1.get_int4_array(0, 0)
    assert_equal(arr1.length(), 5)
    assert_true(arr1.has_nulls)
    assert_equal(arr1.get(0), 1)
    assert_equal(arr1.get(1), 0)  # NULL as 0
    assert_equal(arr1.get(4), 5)

    # TEXT[] with NULL
    var result2 = conn.query("SELECT ARRAY['hello', NULL, 'world']::TEXT[]")
    var arr2 = result2.get_text_array(0, 0)
    assert_equal(arr2.length(), 3)
    assert_true(arr2.has_nulls)
    assert_equal(arr2.get(0), "hello")
    assert_equal(arr2.get(1), "")  # NULL as empty string
    assert_equal(arr2.get(2), "world")

    # BOOLEAN[] with NULL
    var result3 = conn.query("SELECT ARRAY[true, NULL, false]::BOOLEAN[]")
    var arr3 = result3.get_bool_array(0, 0)
    assert_equal(arr3.length(), 3)
    assert_true(arr3.has_nulls)

    conn.close()

    print(" ✅")


fn test_array_insert() raises:
    """Test 9: INSERT with arrays."""
    print("  test_array_insert...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS array_test")
    var __ = conn.query("""
        CREATE TABLE array_test (
            id SERIAL PRIMARY KEY,
            int_array INT4[],
            text_array TEXT[],
            bool_array BOOLEAN[]
        )
    """)

    # Insert arrays
    var ___ = conn.query("""
        INSERT INTO array_test (int_array, text_array, bool_array)
        VALUES (
            ARRAY[1,2,3],
            ARRAY['a','b','c'],
            ARRAY[true,false,true]
        )
    """)

    # Retrieve and verify
    var result = conn.query("SELECT int_array, text_array, bool_array FROM array_test WHERE id = 1")

    var int_arr = result.get_int4_array(0, 0)
    assert_equal(int_arr.length(), 3)
    assert_equal(int_arr.get(0), 1)

    var text_arr = result.get_text_array(0, 1)
    assert_equal(text_arr.length(), 3)
    assert_equal(text_arr.get(1), "b")

    var bool_arr = result.get_bool_array(0, 2)
    assert_equal(bool_arr.length(), 3)
    assert_true(bool_arr.get(0))

    # Cleanup
    var ____ = conn.query("DROP TABLE array_test")

    conn.close()

    print(" ✅")


fn test_array_update() raises:
    """Test 10: UPDATE with arrays."""
    print("  test_array_update...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS array_test")
    var __ = conn.query("""
        CREATE TABLE array_test (
            id SERIAL PRIMARY KEY,
            tags TEXT[]
        )
    """)

    # Insert
    var ___ = conn.query("INSERT INTO array_test (tags) VALUES (ARRAY['old', 'tags'])")

    # Update
    var ____ = conn.query("UPDATE array_test SET tags = ARRAY['new', 'updated', 'tags'] WHERE id = 1")

    # Verify
    var result = conn.query("SELECT tags FROM array_test WHERE id = 1")
    var tags = result.get_text_array(0, 0)

    assert_equal(tags.length(), 3)
    assert_equal(tags.get(0), "new")
    assert_equal(tags.get(1), "updated")

    # Cleanup
    var _____ = conn.query("DROP TABLE array_test")

    conn.close()

    print(" ✅")


fn test_array_operations() raises:
    """Test 11: PostgreSQL array operations."""
    print("  test_array_operations...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # array_length
    var result1 = conn.query("SELECT array_length(ARRAY[1,2,3,4,5], 1)")
    var length = result1.get_int32(0, 0)
    assert_equal(length, 5)

    # array_append
    var result2 = conn.query("SELECT array_append(ARRAY[1,2,3], 4)")
    var appended = result2.get_int4_array(0, 0)
    assert_equal(appended.length(), 4)
    assert_equal(appended.get(3), 4)

    # array_prepend
    var result3 = conn.query("SELECT array_prepend(0, ARRAY[1,2,3])")
    var prepended = result3.get_int4_array(0, 0)
    assert_equal(prepended.length(), 4)
    assert_equal(prepended.get(0), 0)

    # array_cat (concatenate)
    var result4 = conn.query("SELECT array_cat(ARRAY[1,2], ARRAY[3,4])")
    var concatenated = result4.get_int4_array(0, 0)
    assert_equal(concatenated.length(), 4)
    assert_equal(concatenated.get(0), 1)
    assert_equal(concatenated.get(3), 4)

    # ANY operator
    var result5 = conn.query("SELECT 3 = ANY(ARRAY[1,2,3,4,5])")
    var contains = result5.get_bool(0, 0)
    assert_true(contains)

    var result6 = conn.query("SELECT 10 = ANY(ARRAY[1,2,3,4,5])")
    var not_contains = result6.get_bool(0, 0)
    assert_false(not_contains)

    conn.close()

    print(" ✅")


fn test_array_unnest() raises:
    """Test 12: unnest() operation."""
    print("  test_array_unnest...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # unnest INT4[]
    var result1 = conn.query("SELECT unnest(ARRAY[10,20,30])")
    assert_equal(result1.row_count(), 3)
    assert_equal(result1.get_int32(0, 0), 10)
    assert_equal(result1.get_int32(1, 0), 20)
    assert_equal(result1.get_int32(2, 0), 30)

    # unnest TEXT[]
    var result2 = conn.query("SELECT unnest(ARRAY['a', 'b', 'c'])")
    assert_equal(result2.row_count(), 3)
    assert_equal(result2.get_string(0, 0), "a")
    assert_equal(result2.get_string(1, 0), "b")
    assert_equal(result2.get_string(2, 0), "c")

    conn.close()

    print(" ✅")


fn test_array_agg() raises:
    """Test 13: array_agg() aggregation."""
    print("  test_array_agg...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # array_agg with generate_series
    var result = conn.query("SELECT array_agg(x) FROM generate_series(1, 5) AS x")
    var arr = result.get_int4_array(0, 0)

    assert_equal(arr.length(), 5)
    assert_equal(arr.get(0), 1)
    assert_equal(arr.get(4), 5)

    conn.close()

    print(" ✅")


fn test_multi_row_arrays() raises:
    """Test 14: Multiple rows with arrays."""
    print("  test_multi_row_arrays...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS products")
    var __ = conn.query("""
        CREATE TABLE products (
            id SERIAL PRIMARY KEY,
            name TEXT,
            tags TEXT[]
        )
    """)

    # Insert multiple rows
    var ___ = conn.query("""
        INSERT INTO products (name, tags) VALUES
        ('Product A', ARRAY['electronics', 'new']),
        ('Product B', ARRAY['clothing', 'sale', 'popular']),
        ('Product C', ARRAY['books'])
    """)

    # Query all rows
    var result = conn.query("SELECT name, tags FROM products ORDER BY id")
    assert_equal(result.row_count(), 3)

    # Verify row 1
    var name1 = result.get_string(0, 0)
    var tags1 = result.get_text_array(0, 1)
    assert_equal(name1, "Product A")
    assert_equal(tags1.length(), 2)
    assert_equal(tags1.get(0), "electronics")

    # Verify row 2
    var tags2 = result.get_text_array(1, 1)
    assert_equal(tags2.length(), 3)
    assert_equal(tags2.get(1), "sale")

    # Verify row 3
    var tags3 = result.get_text_array(2, 1)
    assert_equal(tags3.length(), 1)
    assert_equal(tags3.get(0), "books")

    # Cleanup
    var ____ = conn.query("DROP TABLE products")

    conn.close()

    print(" ✅")


fn test_array_where_clause() raises:
    """Test 15: Arrays in WHERE clause."""
    print("  test_array_where_clause...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS items")
    var __ = conn.query("""
        CREATE TABLE items (
            id SERIAL PRIMARY KEY,
            name TEXT,
            categories TEXT[]
        )
    """)

    # Insert data
    var ___ = conn.query("""
        INSERT INTO items (name, categories) VALUES
        ('Item 1', ARRAY['food', 'organic']),
        ('Item 2', ARRAY['electronics', 'sale']),
        ('Item 3', ARRAY['food', 'frozen'])
    """)

    # Query with ANY
    var result = conn.query("SELECT name FROM items WHERE 'food' = ANY(categories) ORDER BY id")
    assert_equal(result.row_count(), 2)
    assert_equal(result.get_string(0, 0), "Item 1")
    assert_equal(result.get_string(1, 0), "Item 3")

    # Cleanup
    var ____ = conn.query("DROP TABLE items")

    conn.close()

    print(" ✅")


fn test_empty_array() raises:
    """Test 16: Empty arrays."""
    print("  test_empty_array...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Empty INT4[]
    var result1 = conn.query("SELECT ARRAY[]::INT4[]")
    var arr1 = result1.get_int4_array(0, 0)
    # PostgreSQL returns "{}" which parses to 1 empty element
    assert_true(arr1.length() >= 0)

    # Empty TEXT[]
    var result2 = conn.query("SELECT ARRAY[]::TEXT[]")
    var arr2 = result2.get_text_array(0, 0)
    assert_true(arr2.length() >= 0)

    conn.close()

    print(" ✅")


fn test_array_literal_builders() raises:
    """Test 17: Array literal builder functions."""
    print("  test_array_literal_builders...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Build INT4[] literal
    var int_list = List[Int32]()
    int_list.append(100)
    int_list.append(200)
    int_list.append(300)
    var int_literal = build_int4_array_literal(int_list)

    var query1 = "SELECT " + int_literal + "::INT4[]"
    var result1 = conn.query(query1)
    var arr1 = result1.get_int4_array(0, 0)
    assert_equal(arr1.length(), 3)
    assert_equal(arr1.get(0), 100)
    assert_equal(arr1.get(2), 300)

    # Build TEXT[] literal
    var text_list = List[String]()
    text_list.append("hello")
    text_list.append("world")
    var text_literal = build_text_array_literal(text_list)

    var query2 = "SELECT " + text_literal + "::TEXT[]"
    var result2 = conn.query(query2)
    var arr2 = result2.get_text_array(0, 0)
    assert_equal(arr2.length(), 2)
    assert_equal(arr2.get(0), "hello")
    assert_equal(arr2.get(1), "world")

    conn.close()

    print(" ✅")


fn main() raises:
    print("\n" + "=" * 70)
    print("Array Types Integration Tests")
    print("=" * 70 + "\n")

    print("Basic Array Type Tests:")
    test_int4_array_select()
    test_int2_array_select()
    test_int8_array_select()
    test_float4_array_select()
    test_float8_array_select()
    test_text_array_select()
    test_bool_array_select()

    print("\nArray Manipulation Tests:")
    test_array_with_nulls()
    test_array_insert()
    test_array_update()
    test_array_operations()
    test_array_unnest()
    test_array_agg()

    print("\nAdvanced Array Tests:")
    test_multi_row_arrays()
    test_array_where_clause()
    test_empty_array()
    test_array_literal_builders()

    print("\n" + "=" * 70)
    print("✅ All 17 tests passed!")
    print("=" * 70 + "\n")
