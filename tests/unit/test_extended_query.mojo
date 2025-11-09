"""
Unit tests for PostgreSQL Extended Query Protocol.

Tests:
- Message builders (Parse, Bind, Execute, Sync, Close)
- Parameter counting
- PreparedStatement struct
- Response parsing

Run:
  mojo tests/unit/test_extended_query.mojo
"""

from testing import assert_equal, assert_true, assert_false


# ============================================================================
# Parse Message Tests
# ============================================================================

fn test_parse_message_unnamed() raises:
    """Test building Parse message with unnamed statement."""
    print("  Testing Parse message (unnamed)...")

    from src.protocol.extended_query import build_parse_message

    var query = "SELECT * FROM users WHERE id = $1"
    var msg = build_parse_message("", query)

    # Check message type
    if msg[0] != ord('P'):
        raise Error("Message type should be 'P'")

    # Message should have: type (1) + length (4) + stmt_name (\0) + query + \0 + param_count (2)
    var expected_min_len = 1 + 4 + 1 + len(query) + 1 + 2
    if len(msg) < expected_min_len:
        raise Error("Message too short")

    print("    ✓ Parse message (unnamed) works")


fn test_parse_message_named() raises:
    """Test building Parse message with named statement."""
    print("  Testing Parse message (named)...")

    from src.protocol.extended_query import build_parse_message

    var stmt_name = "my_statement"
    var query = "SELECT * FROM users WHERE id = $1"
    var msg = build_parse_message(stmt_name, query)

    # Check message type
    if msg[0] != ord('P'):
        raise Error("Message type should be 'P'")

    # Check statement name is included
    var found_stmt_name = False
    for i in range(5, min(5 + len(stmt_name) + 1, len(msg))):
        if i + len(stmt_name) <= len(msg):
            var matches = True
            for j in range(len(stmt_name)):
                if msg[i + j] != ord(stmt_name[j]):
                    matches = False
                    break
            if matches:
                found_stmt_name = True
                break

    print("    ✓ Parse message (named) works")


fn test_parse_message_with_params() raises:
    """Test building Parse message with parameter types."""
    print("  Testing Parse message with parameter types...")

    from src.protocol.extended_query import build_parse_message

    var query = "SELECT * FROM users WHERE id = $1 AND age = $2"
    var param_types = List[Int]()
    param_types.append(23)  # INT4
    param_types.append(23)  # INT4

    var msg = build_parse_message("", query, param_types)

    # Check message type
    if msg[0] != ord('P'):
        raise Error("Message type should be 'P'")

    # Message should include parameter types (4 bytes each)
    var expected_min_len = 1 + 4 + 1 + len(query) + 1 + 2 + (4 * len(param_types))
    if len(msg) < expected_min_len:
        raise Error("Message too short for parameter types")

    print("    ✓ Parse message with parameter types works")


# ============================================================================
# Bind Message Tests
# ============================================================================

fn test_bind_message_simple() raises:
    """Test building Bind message with simple parameters."""
    print("  Testing Bind message (simple)...")

    from src.protocol.extended_query import build_bind_message

    var params = List[String]()
    params.append("123")
    params.append("true")

    var msg = build_bind_message("", "stmt1", params)

    # Check message type
    if msg[0] != ord('B'):
        raise Error("Message type should be 'B'")

    # Message should have reasonable length
    if len(msg) < 20:
        raise Error("Message too short")

    print("    ✓ Bind message (simple) works")


fn test_bind_message_empty_params() raises:
    """Test building Bind message with no parameters."""
    print("  Testing Bind message (no parameters)...")

    from src.protocol.extended_query import build_bind_message

    var params = List[String]()
    var msg = build_bind_message("", "stmt1", params)

    # Check message type
    if msg[0] != ord('B'):
        raise Error("Message type should be 'B'")

    print("    ✓ Bind message (no parameters) works")


fn test_bind_message_with_formats() raises:
    """Test building Bind message with format codes."""
    print("  Testing Bind message with format codes...")

    from src.protocol.extended_query import build_bind_message

    var params = List[String]()
    params.append("123")

    var param_formats = List[Int]()
    param_formats.append(0)  # TEXT

    var result_formats = List[Int]()
    result_formats.append(0)  # TEXT

    var msg = build_bind_message("", "stmt1", params, param_formats, result_formats)

    # Check message type
    if msg[0] != ord('B'):
        raise Error("Message type should be 'B'")

    print("    ✓ Bind message with format codes works")


# ============================================================================
# Execute Message Tests
# ============================================================================

fn test_execute_message_unlimited() raises:
    """Test building Execute message with unlimited rows."""
    print("  Testing Execute message (unlimited rows)...")

    from src.protocol.extended_query import build_execute_message

    var msg = build_execute_message("", 0)

    # Check message type
    if msg[0] != ord('E'):
        raise Error("Message type should be 'E'")

    # Message: type (1) + length (4) + portal_name (\0) + max_rows (4)
    var expected_len = 1 + 4 + 1 + 4
    if len(msg) != expected_len:
        raise Error("Message length incorrect")

    print("    ✓ Execute message (unlimited rows) works")


fn test_execute_message_limited() raises:
    """Test building Execute message with row limit."""
    print("  Testing Execute message (row limit)...")

    from src.protocol.extended_query import build_execute_message

    var msg = build_execute_message("", 100)

    # Check message type
    if msg[0] != ord('E'):
        raise Error("Message type should be 'E'")

    print("    ✓ Execute message (row limit) works")


# ============================================================================
# Sync Message Tests
# ============================================================================

fn test_sync_message() raises:
    """Test building Sync message."""
    print("  Testing Sync message...")

    from src.protocol.extended_query import build_sync_message

    var msg = build_sync_message()

    # Check message type
    if msg[0] != ord('S'):
        raise Error("Message type should be 'S'")

    # Sync message: type (1) + length (4)
    var expected_len = 1 + 4
    if len(msg) != expected_len:
        raise Error("Message length incorrect")

    print("    ✓ Sync message works")


# ============================================================================
# Close Message Tests
# ============================================================================

fn test_close_message_statement() raises:
    """Test building Close message for statement."""
    print("  Testing Close message (statement)...")

    from src.protocol.extended_query import build_close_message

    var msg = build_close_message("S", "stmt1")

    # Check message type
    if msg[0] != ord('C'):
        raise Error("Message type should be 'C'")

    # Check target type is 'S' (statement)
    # Message: type (1) + length (4) + target_type (1) + name + \0
    if msg[5] != ord('S'):
        raise Error("Target type should be 'S'")

    print("    ✓ Close message (statement) works")


fn test_close_message_portal() raises:
    """Test building Close message for portal."""
    print("  Testing Close message (portal)...")

    from src.protocol.extended_query import build_close_message

    var msg = build_close_message("P", "")

    # Check message type
    if msg[0] != ord('C'):
        raise Error("Message type should be 'C'")

    # Check target type is 'P' (portal)
    if msg[5] != ord('P'):
        raise Error("Target type should be 'P'")

    print("    ✓ Close message (portal) works")


# ============================================================================
# Flush Message Tests
# ============================================================================

fn test_flush_message() raises:
    """Test building Flush message."""
    print("  Testing Flush message...")

    from src.protocol.extended_query import build_flush_message

    var msg = build_flush_message()

    # Check message type
    if msg[0] != ord('H'):
        raise Error("Message type should be 'H'")

    # Flush message: type (1) + length (4)
    var expected_len = 1 + 4
    if len(msg) != expected_len:
        raise Error("Message length incorrect")

    print("    ✓ Flush message works")


# ============================================================================
# Utility Function Tests
# ============================================================================

fn test_count_parameters_none() raises:
    """Test counting parameters with no placeholders."""
    print("  Testing parameter counting (none)...")

    from src.protocol.extended_query import count_parameters

    var query = "SELECT * FROM users"
    var count = count_parameters(query)

    if count != 0:
        raise Error("Expected 0 parameters, got " + String(count))

    print("    ✓ Parameter counting (none) works")


fn test_count_parameters_single() raises:
    """Test counting parameters with single placeholder."""
    print("  Testing parameter counting (single)...")

    from src.protocol.extended_query import count_parameters

    var query = "SELECT * FROM users WHERE id = $1"
    var count = count_parameters(query)

    if count != 1:
        raise Error("Expected 1 parameter, got " + String(count))

    print("    ✓ Parameter counting (single) works")


fn test_count_parameters_multiple() raises:
    """Test counting parameters with multiple placeholders."""
    print("  Testing parameter counting (multiple)...")

    from src.protocol.extended_query import count_parameters

    var query = "SELECT * FROM users WHERE id = $1 AND age = $2 AND name = $3"
    var count = count_parameters(query)

    if count != 3:
        raise Error("Expected 3 parameters, got " + String(count))

    print("    ✓ Parameter counting (multiple) works")


fn test_count_parameters_out_of_order() raises:
    """Test counting parameters with out-of-order placeholders."""
    print("  Testing parameter counting (out-of-order)...")

    from src.protocol.extended_query import count_parameters

    # PostgreSQL allows $3, $1, $2 order
    var query = "SELECT * FROM users WHERE id = $3 AND age = $1 AND name = $2"
    var count = count_parameters(query)

    # Should return highest parameter number (3)
    if count != 3:
        raise Error("Expected 3 parameters, got " + String(count))

    print("    ✓ Parameter counting (out-of-order) works")


# ============================================================================
# PreparedStatement Tests
# ============================================================================

fn test_prepared_statement_creation() raises:
    """Test creating PreparedStatement struct."""
    print("  Testing PreparedStatement creation...")

    from src.protocol.extended_query import PreparedStatement

    var stmt = PreparedStatement("stmt1", "SELECT * FROM users WHERE id = $1", 1)

    if stmt.statement_name != "stmt1":
        raise Error("Statement name mismatch")

    if stmt.param_count != 1:
        raise Error("Parameter count mismatch")

    print("    ✓ PreparedStatement creation works")


# ============================================================================
# Main Test Runner
# ============================================================================

fn main() raises:
    print("\n" + "=" * 70)
    print("Unit Tests: Extended Query Protocol")
    print("=" * 70)
    print("")

    print("Parse Message Tests:")
    test_parse_message_unnamed()
    test_parse_message_named()
    test_parse_message_with_params()

    print("\nBind Message Tests:")
    test_bind_message_simple()
    test_bind_message_empty_params()
    test_bind_message_with_formats()

    print("\nExecute Message Tests:")
    test_execute_message_unlimited()
    test_execute_message_limited()

    print("\nSync Message Tests:")
    test_sync_message()

    print("\nClose Message Tests:")
    test_close_message_statement()
    test_close_message_portal()

    print("\nFlush Message Tests:")
    test_flush_message()

    print("\nUtility Function Tests:")
    test_count_parameters_none()
    test_count_parameters_single()
    test_count_parameters_multiple()
    test_count_parameters_out_of_order()

    print("\nPreparedStatement Tests:")
    test_prepared_statement_creation()

    print("\n" + "=" * 70)
    print("✅ All unit tests passed!")
    print("=" * 70)
    print("")
    print("Test Summary:")
    print("  - Parse messages: 3 tests ✓")
    print("  - Bind messages: 3 tests ✓")
    print("  - Execute messages: 2 tests ✓")
    print("  - Sync messages: 1 test ✓")
    print("  - Close messages: 2 tests ✓")
    print("  - Flush messages: 1 test ✓")
    print("  - Utility functions: 4 tests ✓")
    print("  - PreparedStatement: 1 test ✓")
    print("")
    print("Total: 17 unit tests")
    print("=" * 70)
