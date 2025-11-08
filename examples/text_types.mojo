"""
Example: PostgreSQL Text and Boolean Type Decoders

Demonstrates:
1. Using typed accessors (get_bool, get_text, get_varchar)
2. Working with user data (TEXT/VARCHAR)
3. Working with flags and status (BOOLEAN)
4. NULL handling with text/boolean types
5. Real-world use case: User management system
6. Real-world use case: Trading pair management

Prerequisites:
Run PostgreSQL locally:
  docker run -d -p 5432:5432 \
    -e POSTGRES_PASSWORD=test \
    -e POSTGRES_USER=test \
    -e POSTGRES_DB=test \
    postgres:16
"""

from src.protocol.connection import PostgresConnection


fn example_typed_accessors() raises:
    """Example 1: Basic typed accessors."""
    print("\n" + "=" * 70)
    print("Example 1: Typed Accessors (get_bool, get_text, get_varchar)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query with different text and boolean types
    var result = conn.query("""
        SELECT
            'Alice'::TEXT AS name,
            'alice@example.com'::VARCHAR(255) AS email,
            TRUE::BOOLEAN AS is_active
    """)

    print("\nUsing typed accessors:")
    print("")

    # TEXT - returns String
    var name = result.get_text(0, 0)
    print("  name (TEXT):     ", name, " - type: String")

    # VARCHAR - returns String
    var email = result.get_varchar(0, 1)
    print("  email (VARCHAR): ", email, " - type: String")

    # BOOLEAN - returns Bool
    var is_active = result.get_bool(0, 2)
    print("  is_active (BOOL):", String(is_active), " - type: Bool")

    print("\nBenefits:")
    print("  ✓ Type safety - compiler checks types")
    print("  ✓ Consistent API - same pattern as numeric types")
    print("  ✓ NULL-safe - explicit NULL checking required")

    conn.close()
    print("\n✅ Example 1 complete\n")


fn example_boolean_flags() raises:
    """Example 2: Working with BOOLEAN flags."""
    print("\n" + "=" * 70)
    print("Example 2: Boolean Flags and Status")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create sample user preferences
    var result = conn.query("""
        SELECT * FROM (VALUES
            ('alice'::TEXT, TRUE::BOOLEAN, FALSE::BOOLEAN, TRUE::BOOLEAN),
            ('bob'::TEXT, FALSE::BOOLEAN, TRUE::BOOLEAN, FALSE::BOOLEAN),
            ('charlie'::TEXT, TRUE::BOOLEAN, TRUE::BOOLEAN, TRUE::BOOLEAN)
        ) AS prefs(username, email_notif, dark_mode, two_factor)
    """)

    print("\nUser Preferences:")
    print("-" * 70)

    for row_idx in range(result.row_count()):
        var username = result.get_text(row_idx, 0)
        var email_notif = result.get_bool(row_idx, 1)
        var dark_mode = result.get_bool(row_idx, 2)
        var two_factor = result.get_bool(row_idx, 3)

        print("\n  User:", username)
        print("    Email notifications:", "ON" if email_notif else "OFF")
        print("    Dark mode:          ", "ON" if dark_mode else "OFF")
        print("    2FA:                ", "ON" if two_factor else "OFF")

    conn.close()
    print("\n✅ Example 2 complete\n")


fn example_text_data() raises:
    """Example 3: Working with TEXT and VARCHAR data."""
    print("\n" + "=" * 70)
    print("Example 3: TEXT and VARCHAR Data")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create sample user data
    var result = conn.query("""
        SELECT * FROM (VALUES
            ('alice'::VARCHAR(50), 'Alice Smith'::TEXT, 'alice@example.com'::VARCHAR(255)),
            ('bob'::VARCHAR(50), 'Bob Jones'::TEXT, 'bob@example.com'::VARCHAR(255))
        ) AS users(username, full_name, email)
    """)

    print("\nUser Data:")
    print("-" * 50)

    for row_idx in range(result.row_count()):
        var username = result.get_varchar(row_idx, 0)
        var full_name = result.get_text(row_idx, 1)
        var email = result.get_varchar(row_idx, 2)

        print("\n  Username:  ", username)
        print("  Full name: ", full_name)
        print("  Email:     ", email)

    conn.close()
    print("\n✅ Example 3 complete\n")


fn example_null_handling() raises:
    """Example 4: NULL handling with text and boolean types."""
    print("\n" + "=" * 70)
    print("Example 4: NULL Handling")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query with NULL values
    var result = conn.query("""
        SELECT * FROM (VALUES
            ('alice'::TEXT, 'alice@example.com'::VARCHAR(255), TRUE::BOOLEAN),
            ('bob'::TEXT, NULL::VARCHAR(255), NULL::BOOLEAN),
            (NULL::TEXT, 'charlie@example.com'::VARCHAR(255), FALSE::BOOLEAN)
        ) AS users(username, email, is_verified)
    """)

    print("\nUser Data (with NULLs):")
    print("-" * 50)

    for row_idx in range(result.row_count()):
        print("\nUser #", String(row_idx + 1), ":")

        # Check username (column 0)
        if result.is_null(row_idx, 0):
            print("  Username:    NULL (anonymous)")
        else:
            var username = result.get_text(row_idx, 0)
            print("  Username:    ", username)

        # Check email (column 1)
        if result.is_null(row_idx, 1):
            print("  Email:       NULL (no email provided)")
        else:
            var email = result.get_varchar(row_idx, 1)
            print("  Email:       ", email)

        # Check verification (column 2)
        if result.is_null(row_idx, 2):
            print("  Verified:    NULL (unknown)")
        else:
            var verified = result.get_bool(row_idx, 2)
            print("  Verified:    ", "YES" if verified else "NO")

    print("\nBest practice:")
    print("  ✓ Always use is_null() before get_bool() / get_text()")
    print("  ✓ Typed accessors raise error on NULL")

    conn.close()
    print("\n✅ Example 4 complete\n")


fn example_user_management_system() raises:
    """Example 5: Real-world user management system."""
    print("\n" + "=" * 70)
    print("Example 5: User Management System")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create users table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE users (
            id SERIAL PRIMARY KEY,
            username VARCHAR(50) UNIQUE NOT NULL,
            email VARCHAR(255) UNIQUE NOT NULL,
            full_name TEXT NOT NULL,
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            is_verified BOOLEAN NOT NULL DEFAULT FALSE,
            is_admin BOOLEAN NOT NULL DEFAULT FALSE
        )
    """)

    # Insert sample users
    var __ = conn.query("""
        INSERT INTO users (username, email, full_name, is_active, is_verified, is_admin) VALUES
            ('alice', 'alice@example.com', 'Alice Smith', TRUE, TRUE, FALSE),
            ('bob', 'bob@example.com', 'Bob Jones', TRUE, FALSE, FALSE),
            ('charlie', 'charlie@example.com', 'Charlie Brown', FALSE, TRUE, FALSE),
            ('admin', 'admin@example.com', 'System Admin', TRUE, TRUE, TRUE)
    """)

    # Query active users
    var result = conn.query("""
        SELECT username, email, full_name, is_verified, is_admin
        FROM users
        WHERE is_active = TRUE
        ORDER BY username
    """)

    print("\nActive Users:")
    print("-" * 70)

    var admin_count = 0
    var verified_count = 0

    for row_idx in range(result.row_count()):
        var username = result.get_varchar(row_idx, 0)
        var email = result.get_varchar(row_idx, 1)
        var full_name = result.get_text(row_idx, 2)
        var is_verified = result.get_bool(row_idx, 3)
        var is_admin = result.get_bool(row_idx, 4)

        print("\n  ", full_name, " (@", username, ")")
        print("    Email:    ", email)
        print("    Verified: ", "✓" if is_verified else "✗")
        print("    Admin:    ", "✓" if is_admin else "✗")

        if is_admin:
            admin_count += 1
        if is_verified:
            verified_count += 1

    print("\n" + "-" * 70)
    print("Summary:")
    print("  Total active users:  ", String(result.row_count()))
    print("  Verified users:      ", String(verified_count))
    print("  Admin users:         ", String(admin_count))

    conn.close()
    print("\n✅ Example 5 complete\n")


fn example_trading_pair_management() raises:
    """Example 6: Real-world cryptocurrency trading pair management."""
    print("\n" + "=" * 70)
    print("Example 6: Trading Pair Management")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create trading pairs table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE trading_pairs (
            id SERIAL PRIMARY KEY,
            symbol VARCHAR(20) UNIQUE NOT NULL,
            base_currency VARCHAR(10) NOT NULL,
            quote_currency VARCHAR(10) NOT NULL,
            description TEXT,
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            is_tradeable BOOLEAN NOT NULL DEFAULT TRUE,
            is_margin_enabled BOOLEAN NOT NULL DEFAULT FALSE
        )
    """)

    # Insert sample trading pairs
    var __ = conn.query("""
        INSERT INTO trading_pairs (symbol, base_currency, quote_currency, description, is_active, is_tradeable, is_margin_enabled) VALUES
            ('BTC/USD', 'BTC', 'USD', 'Bitcoin to US Dollar', TRUE, TRUE, TRUE),
            ('ETH/USD', 'ETH', 'USD', 'Ethereum to US Dollar', TRUE, TRUE, TRUE),
            ('SOL/USD', 'SOL', 'USD', 'Solana to US Dollar', TRUE, TRUE, FALSE),
            ('DOGE/USD', 'DOGE', 'USD', 'Dogecoin to US Dollar', FALSE, FALSE, FALSE)
    """)

    # Query active tradeable pairs
    var result = conn.query("""
        SELECT symbol, base_currency, quote_currency, description, is_margin_enabled
        FROM trading_pairs
        WHERE is_active = TRUE AND is_tradeable = TRUE
        ORDER BY symbol
    """)

    print("\nActive Trading Pairs:")
    print("-" * 70)

    var margin_count = 0

    for row_idx in range(result.row_count()):
        var symbol = result.get_varchar(row_idx, 0)
        var base = result.get_varchar(row_idx, 1)
        var quote = result.get_varchar(row_idx, 2)
        var desc = result.get_text(row_idx, 3)
        var margin = result.get_bool(row_idx, 4)

        print("\n  ", symbol)
        print("    Description: ", desc)
        print("    Base:        ", base)
        print("    Quote:       ", quote)
        print("    Margin:      ", "ENABLED" if margin else "DISABLED")

        if margin:
            margin_count += 1

    print("\n" + "-" * 70)
    print("Summary:")
    print("  Active pairs:        ", String(result.row_count()))
    print("  Margin-enabled:      ", String(margin_count))

    conn.close()
    print("\n✅ Example 6 complete\n")


fn example_boolean_conditions() raises:
    """Example 7: Using BOOLEAN in WHERE clauses."""
    print("\n" + "=" * 70)
    print("Example 7: Boolean Conditions in Queries")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create sample data
    var _ = conn.query("""
        CREATE TEMPORARY TABLE features (
            id SERIAL PRIMARY KEY,
            feature_name VARCHAR(100) NOT NULL,
            is_enabled BOOLEAN NOT NULL,
            is_beta BOOLEAN NOT NULL,
            is_paid BOOLEAN NOT NULL
        )
    """)

    var __ = conn.query("""
        INSERT INTO features (feature_name, is_enabled, is_beta, is_paid) VALUES
            ('Dark Mode', TRUE, FALSE, FALSE),
            ('Advanced Charts', TRUE, FALSE, TRUE),
            ('AI Trading Bot', FALSE, TRUE, TRUE),
            ('Social Trading', TRUE, TRUE, FALSE),
            ('API Access', TRUE, FALSE, TRUE)
    """)

    # Query: Enabled non-beta features
    var result = conn.query("""
        SELECT feature_name, is_paid
        FROM features
        WHERE is_enabled = TRUE AND is_beta = FALSE
        ORDER BY feature_name
    """)

    print("\nEnabled (Non-Beta) Features:")
    print("-" * 50)

    for row_idx in range(result.row_count()):
        var feature = result.get_varchar(row_idx, 0)
        var is_paid = result.get_bool(row_idx, 1)

        print("  ", feature, " (", ("PAID" if is_paid else "FREE"), ")")

    conn.close()
    print("\n✅ Example 7 complete\n")


fn main() raises:
    print("\n" + "=" * 70)
    print("mojo-postgres: Text and Boolean Type Decoders Examples")
    print("=" * 70)
    print("")
    print("These examples demonstrate type-safe text and boolean data access")
    print("for real-world applications.")
    print("=" * 70)

    # Run examples
    example_typed_accessors()
    example_boolean_flags()
    example_text_data()
    example_null_handling()
    example_user_management_system()
    example_trading_pair_management()
    example_boolean_conditions()

    # Summary
    print("\n" + "=" * 70)
    print("Summary: Text and Boolean Type Decoders")
    print("=" * 70)
    print("")
    print("Supported Types:")
    print("  ✅ BOOLEAN          - get_bool()    → Bool")
    print("  ✅ TEXT             - get_text()    → String")
    print("  ✅ VARCHAR(n)       - get_varchar() → String")
    print("")
    print("Features:")
    print("  ✅ Type-safe access")
    print("  ✅ Automatic decoding")
    print("  ✅ NULL handling")
    print("  ✅ Case-insensitive BOOLEAN (t/f, true/false, yes/no, etc.)")
    print("  ✅ Unicode support (TEXT/VARCHAR)")
    print("")
    print("Use Cases:")
    print("  • User management (usernames, emails, flags)")
    print("  • Trading pairs (symbols, descriptions, status)")
    print("  • Feature flags (enable/disable)")
    print("  • Configuration data")
    print("")
    print("Next Steps:")
    print("  • Task 1.5: TIMESTAMP, DATE, TIME types")
    print("  • Task 1.6: NUMERIC, JSONB types")
    print("=" * 70)
