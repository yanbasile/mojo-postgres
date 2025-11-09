"""
PostgreSQL Additional Types Examples.

Demonstrates UUID, INET/CIDR, and INTERVAL type support.

Types Covered:
- UUID (Universally Unique Identifier)
- INET (IP address with optional netmask)
- CIDR (Network address)
- INTERVAL (Time intervals)

Examples:
1. UUID operations (generate, query, validate)
2. INET operations (IP addresses with netmasks)
3. CIDR operations (network addresses)
4. INTERVAL operations (time calculations)
5. Practical use cases

Prerequisites:
- PostgreSQL running on localhost:5432
- Database 'test' with user 'test' / password 'test'
- pgcrypto extension (for UUID generation): CREATE EXTENSION IF NOT EXISTS pgcrypto;
"""

from src.protocol.connection import PostgresConnection
from src.types.additional_types import (
    build_uuid_literal,
    build_inet_literal,
    build_cidr_literal,
    build_interval_literal,
    validate_uuid,
    validate_ipv4,
)


fn example1_uuid_operations() raises:
    """Example 1: UUID operations."""
    print("=" * 70)
    print("Example 1: UUID Operations")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")
    print("✅ Connected to PostgreSQL")

    # Enable pgcrypto extension for gen_random_uuid()
    print("\n📦 Enabling pgcrypto extension...")
    try:
        var _ = conn.query("CREATE EXTENSION IF NOT EXISTS pgcrypto")
        print("✅ pgcrypto extension enabled")
    except e:
        print("⚠️  Note: pgcrypto may already exist or PostgreSQL 13+ has built-in gen_random_uuid()")

    # Generate UUID v4
    print("\n1️⃣  Generate UUID v4:")
    var result1 = conn.query("SELECT gen_random_uuid()")
    var uuid1 = result1.get_uuid(0, 0)
    print("   Query: SELECT gen_random_uuid()")
    print("   UUID:", uuid1.to_string())
    print("   Canonical:", uuid1.to_canonical())
    print("   Is Nil:", uuid1.is_nil())

    # Parse specific UUID
    print("\n2️⃣  Parse specific UUID:")
    var result2 = conn.query("SELECT '550e8400-e29b-41d4-a716-446655440000'::UUID")
    var uuid2 = result2.get_uuid(0, 0)
    print("   Query: SELECT '550e8400-e29b-41d4-a716-446655440000'::UUID")
    print("   UUID:", uuid2.to_string())

    # Nil UUID
    print("\n3️⃣  Nil UUID (all zeros):")
    var result3 = conn.query("SELECT '00000000-0000-0000-0000-000000000000'::UUID")
    var uuid3 = result3.get_uuid(0, 0)
    print("   Query: SELECT '00000000-0000-0000-0000-000000000000'::UUID")
    print("   UUID:", uuid3.to_string())
    print("   Is Nil:", uuid3.is_nil())

    # Validate UUID format
    print("\n4️⃣  Validate UUID format:")
    var valid_uuid = "550e8400-e29b-41d4-a716-446655440000"
    var invalid_uuid = "not-a-uuid"
    print("   Valid UUID '" + valid_uuid + "':", validate_uuid(valid_uuid))
    print("   Invalid UUID '" + invalid_uuid + "':", validate_uuid(invalid_uuid))

    conn.close()
    print("\n✅ Example 1 complete!\n")


fn example2_uuid_table_operations() raises:
    """Example 2: UUID as primary key."""
    print("=" * 70)
    print("Example 2: UUID as Primary Key")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table with UUID primary key
    print("\n📝 Creating table with UUID primary key...")
    var _ = conn.query("DROP TABLE IF EXISTS users")
    var __ = conn.query("""
        CREATE TABLE users (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            username TEXT NOT NULL,
            email TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    print("✅ Table created: users (id UUID, username, email, created_at)")

    # Insert users (UUID auto-generated)
    print("\n📥 Inserting users with auto-generated UUIDs...")
    var ___ = conn.query("INSERT INTO users (username, email) VALUES ('alice', 'alice@example.com')")
    var ____ = conn.query("INSERT INTO users (username, email) VALUES ('bob', 'bob@example.com')")
    var _____ = conn.query("INSERT INTO users (username, email) VALUES ('charlie', 'charlie@example.com')")
    print("✅ Inserted 3 users")

    # Query users
    print("\n📊 Querying users...")
    var result = conn.query("SELECT id, username, email FROM users ORDER BY username")

    print("\nUsers in database:")
    for row in range(result.row_count()):
        var user_id = result.get_uuid(row, 0)
        var username = result.get_string(row, 1)
        var email = result.get_string(row, 2)

        print(f"\n  User: {username}")
        print(f"    UUID: {user_id.to_string()}")
        print(f"    Email: {email}")

    # Query specific user by UUID
    print("\n🔍 Query specific user by UUID...")
    var first_uuid = result.get_uuid(0, 0)
    var query = "SELECT username FROM users WHERE id = '" + first_uuid.to_string() + "'::UUID"
    var result2 = conn.query(query)
    var found_username = result2.get_string(0, 0)
    print(f"   Found user: {found_username}")

    # Cleanup
    var ______ = conn.query("DROP TABLE users")

    conn.close()
    print("\n✅ Example 2 complete!\n")


fn example3_inet_operations() raises:
    """Example 3: INET operations."""
    print("=" * 70)
    print("Example 3: INET Operations (IP Addresses)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # IPv4 with netmask
    print("\n1️⃣  IPv4 with netmask:")
    var result1 = conn.query("SELECT '192.168.1.5/24'::INET")
    var ip1 = result1.get_inet(0, 0)
    print("   Query: SELECT '192.168.1.5/24'::INET")
    print("   Address:", ip1.address)
    print("   Netmask:", ip1.netmask)
    print("   Full:", ip1.to_string())
    print("   Has netmask:", ip1.has_netmask)
    print("   Is IPv4:", ip1.is_ipv4())

    # IPv4 without netmask
    print("\n2️⃣  IPv4 without netmask:")
    var result2 = conn.query("SELECT '192.168.1.5'::INET")
    var ip2 = result2.get_inet(0, 0)
    print("   Query: SELECT '192.168.1.5'::INET")
    print("   Address:", ip2.address)
    print("   Full:", ip2.to_string())
    print("   Has netmask:", ip2.has_netmask)

    # IPv6
    print("\n3️⃣  IPv6 address:")
    var result3 = conn.query("SELECT '2001:db8::1/64'::INET")
    var ip3 = result3.get_inet(0, 0)
    print("   Query: SELECT '2001:db8::1/64'::INET")
    print("   Address:", ip3.address)
    print("   Netmask:", ip3.netmask)
    print("   Full:", ip3.to_string())
    print("   Is IPv6:", ip3.is_ipv6())

    # Localhost
    print("\n4️⃣  Localhost:")
    var result4 = conn.query("SELECT '127.0.0.1'::INET")
    var ip4 = result4.get_inet(0, 0)
    print("   Query: SELECT '127.0.0.1'::INET")
    print("   Address:", ip4.to_string())

    # INET operations
    print("\n5️⃣  INET operations:")

    # Network contains
    var result5 = conn.query("SELECT '192.168.1.0/24'::INET >> '192.168.1.5'::INET")
    var contains = result5.get_bool(0, 0)
    print("   '192.168.1.0/24' contains '192.168.1.5':", contains)

    # Broadcast address
    var result6 = conn.query("SELECT broadcast('192.168.1.0/24'::INET)")
    var broadcast = result6.get_inet(0, 0)
    print("   Broadcast of '192.168.1.0/24':", broadcast.to_string())

    # Network address
    var result7 = conn.query("SELECT network('192.168.1.5/24'::INET)")
    var network = result7.get_inet(0, 0)
    print("   Network of '192.168.1.5/24':", network.to_string())

    # Validate IPv4
    print("\n6️⃣  Validate IPv4 format:")
    var valid_ip = "192.168.1.1"
    var invalid_ip = "999.999.999.999"
    print("   Valid IP '" + valid_ip + "':", validate_ipv4(valid_ip))
    print("   Invalid IP '" + invalid_ip + "':", validate_ipv4(invalid_ip))

    conn.close()
    print("\n✅ Example 3 complete!\n")


fn example4_cidr_operations() raises:
    """Example 4: CIDR operations."""
    print("=" * 70)
    print("Example 4: CIDR Operations (Network Addresses)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Basic CIDR
    print("\n1️⃣  Basic CIDR:")
    var result1 = conn.query("SELECT '192.168.1.0/24'::CIDR")
    var cidr1 = result1.get_cidr(0, 0)
    print("   Query: SELECT '192.168.1.0/24'::CIDR")
    print("   Network:", cidr1.network)
    print("   Netmask:", cidr1.netmask)
    print("   Full:", cidr1.to_string())

    # Different network sizes
    print("\n2️⃣  Different network sizes:")
    var result2 = conn.query("SELECT '10.0.0.0/8'::CIDR")
    var cidr2 = result2.get_cidr(0, 0)
    print("   /8 network:", cidr2.to_string())

    var result3 = conn.query("SELECT '172.16.0.0/16'::CIDR")
    var cidr3 = result3.get_cidr(0, 0)
    print("   /16 network:", cidr3.to_string())

    var result4 = conn.query("SELECT '192.168.0.0/24'::CIDR")
    var cidr4 = result4.get_cidr(0, 0)
    print("   /24 network:", cidr4.to_string())

    # IPv6 CIDR
    print("\n3️⃣  IPv6 CIDR:")
    var result5 = conn.query("SELECT '2001:db8::/32'::CIDR")
    var cidr5 = result5.get_cidr(0, 0)
    print("   Query: SELECT '2001:db8::/32'::CIDR")
    print("   Network:", cidr5.to_string())

    conn.close()
    print("\n✅ Example 4 complete!\n")


fn example5_interval_operations() raises:
    """Example 5: INTERVAL operations."""
    print("=" * 70)
    print("Example 5: INTERVAL Operations (Time Intervals)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Simple intervals
    print("\n1️⃣  Simple intervals:")

    var result1 = conn.query("SELECT INTERVAL '1 day'")
    var interval1 = result1.get_interval(0, 0)
    print("   '1 day':", interval1.to_string())
    print("   Total seconds:", interval1.to_total_seconds())
    print("   Total days:", interval1.to_total_days())

    var result2 = conn.query("SELECT INTERVAL '2 hours'")
    var interval2 = result2.get_interval(0, 0)
    print("   '2 hours':", interval2.to_string())

    var result3 = conn.query("SELECT INTERVAL '30 minutes'")
    var interval3 = result3.get_interval(0, 0)
    print("   '30 minutes':", interval3.to_string())

    # Complex intervals
    print("\n2️⃣  Complex intervals:")

    var result4 = conn.query("SELECT INTERVAL '2 days 3 hours 30 minutes'")
    var interval4 = result4.get_interval(0, 0)
    print("   '2 days 3 hours 30 minutes':", interval4.to_string())
    print("   Days:", interval4.days)
    print("   Hours:", interval4.hours)
    print("   Minutes:", interval4.minutes)

    var result5 = conn.query("SELECT INTERVAL '1 year 2 months 3 days'")
    var interval5 = result5.get_interval(0, 0)
    print("   '1 year 2 months 3 days':", interval5.to_string())
    print("   Years:", interval5.years)
    print("   Months:", interval5.months)
    print("   Days:", interval5.days)

    # Time format
    print("\n3️⃣  Time format intervals:")

    var result6 = conn.query("SELECT INTERVAL '01:30:45'")
    var interval6 = result6.get_interval(0, 0)
    print("   '01:30:45':", interval6.to_string())
    print("   Hours:", interval6.hours)
    print("   Minutes:", interval6.minutes)
    print("   Seconds:", interval6.seconds)

    # Interval arithmetic
    print("\n4️⃣  Interval arithmetic:")

    var result7 = conn.query("SELECT TIMESTAMP '2024-01-01 00:00:00' + INTERVAL '7 days'")
    var future_date = result7.get_timestamp(0, 0)
    print("   '2024-01-01' + '7 days':", future_date.to_string())

    var result8 = conn.query("SELECT TIMESTAMP '2024-01-01 00:00:00' - INTERVAL '1 month'")
    var past_date = result8.get_timestamp(0, 0)
    print("   '2024-01-01' - '1 month':", past_date.to_string())

    # Interval comparison
    print("\n5️⃣  Interval comparison:")

    var result9 = conn.query("SELECT INTERVAL '1 day' < INTERVAL '2 days'")
    var is_less = result9.get_bool(0, 0)
    print("   '1 day' < '2 days':", is_less)

    var result10 = conn.query("SELECT INTERVAL '24 hours' = INTERVAL '1 day'")
    var is_equal = result10.get_bool(0, 0)
    print("   '24 hours' = '1 day':", is_equal)

    conn.close()
    print("\n✅ Example 5 complete!\n")


fn example6_practical_use_cases() raises:
    """Example 6: Practical use cases."""
    print("=" * 70)
    print("Example 6: Practical Use Cases")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Use Case 1: Session tracking with UUIDs
    print("\n🔐 Use Case 1: Session Tracking")
    var _ = conn.query("DROP TABLE IF EXISTS sessions")
    var __ = conn.query("""
        CREATE TABLE sessions (
            session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id INT NOT NULL,
            ip_address INET NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP
        )
    """)

    var ___ = conn.query("""
        INSERT INTO sessions (user_id, ip_address, expires_at) VALUES
        (1, '192.168.1.100'::INET, CURRENT_TIMESTAMP + INTERVAL '24 hours'),
        (2, '10.0.0.50'::INET, CURRENT_TIMESTAMP + INTERVAL '24 hours'),
        (3, '172.16.0.25'::INET, CURRENT_TIMESTAMP + INTERVAL '24 hours')
    """)

    print("✅ Created sessions table with UUID, INET, and INTERVAL")

    var result1 = conn.query("SELECT session_id, user_id, ip_address FROM sessions ORDER BY user_id")
    print("\n📋 Active Sessions:")
    for row in range(result1.row_count()):
        var session_id = result1.get_uuid(row, 0)
        var user_id = result1.get_int32(row, 1)
        var ip_address = result1.get_inet(row, 2)
        print(f"\n  User {user_id}:")
        print(f"    Session: {session_id.to_string()}")
        print(f"    IP: {ip_address.to_string()}")

    # Use Case 2: Network access control
    print("\n🔒 Use Case 2: Network Access Control")
    var ____ = conn.query("DROP TABLE IF EXISTS allowed_networks")
    var _____ = conn.query("""
        CREATE TABLE allowed_networks (
            id SERIAL PRIMARY KEY,
            name TEXT,
            network CIDR
        )
    """)

    var ______ = conn.query("""
        INSERT INTO allowed_networks (name, network) VALUES
        ('Office Network', '192.168.1.0/24'::CIDR),
        ('VPN Network', '10.8.0.0/24'::CIDR),
        ('DMZ', '172.16.0.0/16'::CIDR)
    """)

    var result2 = conn.query("SELECT name, network FROM allowed_networks ORDER BY id")
    print("\n🌐 Allowed Networks:")
    for row in range(result2.row_count()):
        var name = result2.get_string(row, 0)
        var network = result2.get_cidr(row, 1)
        print(f"   {name}: {network.to_string()}")

    # Check if IP is in allowed network
    print("\n✅ Checking IP access:")
    var result3 = conn.query("""
        SELECT name
        FROM allowed_networks
        WHERE network >> '192.168.1.50'::INET
    """)
    if result3.row_count() > 0:
        var network_name = result3.get_string(0, 0)
        print(f"   IP 192.168.1.50 is allowed (in {network_name})")

    # Use Case 3: Subscription management
    print("\n💳 Use Case 3: Subscription Management")
    var _______ = conn.query("DROP TABLE IF EXISTS subscriptions")
    var ________ = conn.query("""
        CREATE TABLE subscriptions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_email TEXT,
            duration INTERVAL,
            started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    var _________ = conn.query("""
        INSERT INTO subscriptions (user_email, duration) VALUES
        ('user1@example.com', INTERVAL '1 month'),
        ('user2@example.com', INTERVAL '1 year'),
        ('user3@example.com', INTERVAL '6 months')
    """)

    var result4 = conn.query("""
        SELECT id, user_email, duration,
               started_at + duration AS expires_at
        FROM subscriptions
        ORDER BY user_email
    """)

    print("\n📅 Subscriptions:")
    for row in range(result4.row_count()):
        var sub_id = result4.get_uuid(row, 0)
        var email = result4.get_string(row, 1)
        var duration = result4.get_interval(row, 2)
        var expires = result4.get_timestamp(row, 3)

        print(f"\n  {email}:")
        print(f"    ID: {sub_id.to_string()}")
        print(f"    Duration: {duration.to_string()}")
        print(f"    Expires: {expires.to_string()}")

    # Cleanup
    var __________ = conn.query("DROP TABLE sessions")
    var ___________ = conn.query("DROP TABLE allowed_networks")
    var ____________ = conn.query("DROP TABLE subscriptions")

    conn.close()
    print("\n✅ Example 6 complete!\n")


fn main() raises:
    print("\n")
    print("🔥 PostgreSQL Additional Types Examples")
    print("UUID, INET/CIDR, and INTERVAL Support")
    print("\n")

    # Run examples
    example1_uuid_operations()
    example2_uuid_table_operations()
    example3_inet_operations()
    example4_cidr_operations()
    example5_interval_operations()
    example6_practical_use_cases()

    print("=" * 70)
    print("🎉 All examples completed successfully!")
    print("=" * 70)
    print("\n💡 Key Takeaways:")
    print("   - UUID: Perfect for distributed primary keys")
    print("   - INET: Store IP addresses with optional netmasks")
    print("   - CIDR: Represent network addresses")
    print("   - INTERVAL: Time duration calculations")
    print("\n💡 Use Cases:")
    print("   - Session tracking (UUID + INET)")
    print("   - Network access control (CIDR)")
    print("   - Subscription management (UUID + INTERVAL)")
    print("   - Distributed systems (UUID)")
    print("   - IP whitelisting/blacklisting (INET/CIDR)")
    print("\n💡 Benefits:")
    print("   - Type safety with validation")
    print("   - Database-level constraints")
    print("   - Efficient storage and indexing")
    print("   - Built-in operations (network contains, interval arithmetic)")
    print("\n")
