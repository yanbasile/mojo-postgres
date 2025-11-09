"""
PostgreSQL LISTEN/NOTIFY Protocol Implementation.

Implements asynchronous notification mechanism for real-time updates and pub/sub patterns.

LISTEN/NOTIFY Flow:
-------------------
1. Client sends: LISTEN channel_name
2. Server responds: CommandComplete ('C')
3. Server responds: ReadyForQuery ('Z')
4. When notification occurs:
   - Server sends: NotificationResponse ('A')
   - Message contains: PID, channel, payload

5. Client sends: NOTIFY channel_name, 'payload'
6. Server responds: CommandComplete ('C')
7. Server responds: ReadyForQuery ('Z')
8. All listening clients receive NotificationResponse ('A')

9. Client sends: UNLISTEN channel_name (or UNLISTEN *)
10. Server responds: CommandComplete ('C')
11. Server responds: ReadyForQuery ('Z')

Message Format:
--------------
NotificationResponse ('A'):
  'A' (1 byte) - Message type
  Length (4 bytes) - Message length
  PID (4 bytes) - Process ID of notifying backend
  Channel (null-terminated string) - Channel name
  Payload (null-terminated string) - Notification payload

Example:
    # Subscribe to notifications
    conn.listen("order_updates")

    # Check for notifications
    var notifications = conn.get_notifications()
    for i in range(len(notifications)):
        print("Channel:", notifications[i].channel)
        print("Payload:", notifications[i].payload)

    # Send notification
    conn.notify("order_updates", "New order: 12345")

    # Unsubscribe
    conn.unlisten("order_updates")
"""

from collections import List


# ============================================================================
# Constants
# ============================================================================

alias MSG_NOTIFICATION_RESPONSE = ord('A')  # NotificationResponse message


# ============================================================================
# Notification Data Structure
# ============================================================================

@value
struct Notification:
    """
    Represents a PostgreSQL notification.

    Contains:
    - pid: Process ID of the notifying backend
    - channel: Channel name
    - payload: Notification payload (can be empty)
    """
    var pid: Int
    var channel: String
    var payload: String

    fn to_string(self) -> String:
        """Return string representation."""
        return "Notification(pid=" + String(self.pid) + \
               ", channel='" + self.channel + "'" + \
               ", payload='" + self.payload + "')"


# ============================================================================
# Notification Queue
# ============================================================================

struct NotificationQueue:
    """
    Queue for storing received notifications.

    PostgreSQL can send NotificationResponse messages at any time,
    so we need to queue them for later retrieval.
    """
    var notifications: List[Notification]

    fn __init__(inout self):
        """Initialize empty notification queue."""
        self.notifications = List[Notification]()

    fn enqueue(inout self, notification: Notification):
        """Add notification to queue."""
        self.notifications.append(notification)

    fn dequeue(inout self) raises -> Notification:
        """
        Remove and return oldest notification.

        Raises:
            Error if queue is empty
        """
        if len(self.notifications) == 0:
            raise Error("Notification queue is empty")

        var notification = self.notifications[0]

        # Remove first element
        var new_list = List[Notification]()
        for i in range(1, len(self.notifications)):
            new_list.append(self.notifications[i])
        self.notifications = new_list

        return notification

    fn peek(self) raises -> Notification:
        """
        Return oldest notification without removing it.

        Raises:
            Error if queue is empty
        """
        if len(self.notifications) == 0:
            raise Error("Notification queue is empty")
        return self.notifications[0]

    fn is_empty(self) -> Bool:
        """Check if queue is empty."""
        return len(self.notifications) == 0

    fn count(self) -> Int:
        """Get number of notifications in queue."""
        return len(self.notifications)

    fn clear(inout self):
        """Clear all notifications from queue."""
        self.notifications = List[Notification]()

    fn get_all(inout self) -> List[Notification]:
        """
        Get and remove all notifications from queue.

        Returns:
            List of all notifications (queue becomes empty)
        """
        var all_notifications = self.notifications
        self.notifications = List[Notification]()
        return all_notifications


# ============================================================================
# Message Parsing
# ============================================================================

fn parse_notification_message(message: List[UInt8]) raises -> Notification:
    """
    Parse NotificationResponse message.

    Format:
        'A' (1 byte) - Message type
        Length (4 bytes) - Message length including self
        PID (4 bytes) - Process ID (big-endian)
        Channel (null-terminated string)
        Payload (null-terminated string)

    Args:
        message: Raw message bytes (including type byte)

    Returns:
        Notification object

    Raises:
        Error if message format is invalid
    """
    # Verify message type
    if len(message) < 1 or Int(message[0]) != MSG_NOTIFICATION_RESPONSE:
        raise Error("Invalid notification message: wrong type")

    # Skip message type (1 byte) and length (4 bytes)
    var offset = 5

    # Parse PID (4 bytes, big-endian)
    if len(message) < offset + 4:
        raise Error("Invalid notification message: too short for PID")

    var pid = (Int(message[offset]) << 24) | (Int(message[offset + 1]) << 16) | \
              (Int(message[offset + 2]) << 8) | Int(message[offset + 3])
    offset += 4

    # Parse channel name (null-terminated string)
    var channel = String("")
    while offset < len(message) and message[offset] != 0:
        channel += chr(Int(message[offset]))
        offset += 1

    if offset >= len(message):
        raise Error("Invalid notification message: channel not terminated")

    offset += 1  # Skip null terminator

    # Parse payload (null-terminated string)
    var payload = String("")
    while offset < len(message) and message[offset] != 0:
        payload += chr(Int(message[offset]))
        offset += 1

    return Notification(pid, channel, payload)


# ============================================================================
# LISTEN Command
# ============================================================================

fn build_listen_command(channel: String) -> String:
    """
    Build LISTEN SQL command.

    Args:
        channel: Channel name to subscribe to

    Returns:
        SQL command: "LISTEN channel_name"

    Example:
        var sql = build_listen_command("order_updates")
        # Returns: "LISTEN order_updates"
    """
    return "LISTEN " + channel


# ============================================================================
# NOTIFY Command
# ============================================================================

fn build_notify_command(channel: String, payload: String = "") -> String:
    """
    Build NOTIFY SQL command.

    Args:
        channel: Channel name to send notification to
        payload: Optional payload (default: empty string)

    Returns:
        SQL command: "NOTIFY channel_name, 'payload'"

    Example:
        var sql = build_notify_command("order_updates", "New order")
        # Returns: "NOTIFY order_updates, 'New order'"
    """
    if len(payload) == 0:
        return "NOTIFY " + channel
    else:
        # Escape single quotes in payload
        var escaped_payload = String("")
        for i in range(len(payload)):
            if payload[i] == '\'':
                escaped_payload += "''"  # PostgreSQL escape for single quote
            else:
                escaped_payload += payload[i]

        return "NOTIFY " + channel + ", '" + escaped_payload + "'"


# ============================================================================
# UNLISTEN Command
# ============================================================================

fn build_unlisten_command(channel: String = "") -> String:
    """
    Build UNLISTEN SQL command.

    Args:
        channel: Channel name to unsubscribe from (default: "" for all channels)

    Returns:
        SQL command: "UNLISTEN channel_name" or "UNLISTEN *"

    Example:
        var sql1 = build_unlisten_command("order_updates")
        # Returns: "UNLISTEN order_updates"

        var sql2 = build_unlisten_command()
        # Returns: "UNLISTEN *"
    """
    if len(channel) == 0:
        return "UNLISTEN *"
    else:
        return "UNLISTEN " + channel


# ============================================================================
# Channel Management
# ============================================================================

struct ChannelSubscriptions:
    """
    Tracks active LISTEN subscriptions.

    Maintains a list of channels the connection is listening to,
    useful for reconnection and debugging.
    """
    var channels: List[String]

    fn __init__(inout self):
        """Initialize empty subscription list."""
        self.channels = List[String]()

    fn add(inout self, channel: String):
        """
        Add channel to subscriptions.

        Only adds if not already subscribed.
        """
        # Check if already subscribed
        for i in range(len(self.channels)):
            if self.channels[i] == channel:
                return  # Already subscribed

        self.channels.append(channel)

    fn remove(inout self, channel: String):
        """Remove channel from subscriptions."""
        var new_channels = List[String]()
        for i in range(len(self.channels)):
            if self.channels[i] != channel:
                new_channels.append(self.channels[i])
        self.channels = new_channels

    fn remove_all(inout self):
        """Remove all channel subscriptions."""
        self.channels = List[String]()

    fn is_subscribed(self, channel: String) -> Bool:
        """Check if subscribed to channel."""
        for i in range(len(self.channels)):
            if self.channels[i] == channel:
                return True
        return False

    fn count(self) -> Int:
        """Get number of active subscriptions."""
        return len(self.channels)

    fn get_all(self) -> List[String]:
        """Get all subscribed channels."""
        return self.channels

    fn to_string(self) -> String:
        """Return string representation."""
        var result = "ChannelSubscriptions(["
        for i in range(len(self.channels)):
            result += "'" + self.channels[i] + "'"
            if i < len(self.channels) - 1:
                result += ", "
        result += "])"
        return result


# ============================================================================
# Notification Statistics
# ============================================================================

@value
struct NotificationStats:
    """Statistics for LISTEN/NOTIFY operations."""
    var total_received: Int
    var total_sent: Int
    var channels_subscribed: Int
    var queue_size: Int

    fn to_string(self) -> String:
        """Return string representation."""
        return "NotificationStats(received=" + String(self.total_received) + \
               ", sent=" + String(self.total_sent) + \
               ", subscribed=" + String(self.channels_subscribed) + \
               ", queued=" + String(self.queue_size) + ")"
