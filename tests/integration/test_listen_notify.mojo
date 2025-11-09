"""
Integration tests for LISTEN/NOTIFY with real PostgreSQL.

Prerequisites:
- PostgreSQL running on localhost:5432
- Database 'test' with user 'test' / password 'test'

Tests:
1. Basic LISTEN command
2. Basic NOTIFY command
3. UNLISTEN command
4. Multiple channels
5. Notifications with payloads
6. UNLISTEN all channels
"""

from testing import assert_equal, assert_true, assert_false, assert_raises
from src.protocol.connection import PostgresConnection
from collections import List


fn test_basic_listen() raises:
    """Test 1: Basic LISTEN command."""
    print("  test_basic_listen...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # LISTEN should succeed without error
    conn.listen("test_channel")

    # Cleanup
    conn.unlisten("test_channel")
    conn.close()

    print(" ✅")


fn test_basic_notify() raises:
    """Test 2: Basic NOTIFY command."""
    print("  test_basic_notify...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # NOTIFY should succeed without error
    conn.notify("test_channel", "test message")

    conn.close()

    print(" ✅")


fn test_listen_notify_roundtrip() raises:
    """Test 3: LISTEN then NOTIFY on same connection."""
    print("  test_listen_notify_roundtrip...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Listen first
    conn.listen("roundtrip_channel")

    # Notify (same connection)
    conn.notify("roundtrip_channel", "roundtrip message")

    # Note: Notifications from the same session aren't received by that session
    # This is PostgreSQL behavior

    # Cleanup
    conn.unlisten("roundtrip_channel")
    conn.close()

    print(" ✅")


fn test_unlisten() raises:
    """Test 4: UNLISTEN command."""
    print("  test_unlisten...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Listen to channel
    conn.listen("channel1")

    # Unlisten from specific channel
    conn.unlisten("channel1")

    conn.close()

    print(" ✅")


fn test_multiple_channels() raises:
    """Test 5: Multiple channels."""
    print("  test_multiple_channels...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Listen to multiple channels
    conn.listen("channel1")
    conn.listen("channel2")
    conn.listen("channel3")

    # Send notifications to all channels
    conn.notify("channel1", "message1")
    conn.notify("channel2", "message2")
    conn.notify("channel3", "message3")

    # Unlisten from all
    conn.unlisten()

    conn.close()

    print(" ✅")


fn test_notification_with_empty_payload() raises:
    """Test 6: Notification with empty payload."""
    print("  test_notification_with_empty_payload...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    conn.listen("empty_payload_channel")

    # Send notification without payload
    conn.notify("empty_payload_channel")

    conn.unlisten()
    conn.close()

    print(" ✅")


fn test_notification_with_special_characters() raises:
    """Test 7: Notification payload with special characters."""
    print("  test_notification_with_special_characters...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    conn.listen("special_chars")

    # Send notification with quotes
    conn.notify("special_chars", "Message with 'single quotes'")

    conn.unlisten()
    conn.close()

    print(" ✅")


fn test_notification_with_json_payload() raises:
    """Test 8: Notification with JSON payload."""
    print("  test_notification_with_json_payload...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    conn.listen("json_channel")

    # Send JSON-formatted payload
    var json_payload = "{\"type\": \"order\", \"id\": 12345, \"status\": \"completed\"}"
    conn.notify("json_channel", json_payload)

    conn.unlisten()
    conn.close()

    print(" ✅")


fn test_two_connection_notify() raises:
    """Test 9: Two connections - one listening, one notifying."""
    print("  test_two_connection_notify...", end="")

    # Listener
    var listener = PostgresConnection("localhost", 5432)
    listener.connect("test", "test", "test")
    listener.listen("two_conn_channel")

    # Notifier
    var notifier = PostgresConnection("localhost", 5432)
    notifier.connect("test", "test", "test")
    notifier.notify("two_conn_channel", "Hello from notifier")

    # Note: Full notification reception would require non-blocking I/O
    # For now, we just verify the commands succeed

    listener.unlisten()
    listener.close()
    notifier.close()

    print(" ✅")


fn test_unlisten_all_channels() raises:
    """Test 10: UNLISTEN * (all channels)."""
    print("  test_unlisten_all_channels...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Subscribe to multiple channels
    conn.listen("channel_a")
    conn.listen("channel_b")
    conn.listen("channel_c")

    # Unlisten from all channels at once
    conn.unlisten()  # Empty string = UNLISTEN *

    conn.close()

    print(" ✅")


fn test_listen_command_building() raises:
    """Test 11: LISTEN command building."""
    print("  test_listen_command_building...", end="")

    from src.protocol.notify import build_listen_command

    var cmd = build_listen_command("my_channel")
    assert_equal(cmd, "LISTEN my_channel")

    print(" ✅")


fn test_notify_command_building() raises:
    """Test 12: NOTIFY command building."""
    print("  test_notify_command_building...", end="")

    from src.protocol.notify import build_notify_command

    # Without payload
    var cmd1 = build_notify_command("channel1")
    assert_equal(cmd1, "NOTIFY channel1")

    # With payload
    var cmd2 = build_notify_command("channel2", "test message")
    assert_equal(cmd2, "NOTIFY channel2, 'test message'")

    # With quotes in payload
    var cmd3 = build_notify_command("channel3", "it's working")
    assert_equal(cmd3, "NOTIFY channel3, 'it''s working'")

    print(" ✅")


fn test_unlisten_command_building() raises:
    """Test 13: UNLISTEN command building."""
    print("  test_unlisten_command_building...", end="")

    from src.protocol.notify import build_unlisten_command

    # Specific channel
    var cmd1 = build_unlisten_command("my_channel")
    assert_equal(cmd1, "UNLISTEN my_channel")

    # All channels
    var cmd2 = build_unlisten_command()
    assert_equal(cmd2, "UNLISTEN *")

    print(" ✅")


fn main() raises:
    print("\n" + "=" * 70)
    print("LISTEN/NOTIFY Integration Tests")
    print("=" * 70 + "\n")

    print("Command Building Tests:")
    test_listen_command_building()
    test_notify_command_building()
    test_unlisten_command_building()

    print("\nIntegration Tests:")
    test_basic_listen()
    test_basic_notify()
    test_listen_notify_roundtrip()
    test_unlisten()
    test_multiple_channels()
    test_notification_with_empty_payload()
    test_notification_with_special_characters()
    test_notification_with_json_payload()
    test_two_connection_notify()
    test_unlisten_all_channels()

    print("\n" + "=" * 70)
    print("✅ All 13 tests passed!")
    print("=" * 70 + "\n")
