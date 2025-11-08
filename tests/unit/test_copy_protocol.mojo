"""
Unit tests for COPY protocol message builders.

Tests:
1. CopyData message building
2. CopyDone message building
3. CopyFail message building
4. Text format row building
5. Text format value escaping
6. Binary format header building
7. Binary format row building
8. Binary format trailer building
"""

from testing import assert_equal, assert_true, assert_false, assert_raises
from src.protocol.copy_protocol import *


fn test_build_copy_data_message() raises:
    """Test CopyData message construction."""
    print("  test_build_copy_data_message...", end="")

    var data = List[UInt8]()
    data.append(ord('H'))
    data.append(ord('i'))

    var msg = build_copy_data_message(data)

    # Check message type
    assert_equal(Int(msg[0]), MSG_COPY_DATA)

    # Check length (4 + 2 = 6)
    var length = (Int(msg[1]) << 24) | (Int(msg[2]) << 16) | (Int(msg[3]) << 8) | Int(msg[4])
    assert_equal(length, 6)

    # Check data
    assert_equal(Int(msg[5]), ord('H'))
    assert_equal(Int(msg[6]), ord('i'))

    print(" ✅")


fn test_build_copy_done_message() raises:
    """Test CopyDone message construction."""
    print("  test_build_copy_done_message...", end="")

    var msg = build_copy_done_message()

    # Check message type
    assert_equal(Int(msg[0]), MSG_COPY_DONE)

    # Check length (always 4)
    var length = (Int(msg[1]) << 24) | (Int(msg[2]) << 16) | (Int(msg[3]) << 8) | Int(msg[4])
    assert_equal(length, 4)

    # Total message size should be 5 bytes
    assert_equal(len(msg), 5)

    print(" ✅")


fn test_build_copy_fail_message() raises:
    """Test CopyFail message construction."""
    print("  test_build_copy_fail_message...", end="")

    var error = "Test error"
    var msg = build_copy_fail_message(error)

    # Check message type
    assert_equal(Int(msg[0]), MSG_COPY_FAIL)

    # Check length (4 + error length + 1 for null)
    var length = (Int(msg[1]) << 24) | (Int(msg[2]) << 16) | (Int(msg[3]) << 8) | Int(msg[4])
    assert_equal(length, 4 + len(error) + 1)

    # Check error message
    for i in range(len(error)):
        assert_equal(Int(msg[5 + i]), ord(error[i]))

    # Check null terminator
    assert_equal(Int(msg[5 + len(error)]), 0)

    print(" ✅")


fn test_escape_copy_value() raises:
    """Test value escaping for COPY text format."""
    print("  test_escape_copy_value...", end="")

    # Test tab escape
    var result1 = escape_copy_value("Hello\tWorld")
    assert_equal(result1, "Hello\\tWorld")

    # Test newline escape
    var result2 = escape_copy_value("Line1\nLine2")
    assert_equal(result2, "Line1\\nLine2")

    # Test carriage return escape
    var result3 = escape_copy_value("Text\rMore")
    assert_equal(result3, "Text\\rMore")

    # Test backslash escape
    var result4 = escape_copy_value("Path\\File")
    assert_equal(result4, "Path\\\\File")

    # Test normal text (no escaping)
    var result5 = escape_copy_value("Normal text")
    assert_equal(result5, "Normal text")

    print(" ✅")


fn test_build_copy_row_text() raises:
    """Test text format row building."""
    print("  test_build_copy_row_text...", end="")

    var values = List[String]()
    values.append("Alice")
    values.append("30")
    values.append("alice@example.com")

    var row = build_copy_row_text(values)

    # Expected: "Alice\t30\talice@example.com\n"
    var expected = "Alice\t30\talice@example.com\n"

    # Check length
    assert_equal(len(row), len(expected))

    # Check content
    for i in range(len(expected)):
        assert_equal(Int(row[i]), ord(expected[i]))

    print(" ✅")


fn test_build_copy_row_text_with_escaping() raises:
    """Test text format row with special characters."""
    print("  test_build_copy_row_text_with_escaping...", end="")

    var values = List[String]()
    values.append("Tab\there")
    values.append("New\nline")

    var row = build_copy_row_text(values)

    # Expected: "Tab\\there\tNew\\nline\n"
    var expected = "Tab\\there\tNew\\nline\n"

    # Check length
    assert_equal(len(row), len(expected))

    # Check content
    for i in range(len(expected)):
        assert_equal(Int(row[i]), ord(expected[i]))

    print(" ✅")


fn test_build_copy_null_row_text() raises:
    """Test text format row with NULL values."""
    print("  test_build_copy_null_row_text...", end="")

    var values = List[String]()
    values.append("Alice")
    values.append("")  # Will be NULL
    values.append("30")

    var null_flags = List[Bool]()
    null_flags.append(False)
    null_flags.append(True)  # Middle value is NULL
    null_flags.append(False)

    var row = build_copy_null_row_text(values, null_flags)

    # Expected: "Alice\t\\N\t30\n"
    var expected = "Alice\t\\N\t30\n"

    # Check length
    assert_equal(len(row), len(expected))

    # Check content
    for i in range(len(expected)):
        assert_equal(Int(row[i]), ord(expected[i]))

    print(" ✅")


fn test_build_copy_header_binary() raises:
    """Test binary format header."""
    print("  test_build_copy_header_binary...", end="")

    var header = build_copy_header_binary()

    # Check signature "PGCOPY\n\xff\r\n\0"
    var sig = PGCOPY_HEADER_SIGNATURE
    for i in range(len(sig)):
        assert_equal(Int(header[i]), ord(sig[i]))

    # Check flags (4 bytes after signature)
    var flags_offset = len(sig)
    var flags = (Int(header[flags_offset]) << 24) | (Int(header[flags_offset + 1]) << 16) | \
                (Int(header[flags_offset + 2]) << 8) | Int(header[flags_offset + 3])
    assert_equal(flags, PGCOPY_HEADER_FLAGS)

    # Check extension length (4 bytes after flags)
    var ext_offset = flags_offset + 4
    var ext_len = (Int(header[ext_offset]) << 24) | (Int(header[ext_offset + 1]) << 16) | \
                  (Int(header[ext_offset + 2]) << 8) | Int(header[ext_offset + 3])
    assert_equal(ext_len, PGCOPY_HEADER_EXTENSION)

    # Total header size: 11 (signature) + 4 (flags) + 4 (extension) = 19
    assert_equal(len(header), 19)

    print(" ✅")


fn test_build_copy_row_binary() raises:
    """Test binary format row building."""
    print("  test_build_copy_row_binary...", end="")

    var values = List[List[UInt8]]()

    # First field: "Test"
    var field1 = List[UInt8]()
    field1.append(ord('T'))
    field1.append(ord('e'))
    field1.append(ord('s'))
    field1.append(ord('t'))
    values.append(field1)

    # Second field: "42"
    var field2 = List[UInt8]()
    field2.append(ord('4'))
    field2.append(ord('2'))
    values.append(field2)

    var null_flags = List[Bool]()
    null_flags.append(False)
    null_flags.append(False)

    var row = build_copy_row_binary(values, null_flags)

    # Field count (2 bytes) = 2
    var field_count = (Int(row[0]) << 8) | Int(row[1])
    assert_equal(field_count, 2)

    # First field length (4 bytes) = 4
    var len1 = (Int(row[2]) << 24) | (Int(row[3]) << 16) | (Int(row[4]) << 8) | Int(row[5])
    assert_equal(len1, 4)

    # First field data
    assert_equal(Int(row[6]), ord('T'))
    assert_equal(Int(row[7]), ord('e'))
    assert_equal(Int(row[8]), ord('s'))
    assert_equal(Int(row[9]), ord('t'))

    # Second field length (4 bytes) = 2
    var len2 = (Int(row[10]) << 24) | (Int(row[11]) << 16) | (Int(row[12]) << 8) | Int(row[13])
    assert_equal(len2, 2)

    # Second field data
    assert_equal(Int(row[14]), ord('4'))
    assert_equal(Int(row[15]), ord('2'))

    print(" ✅")


fn test_build_copy_row_binary_with_null() raises:
    """Test binary format row with NULL value."""
    print("  test_build_copy_row_binary_with_null...", end="")

    var values = List[List[UInt8]]()

    # First field: "Test"
    var field1 = List[UInt8]()
    field1.append(ord('T'))
    field1.append(ord('e'))
    field1.append(ord('s'))
    field1.append(ord('t'))
    values.append(field1)

    # Second field: NULL
    var field2 = List[UInt8]()
    values.append(field2)

    var null_flags = List[Bool]()
    null_flags.append(False)
    null_flags.append(True)  # Second field is NULL

    var row = build_copy_row_binary(values, null_flags)

    # Field count = 2
    var field_count = (Int(row[0]) << 8) | Int(row[1])
    assert_equal(field_count, 2)

    # First field length = 4
    var len1 = (Int(row[2]) << 24) | (Int(row[3]) << 16) | (Int(row[4]) << 8) | Int(row[5])
    assert_equal(len1, 4)

    # Second field length = -1 (NULL marker)
    var len2 = (Int(row[10]) << 24) | (Int(row[11]) << 16) | (Int(row[12]) << 8) | Int(row[13])
    assert_equal(len2, -1)

    print(" ✅")


fn test_build_copy_trailer_binary() raises:
    """Test binary format trailer."""
    print("  test_build_copy_trailer_binary...", end="")

    var trailer = build_copy_trailer_binary()

    # Trailer is just -1 as 2-byte field count
    assert_equal(len(trailer), 2)
    assert_equal(Int(trailer[0]), 0xFF)
    assert_equal(Int(trailer[1]), 0xFF)

    print(" ✅")


fn main() raises:
    print("\n" + "=" * 70)
    print("COPY Protocol Unit Tests")
    print("=" * 70 + "\n")

    print("Message Builders:")
    test_build_copy_data_message()
    test_build_copy_done_message()
    test_build_copy_fail_message()

    print("\nText Format:")
    test_escape_copy_value()
    test_build_copy_row_text()
    test_build_copy_row_text_with_escaping()
    test_build_copy_null_row_text()

    print("\nBinary Format:")
    test_build_copy_header_binary()
    test_build_copy_row_binary()
    test_build_copy_row_binary_with_null()
    test_build_copy_trailer_binary()

    print("\n" + "=" * 70)
    print("✅ All 12 tests passed!")
    print("=" * 70 + "\n")
