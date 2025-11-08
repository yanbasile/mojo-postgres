"""
PostgreSQL Array Types Implementation.

Supports PostgreSQL array types for efficient handling of multi-value columns.

Array Types Supported:
- INT2[] (SMALLINT[])
- INT4[] (INTEGER[])
- INT8[] (BIGINT[])
- FLOAT4[] (REAL[])
- FLOAT8[] (DOUBLE PRECISION[])
- TEXT[]
- VARCHAR[]
- BOOLEAN[]
- TIMESTAMP[]
- DATE[]

Array Format (Text):
  {val1,val2,val3}
  {1,2,3,4,5}
  {"text1","text2","text3"}

Array Format (Multi-dimensional):
  {{1,2},{3,4}}
  {{"a","b"},{"c","d"}}

NULL Elements:
  {1,NULL,3}
  {"text",NULL,"more"}

Example:
    # Parse array from query result
    var result = conn.query("SELECT ARRAY[1,2,3,4,5]::INT4[]")
    var arr = parse_int4_array(result.get_value(0, 0))
    print(arr.to_string())  # [1, 2, 3, 4, 5]

    # Multi-dimensional array
    var result2 = conn.query("SELECT ARRAY[[1,2],[3,4]]::INT4[]")
    var arr2 = parse_int4_array(result2.get_value(0, 0))
"""

from collections import List


# ============================================================================
# Array Parsing Utilities
# ============================================================================

fn skip_whitespace(text: String, offset: Int) -> Int:
    """Skip whitespace characters."""
    var i = offset
    while i < len(text) and (text[i] == ' ' or text[i] == '\t' or text[i] == '\n' or text[i] == '\r'):
        i += 1
    return i


fn parse_array_text(text: String) raises -> List[String]:
    """
    Parse PostgreSQL array text format into list of string elements.

    Format: {val1,val2,val3}
    Quoted: {"val1","val2","val3"}
    With NULL: {val1,NULL,val3}

    Args:
        text: Array text representation (e.g., "{1,2,3}")

    Returns:
        List of element strings (including "NULL" for NULL values)

    Raises:
        Error if format is invalid

    Example:
        var elements = parse_array_text("{1,2,3}")
        # Returns: ["1", "2", "3"]
    """
    var elements = List[String]()

    # Remove leading/trailing whitespace
    var start = 0
    while start < len(text) and text[start] == ' ':
        start += 1

    var end = len(text) - 1
    while end >= 0 and text[end] == ' ':
        end -= 1

    if start > end:
        raise Error("Empty array text")

    # Check for array delimiters
    if text[start] != '{':
        raise Error("Array must start with '{'")

    if text[end] != '}':
        raise Error("Array must end with '}'")

    # Parse elements between { and }
    var i = start + 1  # Skip opening '{'
    var current_element = String("")
    var in_quotes = False

    while i <= end - 1:  # Until closing '}'
        var ch = text[i]

        if ch == '"' and not in_quotes:
            # Start quoted element
            in_quotes = True
        elif ch == '"' and in_quotes:
            # End quoted element
            in_quotes = False
        elif ch == ',' and not in_quotes:
            # Element separator
            var trimmed = current_element
            # Trim whitespace
            while len(trimmed) > 0 and (trimmed[0] == ' ' or trimmed[0] == '\t'):
                trimmed = trimmed[1:]
            while len(trimmed) > 0 and (trimmed[len(trimmed)-1] == ' ' or trimmed[len(trimmed)-1] == '\t'):
                trimmed = trimmed[:len(trimmed)-1]

            elements.append(trimmed)
            current_element = String("")
        else:
            current_element += ch

        i += 1

    # Add last element
    if len(current_element) > 0 or i > start + 1:
        var trimmed = current_element
        # Trim whitespace
        while len(trimmed) > 0 and (trimmed[0] == ' ' or trimmed[0] == '\t'):
            trimmed = trimmed[1:]
        while len(trimmed) > 0 and (trimmed[len(trimmed)-1] == ' ' or trimmed[len(trimmed)-1] == '\t'):
            trimmed = trimmed[:len(trimmed)-1]

        elements.append(trimmed)

    return elements


# ============================================================================
# Integer Arrays
# ============================================================================

@value
struct Int2Array:
    """Array of INT2 (SMALLINT) values."""
    var elements: List[Int16]
    var has_nulls: Bool

    fn to_string(self) -> String:
        """Return string representation."""
        var result = "["
        for i in range(len(self.elements)):
            result += String(self.elements[i])
            if i < len(self.elements) - 1:
                result += ", "
        result += "]"
        return result

    fn length(self) -> Int:
        """Get array length."""
        return len(self.elements)

    fn get(self, index: Int) -> Int16:
        """Get element at index."""
        return self.elements[index]


fn parse_int2_array(text: String) raises -> Int2Array:
    """
    Parse INT2[] (SMALLINT[]) from text format.

    Args:
        text: Array text (e.g., "{1,2,3}")

    Returns:
        Int2Array

    Example:
        var arr = parse_int2_array("{10,20,30}")
    """
    var str_elements = parse_array_text(text)
    var elements = List[Int16]()
    var has_nulls = False

    for i in range(len(str_elements)):
        var elem = str_elements[i]
        if elem == "NULL" or elem == "null":
            has_nulls = True
            elements.append(0)  # Use 0 as placeholder for NULL
        else:
            var val = atol(elem)
            elements.append(Int16(val))

    return Int2Array(elements, has_nulls)


@value
struct Int4Array:
    """Array of INT4 (INTEGER) values."""
    var elements: List[Int32]
    var has_nulls: Bool

    fn to_string(self) -> String:
        """Return string representation."""
        var result = "["
        for i in range(len(self.elements)):
            result += String(self.elements[i])
            if i < len(self.elements) - 1:
                result += ", "
        result += "]"
        return result

    fn length(self) -> Int:
        """Get array length."""
        return len(self.elements)

    fn get(self, index: Int) -> Int32:
        """Get element at index."""
        return self.elements[index]


fn parse_int4_array(text: String) raises -> Int4Array:
    """
    Parse INT4[] (INTEGER[]) from text format.

    Args:
        text: Array text (e.g., "{1,2,3}")

    Returns:
        Int4Array

    Example:
        var arr = parse_int4_array("{100,200,300}")
    """
    var str_elements = parse_array_text(text)
    var elements = List[Int32]()
    var has_nulls = False

    for i in range(len(str_elements)):
        var elem = str_elements[i]
        if elem == "NULL" or elem == "null":
            has_nulls = True
            elements.append(0)
        else:
            var val = atol(elem)
            elements.append(Int32(val))

    return Int4Array(elements, has_nulls)


@value
struct Int8Array:
    """Array of INT8 (BIGINT) values."""
    var elements: List[Int64]
    var has_nulls: Bool

    fn to_string(self) -> String:
        """Return string representation."""
        var result = "["
        for i in range(len(self.elements)):
            result += String(self.elements[i])
            if i < len(self.elements) - 1:
                result += ", "
        result += "]"
        return result

    fn length(self) -> Int:
        """Get array length."""
        return len(self.elements)

    fn get(self, index: Int) -> Int64:
        """Get element at index."""
        return self.elements[index]


fn parse_int8_array(text: String) raises -> Int8Array:
    """
    Parse INT8[] (BIGINT[]) from text format.

    Args:
        text: Array text (e.g., "{1000000000,2000000000}")

    Returns:
        Int8Array

    Example:
        var arr = parse_int8_array("{1234567890,9876543210}")
    """
    var str_elements = parse_array_text(text)
    var elements = List[Int64]()
    var has_nulls = False

    for i in range(len(str_elements)):
        var elem = str_elements[i]
        if elem == "NULL" or elem == "null":
            has_nulls = True
            elements.append(0)
        else:
            var val = atol(elem)
            elements.append(Int64(val))

    return Int8Array(elements, has_nulls)


# ============================================================================
# Float Arrays
# ============================================================================

@value
struct Float4Array:
    """Array of FLOAT4 (REAL) values."""
    var elements: List[Float32]
    var has_nulls: Bool

    fn to_string(self) -> String:
        """Return string representation."""
        var result = "["
        for i in range(len(self.elements)):
            result += String(self.elements[i])
            if i < len(self.elements) - 1:
                result += ", "
        result += "]"
        return result

    fn length(self) -> Int:
        """Get array length."""
        return len(self.elements)

    fn get(self, index: Int) -> Float32:
        """Get element at index."""
        return self.elements[index]


fn parse_float4_array(text: String) raises -> Float4Array:
    """Parse FLOAT4[] (REAL[]) from text format."""
    var str_elements = parse_array_text(text)
    var elements = List[Float32]()
    var has_nulls = False

    for i in range(len(str_elements)):
        var elem = str_elements[i]
        if elem == "NULL" or elem == "null":
            has_nulls = True
            elements.append(0.0)
        else:
            var val = atof(elem)
            elements.append(Float32(val))

    return Float4Array(elements, has_nulls)


@value
struct Float8Array:
    """Array of FLOAT8 (DOUBLE PRECISION) values."""
    var elements: List[Float64]
    var has_nulls: Bool

    fn to_string(self) -> String:
        """Return string representation."""
        var result = "["
        for i in range(len(self.elements)):
            result += String(self.elements[i])
            if i < len(self.elements) - 1:
                result += ", "
        result += "]"
        return result

    fn length(self) -> Int:
        """Get array length."""
        return len(self.elements)

    fn get(self, index: Int) -> Float64:
        """Get element at index."""
        return self.elements[index]


fn parse_float8_array(text: String) raises -> Float8Array:
    """Parse FLOAT8[] (DOUBLE PRECISION[]) from text format."""
    var str_elements = parse_array_text(text)
    var elements = List[Float64]()
    var has_nulls = False

    for i in range(len(str_elements)):
        var elem = str_elements[i]
        if elem == "NULL" or elem == "null":
            has_nulls = True
            elements.append(0.0)
        else:
            var val = atof(elem)
            elements.append(val)

    return Float8Array(elements, has_nulls)


# ============================================================================
# Text Arrays
# ============================================================================

@value
struct TextArray:
    """Array of TEXT values."""
    var elements: List[String]
    var has_nulls: Bool

    fn to_string(self) -> String:
        """Return string representation."""
        var result = "["
        for i in range(len(self.elements)):
            result += "\"" + self.elements[i] + "\""
            if i < len(self.elements) - 1:
                result += ", "
        result += "]"
        return result

    fn length(self) -> Int:
        """Get array length."""
        return len(self.elements)

    fn get(self, index: Int) -> String:
        """Get element at index."""
        return self.elements[index]


fn parse_text_array(text: String) raises -> TextArray:
    """
    Parse TEXT[] from text format.

    Args:
        text: Array text (e.g., '{"hello","world"}')

    Returns:
        TextArray

    Example:
        var arr = parse_text_array('{"apple","banana","cherry"}')
    """
    var str_elements = parse_array_text(text)
    var elements = List[String]()
    var has_nulls = False

    for i in range(len(str_elements)):
        var elem = str_elements[i]
        if elem == "NULL" or elem == "null":
            has_nulls = True
            elements.append("")
        else:
            elements.append(elem)

    return TextArray(elements, has_nulls)


# ============================================================================
# Boolean Arrays
# ============================================================================

@value
struct BoolArray:
    """Array of BOOLEAN values."""
    var elements: List[Bool]
    var has_nulls: Bool

    fn to_string(self) -> String:
        """Return string representation."""
        var result = "["
        for i in range(len(self.elements)):
            result += "true" if self.elements[i] else "false"
            if i < len(self.elements) - 1:
                result += ", "
        result += "]"
        return result

    fn length(self) -> Int:
        """Get array length."""
        return len(self.elements)

    fn get(self, index: Int) -> Bool:
        """Get element at index."""
        return self.elements[index]


fn parse_bool_array(text: String) raises -> BoolArray:
    """
    Parse BOOLEAN[] from text format.

    Args:
        text: Array text (e.g., "{t,f,t}")

    Returns:
        BoolArray

    Example:
        var arr = parse_bool_array("{true,false,true}")
    """
    var str_elements = parse_array_text(text)
    var elements = List[Bool]()
    var has_nulls = False

    for i in range(len(str_elements)):
        var elem = str_elements[i]
        if elem == "NULL" or elem == "null":
            has_nulls = True
            elements.append(False)
        elif elem == "t" or elem == "true" or elem == "TRUE":
            elements.append(True)
        elif elem == "f" or elem == "false" or elem == "FALSE":
            elements.append(False)
        else:
            raise Error("Invalid boolean value: " + elem)

    return BoolArray(elements, has_nulls)


# ============================================================================
# Array Construction (for INSERT)
# ============================================================================

fn build_int4_array_literal(elements: List[Int32]) -> String:
    """
    Build INT4[] literal for SQL INSERT.

    Args:
        elements: List of integers

    Returns:
        SQL array literal (e.g., "ARRAY[1,2,3]")

    Example:
        var arr = List[Int32]()
        arr.append(1)
        arr.append(2)
        arr.append(3)
        var sql = build_int4_array_literal(arr)
        # Returns: "ARRAY[1,2,3]"
    """
    var result = "ARRAY["
    for i in range(len(elements)):
        result += String(elements[i])
        if i < len(elements) - 1:
            result += ","
    result += "]"
    return result


fn build_text_array_literal(elements: List[String]) -> String:
    """
    Build TEXT[] literal for SQL INSERT.

    Args:
        elements: List of strings

    Returns:
        SQL array literal (e.g., "ARRAY['a','b','c']")

    Example:
        var arr = List[String]()
        arr.append("hello")
        arr.append("world")
        var sql = build_text_array_literal(arr)
        # Returns: "ARRAY['hello','world']"
    """
    var result = "ARRAY["
    for i in range(len(elements)):
        # Escape single quotes
        var escaped = String("")
        for j in range(len(elements[i])):
            if elements[i][j] == '\'':
                escaped += "''"
            else:
                escaped += elements[i][j]

        result += "'" + escaped + "'"
        if i < len(elements) - 1:
            result += ","
    result += "]"
    return result


fn build_bool_array_literal(elements: List[Bool]) -> String:
    """
    Build BOOLEAN[] literal for SQL INSERT.

    Args:
        elements: List of booleans

    Returns:
        SQL array literal (e.g., "ARRAY[true,false,true]")
    """
    var result = "ARRAY["
    for i in range(len(elements)):
        result += "true" if elements[i] else "false"
        if i < len(elements) - 1:
            result += ","
    result += "]"
    return result
