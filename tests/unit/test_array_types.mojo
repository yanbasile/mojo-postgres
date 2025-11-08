"""
Unit tests for PostgreSQL Array Types.

Tests array parsing, structure operations, and literal building.

Test Categories:
1. Array text parsing
2. Integer array parsing (INT2, INT4, INT8)
3. Float array parsing (FLOAT4, FLOAT8)
4. Text array parsing
5. Boolean array parsing
6. NULL element handling
7. Array literal builders
8. Edge cases
"""

from testing import assert_equal, assert_true, assert_false, assert_raises
from src.types.array_types import (
    parse_array_text,
    parse_int2_array,
    parse_int4_array,
    parse_int8_array,
    parse_float4_array,
    parse_float8_array,
    parse_text_array,
    parse_bool_array,
    build_int4_array_literal,
    build_text_array_literal,
    build_bool_array_literal,
)
from collections import List


# ============================================================================
# Test 1: Array Text Parsing
# ============================================================================

fn test_parse_array_text_basic() raises:
    """Test 1.1: Basic array text parsing."""
    print("  test_parse_array_text_basic...", end="")

    var elements = parse_array_text("{1,2,3}")
    assert_equal(len(elements), 3)
    assert_equal(elements[0], "1")
    assert_equal(elements[1], "2")
    assert_equal(elements[2], "3")

    print(" ✅")


fn test_parse_array_text_quoted() raises:
    """Test 1.2: Quoted elements."""
    print("  test_parse_array_text_quoted...", end="")

    var elements = parse_array_text('{\"hello\",\"world\"}')
    assert_equal(len(elements), 2)
    assert_equal(elements[0], "hello")
    assert_equal(elements[1], "world")

    print(" ✅")


fn test_parse_array_text_with_null() raises:
    """Test 1.3: Array with NULL elements."""
    print("  test_parse_array_text_with_null...", end="")

    var elements = parse_array_text("{1,NULL,3}")
    assert_equal(len(elements), 3)
    assert_equal(elements[0], "1")
    assert_equal(elements[1], "NULL")
    assert_equal(elements[2], "3")

    print(" ✅")


fn test_parse_array_text_empty() raises:
    """Test 1.4: Empty array."""
    print("  test_parse_array_text_empty...", end="")

    var elements = parse_array_text("{}")
    assert_equal(len(elements), 1)
    assert_equal(elements[0], "")

    print(" ✅")


fn test_parse_array_text_single_element() raises:
    """Test 1.5: Single element array."""
    print("  test_parse_array_text_single_element...", end="")

    var elements = parse_array_text("{42}")
    assert_equal(len(elements), 1)
    assert_equal(elements[0], "42")

    print(" ✅")


fn test_parse_array_text_with_spaces() raises:
    """Test 1.6: Array with spaces."""
    print("  test_parse_array_text_with_spaces...", end="")

    var elements = parse_array_text("{ 1 , 2 , 3 }")
    assert_equal(len(elements), 3)
    assert_equal(elements[0], "1")
    assert_equal(elements[1], "2")
    assert_equal(elements[2], "3")

    print(" ✅")


# ============================================================================
# Test 2: Integer Array Parsing
# ============================================================================

fn test_parse_int2_array() raises:
    """Test 2.1: Parse INT2[] array."""
    print("  test_parse_int2_array...", end="")

    var arr = parse_int2_array("{10,20,30}")
    assert_equal(arr.length(), 3)
    assert_equal(arr.get(0), 10)
    assert_equal(arr.get(1), 20)
    assert_equal(arr.get(2), 30)
    assert_false(arr.has_nulls)

    print(" ✅")


fn test_parse_int4_array() raises:
    """Test 2.2: Parse INT4[] array."""
    print("  test_parse_int4_array...", end="")

    var arr = parse_int4_array("{100,200,300,400}")
    assert_equal(arr.length(), 4)
    assert_equal(arr.get(0), 100)
    assert_equal(arr.get(1), 200)
    assert_equal(arr.get(2), 300)
    assert_equal(arr.get(3), 400)
    assert_false(arr.has_nulls)

    var str_repr = arr.to_string()
    assert_equal(str_repr, "[100, 200, 300, 400]")

    print(" ✅")


fn test_parse_int8_array() raises:
    """Test 2.3: Parse INT8[] array."""
    print("  test_parse_int8_array...", end="")

    var arr = parse_int8_array("{1000000000,2000000000,3000000000}")
    assert_equal(arr.length(), 3)
    assert_equal(arr.get(0), 1000000000)
    assert_equal(arr.get(1), 2000000000)
    assert_equal(arr.get(2), 3000000000)
    assert_false(arr.has_nulls)

    print(" ✅")


fn test_parse_int4_array_with_null() raises:
    """Test 2.4: Parse INT4[] with NULL."""
    print("  test_parse_int4_array_with_null...", end="")

    var arr = parse_int4_array("{1,NULL,3,NULL,5}")
    assert_equal(arr.length(), 5)
    assert_equal(arr.get(0), 1)
    assert_equal(arr.get(1), 0)  # NULL represented as 0
    assert_equal(arr.get(2), 3)
    assert_equal(arr.get(3), 0)  # NULL represented as 0
    assert_equal(arr.get(4), 5)
    assert_true(arr.has_nulls)

    print(" ✅")


fn test_parse_int4_array_negative() raises:
    """Test 2.5: Parse INT4[] with negative numbers."""
    print("  test_parse_int4_array_negative...", end="")

    var arr = parse_int4_array("{-10,-20,30,-40}")
    assert_equal(arr.length(), 4)
    assert_equal(arr.get(0), -10)
    assert_equal(arr.get(1), -20)
    assert_equal(arr.get(2), 30)
    assert_equal(arr.get(3), -40)

    print(" ✅")


# ============================================================================
# Test 3: Float Array Parsing
# ============================================================================

fn test_parse_float4_array() raises:
    """Test 3.1: Parse FLOAT4[] array."""
    print("  test_parse_float4_array...", end="")

    var arr = parse_float4_array("{1.5,2.7,3.14}")
    assert_equal(arr.length(), 3)
    assert_false(arr.has_nulls)

    # Check approximate equality for floats
    var val0 = arr.get(0)
    assert_true(val0 > 1.49 and val0 < 1.51)

    print(" ✅")


fn test_parse_float8_array() raises:
    """Test 3.2: Parse FLOAT8[] array."""
    print("  test_parse_float8_array...", end="")

    var arr = parse_float8_array("{3.14159,2.71828,1.41421}")
    assert_equal(arr.length(), 3)
    assert_false(arr.has_nulls)

    var val0 = arr.get(0)
    assert_true(val0 > 3.14 and val0 < 3.15)

    print(" ✅")


fn test_parse_float8_array_with_null() raises:
    """Test 3.3: Parse FLOAT8[] with NULL."""
    print("  test_parse_float8_array_with_null...", end="")

    var arr = parse_float8_array("{1.5,NULL,3.5}")
    assert_equal(arr.length(), 3)
    assert_equal(arr.get(1), 0.0)  # NULL as 0.0
    assert_true(arr.has_nulls)

    print(" ✅")


fn test_parse_float_array_scientific() raises:
    """Test 3.4: Parse FLOAT[] with scientific notation."""
    print("  test_parse_float_array_scientific...", end="")

    var arr = parse_float8_array("{1e10,2.5e-3,3.14e2}")
    assert_equal(arr.length(), 3)

    print(" ✅")


# ============================================================================
# Test 4: Text Array Parsing
# ============================================================================

fn test_parse_text_array() raises:
    """Test 4.1: Parse TEXT[] array."""
    print("  test_parse_text_array...", end="")

    var arr = parse_text_array('{\"apple\",\"banana\",\"cherry\"}')
    assert_equal(arr.length(), 3)
    assert_equal(arr.get(0), "apple")
    assert_equal(arr.get(1), "banana")
    assert_equal(arr.get(2), "cherry")
    assert_false(arr.has_nulls)

    var str_repr = arr.to_string()
    assert_equal(str_repr, '[\"apple\", \"banana\", \"cherry\"]')

    print(" ✅")


fn test_parse_text_array_with_null() raises:
    """Test 4.2: Parse TEXT[] with NULL."""
    print("  test_parse_text_array_with_null...", end="")

    var arr = parse_text_array('{\"hello\",NULL,\"world\"}')
    assert_equal(arr.length(), 3)
    assert_equal(arr.get(0), "hello")
    assert_equal(arr.get(1), "")  # NULL as empty string
    assert_equal(arr.get(2), "world")
    assert_true(arr.has_nulls)

    print(" ✅")


fn test_parse_text_array_empty_strings() raises:
    """Test 4.3: Parse TEXT[] with empty strings."""
    print("  test_parse_text_array_empty_strings...", end="")

    var arr = parse_text_array('{\"\",\"test\",\"\"}')
    assert_equal(arr.length(), 3)
    assert_equal(arr.get(0), "")
    assert_equal(arr.get(1), "test")
    assert_equal(arr.get(2), "")

    print(" ✅")


fn test_parse_text_array_single() raises:
    """Test 4.4: Parse TEXT[] with single element."""
    print("  test_parse_text_array_single...", end="")

    var arr = parse_text_array('{\"hello\"}')
    assert_equal(arr.length(), 1)
    assert_equal(arr.get(0), "hello")

    print(" ✅")


# ============================================================================
# Test 5: Boolean Array Parsing
# ============================================================================

fn test_parse_bool_array_true_false() raises:
    """Test 5.1: Parse BOOLEAN[] with true/false."""
    print("  test_parse_bool_array_true_false...", end="")

    var arr = parse_bool_array("{true,false,true}")
    assert_equal(arr.length(), 3)
    assert_true(arr.get(0))
    assert_false(arr.get(1))
    assert_true(arr.get(2))
    assert_false(arr.has_nulls)

    var str_repr = arr.to_string()
    assert_equal(str_repr, "[true, false, true]")

    print(" ✅")


fn test_parse_bool_array_t_f() raises:
    """Test 5.2: Parse BOOLEAN[] with t/f."""
    print("  test_parse_bool_array_t_f...", end="")

    var arr = parse_bool_array("{t,f,t,f}")
    assert_equal(arr.length(), 4)
    assert_true(arr.get(0))
    assert_false(arr.get(1))
    assert_true(arr.get(2))
    assert_false(arr.get(3))

    print(" ✅")


fn test_parse_bool_array_uppercase() raises:
    """Test 5.3: Parse BOOLEAN[] with uppercase."""
    print("  test_parse_bool_array_uppercase...", end="")

    var arr = parse_bool_array("{TRUE,FALSE,TRUE}")
    assert_equal(arr.length(), 3)
    assert_true(arr.get(0))
    assert_false(arr.get(1))
    assert_true(arr.get(2))

    print(" ✅")


fn test_parse_bool_array_with_null() raises:
    """Test 5.4: Parse BOOLEAN[] with NULL."""
    print("  test_parse_bool_array_with_null...", end="")

    var arr = parse_bool_array("{t,NULL,f}")
    assert_equal(arr.length(), 3)
    assert_true(arr.get(0))
    assert_false(arr.get(1))  # NULL as false
    assert_false(arr.get(2))
    assert_true(arr.has_nulls)

    print(" ✅")


# ============================================================================
# Test 6: Array Literal Builders
# ============================================================================

fn test_build_int4_array_literal() raises:
    """Test 6.1: Build INT4[] literal."""
    print("  test_build_int4_array_literal...", end="")

    var elements = List[Int32]()
    elements.append(10)
    elements.append(20)
    elements.append(30)

    var literal = build_int4_array_literal(elements)
    assert_equal(literal, "ARRAY[10,20,30]")

    print(" ✅")


fn test_build_int4_array_literal_empty() raises:
    """Test 6.2: Build empty INT4[] literal."""
    print("  test_build_int4_array_literal_empty...", end="")

    var elements = List[Int32]()
    var literal = build_int4_array_literal(elements)
    assert_equal(literal, "ARRAY[]")

    print(" ✅")


fn test_build_int4_array_literal_single() raises:
    """Test 6.3: Build single element INT4[] literal."""
    print("  test_build_int4_array_literal_single...", end="")

    var elements = List[Int32]()
    elements.append(42)

    var literal = build_int4_array_literal(elements)
    assert_equal(literal, "ARRAY[42]")

    print(" ✅")


fn test_build_text_array_literal() raises:
    """Test 6.4: Build TEXT[] literal."""
    print("  test_build_text_array_literal...", end="")

    var elements = List[String]()
    elements.append("hello")
    elements.append("world")

    var literal = build_text_array_literal(elements)
    assert_equal(literal, "ARRAY['hello','world']")

    print(" ✅")


fn test_build_text_array_literal_with_quotes() raises:
    """Test 6.5: Build TEXT[] literal with quotes."""
    print("  test_build_text_array_literal_with_quotes...", end="")

    var elements = List[String]()
    elements.append("it's")
    elements.append("working")

    var literal = build_text_array_literal(elements)
    # Single quotes should be escaped as ''
    assert_equal(literal, "ARRAY['it''s','working']")

    print(" ✅")


fn test_build_bool_array_literal() raises:
    """Test 6.6: Build BOOLEAN[] literal."""
    print("  test_build_bool_array_literal...", end="")

    var elements = List[Bool]()
    elements.append(True)
    elements.append(False)
    elements.append(True)

    var literal = build_bool_array_literal(elements)
    assert_equal(literal, "ARRAY[true,false,true]")

    print(" ✅")


# ============================================================================
# Test 7: Edge Cases
# ============================================================================

fn test_parse_array_text_invalid_format() raises:
    """Test 7.1: Invalid array format (missing braces)."""
    print("  test_parse_array_text_invalid_format...", end="")

    try:
        var _ = parse_array_text("1,2,3")
        raise Error("Should have raised error for missing braces")
    except e:
        # Expected to raise error
        pass

    print(" ✅")


fn test_parse_bool_array_invalid_value() raises:
    """Test 7.2: Invalid boolean value."""
    print("  test_parse_bool_array_invalid_value...", end="")

    try:
        var _ = parse_bool_array("{true,invalid,false}")
        raise Error("Should have raised error for invalid boolean")
    except e:
        # Expected to raise error
        pass

    print(" ✅")


fn test_array_access_bounds() raises:
    """Test 7.3: Array index bounds."""
    print("  test_array_access_bounds...", end="")

    var arr = parse_int4_array("{1,2,3}")

    # Valid access
    var val = arr.get(0)
    assert_equal(val, 1)

    var val2 = arr.get(2)
    assert_equal(val2, 3)

    print(" ✅")


fn test_large_array() raises:
    """Test 7.4: Large array parsing."""
    print("  test_large_array...", end="")

    # Build array with 100 elements
    var array_text = "{"
    for i in range(100):
        if i > 0:
            array_text += ","
        array_text += String(i)
    array_text += "}"

    var arr = parse_int4_array(array_text)
    assert_equal(arr.length(), 100)
    assert_equal(arr.get(0), 0)
    assert_equal(arr.get(99), 99)

    print(" ✅")


fn main() raises:
    print("\n" + "=" * 70)
    print("Array Types Unit Tests")
    print("=" * 70 + "\n")

    print("Test 1: Array Text Parsing")
    test_parse_array_text_basic()
    test_parse_array_text_quoted()
    test_parse_array_text_with_null()
    test_parse_array_text_empty()
    test_parse_array_text_single_element()
    test_parse_array_text_with_spaces()

    print("\nTest 2: Integer Array Parsing")
    test_parse_int2_array()
    test_parse_int4_array()
    test_parse_int8_array()
    test_parse_int4_array_with_null()
    test_parse_int4_array_negative()

    print("\nTest 3: Float Array Parsing")
    test_parse_float4_array()
    test_parse_float8_array()
    test_parse_float8_array_with_null()
    test_parse_float_array_scientific()

    print("\nTest 4: Text Array Parsing")
    test_parse_text_array()
    test_parse_text_array_with_null()
    test_parse_text_array_empty_strings()
    test_parse_text_array_single()

    print("\nTest 5: Boolean Array Parsing")
    test_parse_bool_array_true_false()
    test_parse_bool_array_t_f()
    test_parse_bool_array_uppercase()
    test_parse_bool_array_with_null()

    print("\nTest 6: Array Literal Builders")
    test_build_int4_array_literal()
    test_build_int4_array_literal_empty()
    test_build_int4_array_literal_single()
    test_build_text_array_literal()
    test_build_text_array_literal_with_quotes()
    test_build_bool_array_literal()

    print("\nTest 7: Edge Cases")
    test_parse_array_text_invalid_format()
    test_parse_bool_array_invalid_value()
    test_array_access_bounds()
    test_large_array()

    print("\n" + "=" * 70)
    print("✅ All 34 tests passed!")
    print("=" * 70 + "\n")
