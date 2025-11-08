"""
Examples of using PostgreSQL NUMERIC and JSONB types with mojo-postgres.

Demonstrates:
- NUMERIC for exact financial calculations
- JSONB for flexible metadata storage
- Real-world cryptocurrency trading scenarios
- Type-safe data access

Run:
  mojo examples/numeric_jsonb_types.mojo

Prerequisites:
  PostgreSQL running on localhost:5432 with test database
"""

from src.protocol.connection import PostgresConnection


# ============================================================================
# Example 1: Basic NUMERIC Usage
# ============================================================================

fn example_basic_numeric() raises:
    """Example: Basic NUMERIC usage for exact decimal values."""
    print("\n" + "=" * 70)
    print("Example 1: Basic NUMERIC Usage")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query NUMERIC values
    var result = conn.query("""
        SELECT * FROM (VALUES
            (123.45::NUMERIC, 'Small price'),
            (50123.45678901::NUMERIC, 'Crypto price (8 decimals)'),
            (0.00000001::NUMERIC, '1 satoshi (BTC smallest unit)')
        ) AS prices(amount, description)
    """)

    print("\nNUMERIC Values:")
    print("-" * 70)

    for row_idx in range(result.row_count()):
        var amount = result.get_numeric(row_idx, 0)
        var description = result.get_value(row_idx, 1)

        print("  " + description + ": " + amount.to_string())

    conn.close()

    print("\nKey Points:")
    print("  - NUMERIC preserves exact decimal precision")
    print("  - No floating point rounding errors")
    print("  - Critical for financial calculations")


# ============================================================================
# Example 2: NUMERIC Financial Calculations
# ============================================================================

fn example_numeric_financial() raises:
    """Example: NUMERIC for account balances and calculations."""
    print("\n" + "=" * 70)
    print("Example 2: NUMERIC for Financial Calculations")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create account balances table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE account_balances (
            account_id TEXT PRIMARY KEY,
            balance NUMERIC(20, 8) NOT NULL,
            reserved NUMERIC(20, 8) NOT NULL DEFAULT 0,
            currency TEXT NOT NULL
        )
    """)

    # Insert sample accounts
    var __ = conn.query("""
        INSERT INTO account_balances (account_id, balance, reserved, currency) VALUES
            ('alice_btc', 1.50000000, 0.10000000, 'BTC'),
            ('alice_usd', 75000.00, 5000.00, 'USD'),
            ('bob_btc', 0.00123456, 0.00000000, 'BTC'),
            ('bob_usd', 1250.50, 250.00, 'USD')
    """)

    # Query with calculations
    var result = conn.query("""
        SELECT
            account_id,
            balance,
            reserved,
            (balance - reserved) AS available,
            currency
        FROM account_balances
        ORDER BY account_id
    """)

    print("\nAccount Balances:")
    print("-" * 70)
    print(f"{'Account':<15} {'Balance':<15} {'Reserved':<15} {'Available':<15} {'Currency':<10}")
    print("-" * 70)

    for row_idx in range(result.row_count()):
        var account_id = result.get_value(row_idx, 0)
        var balance = result.get_numeric(row_idx, 1)
        var reserved = result.get_numeric(row_idx, 2)
        var available = result.get_numeric(row_idx, 3)
        var currency = result.get_value(row_idx, 4)

        print(
            account_id + " " * (15 - len(account_id)) +
            balance.to_string() + " " * (15 - len(balance.to_string())) +
            reserved.to_string() + " " * (15 - len(reserved.to_string())) +
            available.to_string() + " " * (15 - len(available.to_string())) +
            currency
        )

    conn.close()

    print("\nKey Points:")
    print("  - Balance calculations are exact (no rounding errors)")
    print("  - Supports high precision (8 decimals for crypto)")
    print("  - PostgreSQL enforces precision constraints")


# ============================================================================
# Example 3: Basic JSONB Usage
# ============================================================================

fn example_basic_jsonb() raises:
    """Example: Basic JSONB usage for flexible data."""
    print("\n" + "=" * 70)
    print("Example 3: Basic JSONB Usage")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query JSONB values
    var result = conn.query("""
        SELECT '{"name": "Alice", "age": 30, "active": true, "balance": 123.45}'::JSONB AS user_data
    """)

    var json = result.get_jsonb(0, 0)

    print("\nJSONB Field Access:")
    print("-" * 70)

    var name = json.get_string("name")
    print("  Name: " + name)

    var age = json.get_int("age")
    print("  Age: " + String(age))

    var active = json.get_bool("active")
    print("  Active: " + ("true" if active else "false"))

    var balance = json.get_float("balance")
    print("  Balance: " + String(balance))

    conn.close()

    print("\nKey Points:")
    print("  - JSONB supports mixed types (string, int, float, bool)")
    print("  - Schema-less storage (flexible structure)")
    print("  - Type-safe field access")


# ============================================================================
# Example 4: JSONB Nested Objects and Arrays
# ============================================================================

fn example_jsonb_nested() raises:
    """Example: JSONB with nested objects and arrays."""
    print("\n" + "=" * 70)
    print("Example 4: JSONB Nested Objects and Arrays")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Nested object
    var result1 = conn.query("""
        SELECT '{
            "user": {"name": "Bob", "id": 123},
            "preferences": {"theme": "dark", "language": "en"}
        }'::JSONB AS data
    """)

    var json1 = result1.get_jsonb(0, 0)
    var user = json1.get_object("user")
    var user_name = user.get_string("name")

    print("\nNested Object:")
    print("  User Name: " + user_name)

    # Array
    var result2 = conn.query("""
        SELECT '{"tags": ["crypto", "trading", "BTC", "ETH"]}'::JSONB AS data
    """)

    var json2 = result2.get_jsonb(0, 0)
    var tags = json2.get_array("tags")

    print("\nArray:")
    print("  Tags: ", end="")
    for i in range(tags.length()):
        print(tags.get_string(i), end="")
        if i < tags.length() - 1:
            print(", ", end="")
    print("")

    conn.close()

    print("\nKey Points:")
    print("  - Supports nested objects (JSON within JSON)")
    print("  - Supports arrays of values")
    print("  - Flexible schema for complex data")


# ============================================================================
# Example 5: Trade Metadata with JSONB
# ============================================================================

fn example_trade_metadata() raises:
    """Example: Using JSONB for trade metadata."""
    print("\n" + "=" * 70)
    print("Example 5: Trade Metadata with JSONB")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create trades table with JSONB metadata
    var _ = conn.query("""
        CREATE TEMPORARY TABLE trades (
            id SERIAL PRIMARY KEY,
            symbol TEXT NOT NULL,
            side TEXT NOT NULL,
            price NUMERIC(20, 8) NOT NULL,
            quantity NUMERIC(20, 8) NOT NULL,
            metadata JSONB NOT NULL
        )
    """)

    # Insert sample trades
    var __ = conn.query("""
        INSERT INTO trades (symbol, side, price, quantity, metadata) VALUES
            ('BTC/USD', 'buy', 50000.00, 0.1,
             '{"exchange": "Coinbase", "fee": 0.001, "maker": true, "order_id": "abc123"}'),
            ('ETH/USD', 'sell', 3000.00, 1.5,
             '{"exchange": "Binance", "fee": 0.0015, "maker": false, "order_id": "def456"}'),
            ('SOL/USD', 'buy', 150.00, 10.0,
             '{"exchange": "Kraken", "fee": 0.0012, "maker": true, "order_id": "ghi789"}')
    """)

    # Query trades
    var result = conn.query("""
        SELECT id, symbol, side, price, quantity, metadata
        FROM trades
        ORDER BY id
    """)

    print("\nTrades with Metadata:")
    print("-" * 70)

    for row_idx in range(result.row_count()):
        var symbol = result.get_value(row_idx, 1)
        var side = result.get_value(row_idx, 2)
        var price = result.get_numeric(row_idx, 3)
        var quantity = result.get_numeric(row_idx, 4)
        var metadata = result.get_jsonb(row_idx, 5)

        var exchange = metadata.get_string("exchange")
        var fee = metadata.get_float("fee")
        var maker = metadata.get_bool("maker")
        var order_id = metadata.get_string("order_id")

        print("\nTrade " + String(row_idx + 1) + ":")
        print("  Symbol: " + symbol)
        print("  Side: " + side)
        print("  Price: " + price.to_string())
        print("  Quantity: " + quantity.to_string())
        print("  Exchange: " + exchange)
        print("  Fee: " + String(fee))
        print("  Maker: " + ("true" if maker else "false"))
        print("  Order ID: " + order_id)

    conn.close()

    print("\n" + "-" * 70)
    print("Key Points:")
    print("  - JSONB perfect for flexible trade metadata")
    print("  - Combine NUMERIC (exact prices) with JSONB (flexible metadata)")
    print("  - Each trade can have different metadata fields")


# ============================================================================
# Example 6: Combining NUMERIC and JSONB
# ============================================================================

fn example_combined_numeric_jsonb() raises:
    """Example: Combining NUMERIC and JSONB for complete solution."""
    print("\n" + "=" * 70)
    print("Example 6: Combining NUMERIC and JSONB")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create cryptocurrency positions table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE crypto_positions (
            id SERIAL PRIMARY KEY,
            user_id TEXT NOT NULL,
            symbol TEXT NOT NULL,
            quantity NUMERIC(20, 8) NOT NULL,
            avg_entry_price NUMERIC(20, 8) NOT NULL,
            position_metadata JSONB NOT NULL
        )
    """)

    # Insert positions
    var __ = conn.query("""
        INSERT INTO crypto_positions (user_id, symbol, quantity, avg_entry_price, position_metadata) VALUES
            ('alice', 'BTC', 1.5, 45000.00,
             '{"exchanges": ["Coinbase", "Kraken"], "first_purchase": "2023-01-15", "notes": "Long-term hold"}'),
            ('alice', 'ETH', 10.0, 2800.00,
             '{"exchanges": ["Binance"], "first_purchase": "2023-03-20", "notes": "Staking on exchange"}')
    """)

    # Query with current price calculation
    var current_btc_price = 52000.00
    var current_eth_price = 3200.00

    var result = conn.query("""
        SELECT
            user_id,
            symbol,
            quantity,
            avg_entry_price,
            position_metadata,
            CASE
                WHEN symbol = 'BTC' THEN """ + String(current_btc_price) + """::NUMERIC(20, 8)
                WHEN symbol = 'ETH' THEN """ + String(current_eth_price) + """::NUMERIC(20, 8)
            END AS current_price,
            quantity * CASE
                WHEN symbol = 'BTC' THEN """ + String(current_btc_price) + """::NUMERIC(20, 8)
                WHEN symbol = 'ETH' THEN """ + String(current_eth_price) + """::NUMERIC(20, 8)
            END AS current_value,
            (quantity * CASE
                WHEN symbol = 'BTC' THEN """ + String(current_btc_price) + """::NUMERIC(20, 8)
                WHEN symbol = 'ETH' THEN """ + String(current_eth_price) + """::NUMERIC(20, 8)
            END) - (quantity * avg_entry_price) AS unrealized_pnl
        FROM crypto_positions
        WHERE user_id = 'alice'
        ORDER BY symbol
    """)

    print("\nCrypto Portfolio:")
    print("-" * 70)

    for row_idx in range(result.row_count()):
        var symbol = result.get_value(row_idx, 1)
        var quantity = result.get_numeric(row_idx, 2)
        var avg_entry = result.get_numeric(row_idx, 3)
        var metadata = result.get_jsonb(row_idx, 4)
        var current_price = result.get_numeric(row_idx, 5)
        var current_value = result.get_numeric(row_idx, 6)
        var pnl = result.get_numeric(row_idx, 7)

        var first_purchase = metadata.get_string("first_purchase")
        var notes = metadata.get_string("notes")

        print("\nPosition: " + symbol)
        print("  Quantity: " + quantity.to_string())
        print("  Avg Entry Price: $" + avg_entry.to_string())
        print("  Current Price: $" + current_price.to_string())
        print("  Current Value: $" + current_value.to_string())
        print("  Unrealized P&L: $" + pnl.to_string())
        print("  First Purchase: " + first_purchase)
        print("  Notes: " + notes)

    conn.close()

    print("\n" + "-" * 70)
    print("Key Points:")
    print("  - NUMERIC for exact price and quantity tracking")
    print("  - JSONB for flexible position metadata")
    print("  - No rounding errors in P&L calculations")
    print("  - Complete portfolio management solution")


# ============================================================================
# Example 7: NULL Handling
# ============================================================================

fn example_null_handling() raises:
    """Example: Handling NULL values in NUMERIC and JSONB."""
    print("\n" + "=" * 70)
    print("Example 7: NULL Handling")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("""
        SELECT * FROM (VALUES
            ('alice', 100.50::NUMERIC, '{"status": "active"}'::JSONB),
            ('bob', NULL::NUMERIC, '{"status": "inactive"}'::JSONB),
            ('charlie', 250.00::NUMERIC, NULL::JSONB)
        ) AS data(name, balance, metadata)
    """)

    print("\nHandling NULL Values:")
    print("-" * 70)

    for row_idx in range(result.row_count()):
        var name = result.get_value(row_idx, 0)
        print("\nUser: " + name)

        # Check for NULL balance
        if result.is_null(row_idx, 1):
            print("  Balance: NULL")
        else:
            var balance = result.get_numeric(row_idx, 1)
            print("  Balance: " + balance.to_string())

        # Check for NULL metadata
        if result.is_null(row_idx, 2):
            print("  Metadata: NULL")
        else:
            var metadata = result.get_jsonb(row_idx, 2)
            var status = metadata.get_string("status")
            print("  Metadata: status=" + status)

    conn.close()

    print("\n" + "-" * 70)
    print("Key Points:")
    print("  - Always use is_null() before accessing typed values")
    print("  - get_numeric() and get_jsonb() raise error on NULL")
    print("  - NULL handling prevents runtime errors")


# ============================================================================
# Main Runner
# ============================================================================

fn main() raises:
    print("\n" + "=" * 70)
    print("NUMERIC and JSONB Type Examples")
    print("=" * 70)
    print("")
    print("Demonstrating NUMERIC and JSONB usage with mojo-postgres")
    print("Prerequisites: PostgreSQL running on localhost:5432")
    print("")

    example_basic_numeric()
    example_numeric_financial()
    example_basic_jsonb()
    example_jsonb_nested()
    example_trade_metadata()
    example_combined_numeric_jsonb()
    example_null_handling()

    print("\n" + "=" * 70)
    print("✅ All examples complete!")
    print("=" * 70)
    print("")
    print("Summary:")
    print("  - NUMERIC provides exact decimal arithmetic")
    print("  - JSONB provides flexible schema-less storage")
    print("  - Perfect combination for financial applications")
    print("  - Type-safe access prevents errors")
    print("")
    print("Next Steps:")
    print("  - Explore extended query protocol (Task 2.x)")
    print("  - Add connection pooling (Task 2.x)")
    print("  - Implement COPY protocol for bulk operations")
    print("")
