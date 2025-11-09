"""
LISTEN/NOTIFY Examples - Real-Time Notifications.

Demonstrates PostgreSQL LISTEN/NOTIFY for real-time updates and pub/sub patterns.

Examples:
1. Basic LISTEN/NOTIFY between two connections
2. Multiple channels
3. Broadcasting to multiple listeners
4. Notification with payloads

Prerequisites:
- PostgreSQL running on localhost:5432
- Database 'test' with user 'test' / password 'test'

Note: LISTEN/NOTIFY requires at least two database connections:
- One to listen for notifications
- One to send notifications
"""

from src.protocol.connection import PostgresConnection
from time import sleep


fn example1_basic_listen_notify() raises:
    """Example 1: Basic LISTEN/NOTIFY between two connections."""
    print("=" * 70)
    print("Example 1: Basic LISTEN/NOTIFY")
    print("=" * 70)

    # Connection 1: Listener
    var listener = PostgresConnection("localhost", 5432)
    listener.connect("test", "test", "test")
    print("✅ Listener connected")

    # Subscribe to channel
    listener.listen("my_channel")
    print("✅ Listening on channel: my_channel")

    # Connection 2: Notifier
    var notifier = PostgresConnection("localhost", 5432)
    notifier.connect("test", "test", "test")
    print("✅ Notifier connected")

    # Send notification
    print("\n📤 Sending notification...")
    notifier.notify("my_channel", "Hello from notifier!")
    print("✅ Notification sent")

    # Note: In a full implementation, we would check for notifications here
    # For now, this demonstrates the API

    # Cleanup
    listener.unlisten("my_channel")
    print("\n✅ Unsubscribed from my_channel")

    listener.close()
    notifier.close()
    print("✅ Example 1 complete!\n")


fn example2_multiple_channels() raises:
    """Example 2: Multiple channels."""
    print("=" * 70)
    print("Example 2: Multiple Channels")
    print("=" * 70)

    var listener = PostgresConnection("localhost", 5432)
    listener.connect("test", "test", "test")

    # Subscribe to multiple channels
    listener.listen("orders")
    listener.listen("inventory")
    listener.listen("users")
    print("✅ Listening on 3 channels: orders, inventory, users")

    var notifier = PostgresConnection("localhost", 5432)
    notifier.connect("test", "test", "test")

    # Send notifications to different channels
    print("\n📤 Sending notifications to different channels...")
    notifier.notify("orders", "New order #12345")
    notifier.notify("inventory", "Stock low on item #67")
    notifier.notify("users", "New user registered: alice")
    print("✅ Sent 3 notifications")

    # Unsubscribe from specific channel
    listener.unlisten("inventory")
    print("\n✅ Unsubscribed from 'inventory' channel")

    # Unsubscribe from all channels
    listener.unlisten()
    print("✅ Unsubscribed from all channels")

    listener.close()
    notifier.close()
    print("\n✅ Example 2 complete!\n")


fn example3_broadcasting() raises:
    """Example 3: Broadcasting to multiple listeners."""
    print("=" * 70)
    print("Example 3: Broadcasting to Multiple Listeners")
    print("=" * 70)

    # Create multiple listeners
    var listener1 = PostgresConnection("localhost", 5432)
    listener1.connect("test", "test", "test")
    listener1.listen("broadcast")
    print("✅ Listener 1 subscribed to 'broadcast'")

    var listener2 = PostgresConnection("localhost", 5432)
    listener2.connect("test", "test", "test")
    listener2.listen("broadcast")
    print("✅ Listener 2 subscribed to 'broadcast'")

    var listener3 = PostgresConnection("localhost", 5432)
    listener3.connect("test", "test", "test")
    listener3.listen("broadcast")
    print("✅ Listener 3 subscribed to 'broadcast'")

    # Broadcaster
    var broadcaster = PostgresConnection("localhost", 5432)
    broadcaster.connect("test", "test", "test")
    print("✅ Broadcaster connected")

    # Send broadcast notification
    print("\n📢 Broadcasting message to all listeners...")
    broadcaster.notify("broadcast", "System maintenance in 5 minutes")
    print("✅ Broadcast sent - all 3 listeners will receive it")

    # Cleanup
    listener1.unlisten()
    listener2.unlisten()
    listener3.unlisten()

    listener1.close()
    listener2.close()
    listener3.close()
    broadcaster.close()

    print("\n✅ Example 3 complete!\n")


fn example4_payloads() raises:
    """Example 4: Notifications with different payload formats."""
    print("=" * 70)
    print("Example 4: Notification Payloads")
    print("=" * 70)

    var listener = PostgresConnection("localhost", 5432)
    listener.connect("test", "test", "test")
    listener.listen("events")
    print("✅ Listening on 'events' channel")

    var notifier = PostgresConnection("localhost", 5432)
    notifier.connect("test", "test", "test")

    # Send notifications with various payloads
    print("\n📤 Sending notifications with different payload formats...")

    # Simple message
    notifier.notify("events", "Simple message")
    print("✅ Sent: Simple message")

    # JSON-like payload
    notifier.notify("events", "{\"type\": \"order\", \"id\": 12345, \"amount\": 99.99}")
    print("✅ Sent: JSON payload")

    # CSV-like payload
    notifier.notify("events", "user,login,alice,2024-01-15T10:30:00Z")
    print("✅ Sent: CSV payload")

    # Empty payload
    notifier.notify("events")
    print("✅ Sent: Empty payload")

    # Payload with special characters
    notifier.notify("events", "Message with 'quotes' and \"double quotes\"")
    print("✅ Sent: Payload with special characters")

    # Cleanup
    listener.unlisten()
    listener.close()
    notifier.close()

    print("\n✅ Example 4 complete!\n")


fn example5_event_driven_pattern() raises:
    """Example 5: Event-driven architecture pattern."""
    print("=" * 70)
    print("Example 5: Event-Driven Architecture Pattern")
    print("=" * 70)

    # Event processor (listener)
    var processor = PostgresConnection("localhost", 5432)
    processor.connect("test", "test", "test")

    # Subscribe to different event types
    processor.listen("order_created")
    processor.listen("order_updated")
    processor.listen("order_cancelled")
    print("✅ Event processor listening for order events")

    # Application (notifier)
    var app = PostgresConnection("localhost", 5432)
    app.connect("test", "test", "test")

    # Simulate order lifecycle
    print("\n📋 Simulating order lifecycle...")

    print("  1. Creating order...")
    app.notify("order_created", "{\"order_id\": 12345, \"customer\": \"alice\", \"total\": 99.99}")

    print("  2. Updating order...")
    app.notify("order_updated", "{\"order_id\": 12345, \"status\": \"processing\"}")

    print("  3. Order cancelled...")
    app.notify("order_cancelled", "{\"order_id\": 12345, \"reason\": \"customer_request\"}")

    print("\n✅ Order lifecycle events sent")
    print("   Event processor would handle these events asynchronously")

    # Cleanup
    processor.unlisten()
    processor.close()
    app.close()

    print("\n✅ Example 5 complete!\n")


fn example6_database_triggers() raises:
    """Example 6: Database triggers with NOTIFY (demonstration)."""
    print("=" * 70)
    print("Example 6: Database Triggers with NOTIFY")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table with trigger
    print("Creating table with NOTIFY trigger...")

    var _ = conn.query("DROP TABLE IF EXISTS audit_log CASCADE")
    var __ = conn.query("""
        CREATE TABLE audit_log (
            id SERIAL PRIMARY KEY,
            action TEXT,
            username TEXT,
            timestamp TIMESTAMP DEFAULT NOW()
        )
    """)

    # Create trigger function
    var ___ = conn.query("""
        CREATE OR REPLACE FUNCTION notify_audit()
        RETURNS TRIGGER AS $$
        BEGIN
            PERFORM pg_notify('audit_events',
                'action=' || NEW.action || ',user=' || NEW.username);
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
    """)

    # Create trigger
    var ____ = conn.query("""
        CREATE TRIGGER audit_notify_trigger
        AFTER INSERT ON audit_log
        FOR EACH ROW
        EXECUTE FUNCTION notify_audit();
    """)

    print("✅ Trigger created: will send NOTIFY on INSERT")

    # Listener for audit events
    var listener = PostgresConnection("localhost", 5432)
    listener.connect("test", "test", "test")
    listener.listen("audit_events")
    print("✅ Listening for audit events")

    # Insert data (will trigger NOTIFY)
    print("\n📝 Inserting audit log entry...")
    var _____ = conn.query("INSERT INTO audit_log (action, username) VALUES ('login', 'alice')")
    print("✅ Inserted - trigger should send notification")

    var ______ = conn.query("INSERT INTO audit_log (action, username) VALUES ('logout', 'alice')")
    print("✅ Inserted - trigger should send another notification")

    # Cleanup
    listener.unlisten()
    var _______ = conn.query("DROP TABLE IF EXISTS audit_log CASCADE")
    var ________ = conn.query("DROP FUNCTION IF EXISTS notify_audit()")

    listener.close()
    conn.close()

    print("\n✅ Example 6 complete!\n")


fn main() raises:
    print("\n")
    print("🔥 LISTEN/NOTIFY Examples")
    print("Real-Time Notifications & Pub/Sub Patterns")
    print("\n")

    # Run examples
    example1_basic_listen_notify()
    example2_multiple_channels()
    example3_broadcasting()
    example4_payloads()
    example5_event_driven_pattern()
    example6_database_triggers()

    print("=" * 70)
    print("🎉 All examples completed successfully!")
    print("=" * 70)
    print("\n💡 Key Takeaways:")
    print("   - LISTEN/NOTIFY enables real-time communication")
    print("   - Pub/sub pattern for decoupled architectures")
    print("   - Multiple listeners can subscribe to same channel")
    print("   - Payloads can be any format (JSON, CSV, plain text)")
    print("   - Database triggers can send notifications automatically")
    print("   - Ideal for: event-driven apps, real-time dashboards, webhooks")
    print("\n💡 Use Cases:")
    print("   - Real-time notifications (order status, alerts)")
    print("   - Cache invalidation")
    print("   - Microservice communication")
    print("   - Live data updates (dashboards, charts)")
    print("   - Background job coordination")
    print("\n")
