"""
Example: PostgreSQL Numeric Type Decoders

Demonstrates:
1. Using typed accessors (get_int4, get_int8, get_float8)
2. Working with cryptocurrency prices (FLOAT8)
3. Working with timestamps (INT8)
4. Working with volumes and counts (INT4, INT8)
5. NULL handling with numeric types
6. Real-world use case: Cryptocurrency trading system

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
    print("Example 1: Typed Accessors (get_int4, get_int8, get_float8)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query with different numeric types
    var result = conn.query("""
        SELECT
            42::INT4 AS count,
            1000000000000::INT8 AS big_number,
            3.14159::FLOAT8 AS pi
    """)

    print("\nUsing typed accessors:")
    print("")

    # INT4 - returns Int32
    var count = result.get_int4(0, 0)
    print("  count (INT4):      ", String(count), " - type: Int32")

    # INT8 - returns Int64
    var big_number = result.get_int8(0, 1)
    print("  big_number (INT8): ", String(big_number), " - type: Int64")

    # FLOAT8 - returns Float64
    var pi = result.get_float8(0, 2)
    print("  pi (FLOAT8):       ", String(pi), " - type: Float64")

    print("\nBenefits:")
    print("  ✓ Type safety - compiler checks types")
    print("  ✓ No manual parsing - direct native types")
    print("  ✓ Better performance - optimized decoders")

    conn.close()
    print("\n✅ Example 1 complete\n")


fn example_crypto_prices() raises:
    """Example 2: Cryptocurrency prices (FLOAT8)."""
    print("\n" + "=" * 70)
    print("Example 2: Cryptocurrency Prices")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create sample crypto prices
    var result = conn.query("""
        SELECT * FROM (VALUES
            ('BTC'::TEXT, 50123.45::FLOAT8),
            ('ETH'::TEXT, 3012.67::FLOAT8),
            ('SOL'::TEXT, 142.89::FLOAT8)
        ) AS prices(symbol, price_usd)
    """)

    print("\nCryptocurrency Prices (USD):")
    print("-" * 40)

    for row_idx in range(result.row_count()):
        var symbol = result.get_value(row_idx, 0)
        var price = result.get_float8(row_idx, 1)  # FLOAT8 → Float64

        print("  ", symbol, ": $", String(price))

    print("\nPrice calculations:")
    var btc_price = result.get_float8(0, 1)
    var eth_price = result.get_float8(1, 1)
    var btc_eth_ratio = btc_price / eth_price
    print("  BTC/ETH ratio: ", String(btc_eth_ratio))

    conn.close()
    print("\n✅ Example 2 complete\n")


fn example_timestamps() raises:
    """Example 3: Working with timestamps (INT8 microseconds)."""
    print("\n" + "=" * 70)
    print("Example 3: Timestamp Handling (TimescaleDB style)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # TimescaleDB stores timestamps as INT8 microseconds since epoch
    var result = conn.query("""
        SELECT
            EXTRACT(EPOCH FROM '2024-01-01 00:00:00'::TIMESTAMP)::INT8 * 1000000 AS timestamp_us,
            'New Year 2024'::TEXT AS event
        UNION ALL
        SELECT
            EXTRACT(EPOCH FROM '2025-01-01 00:00:00'::TIMESTAMP)::INT8 * 1000000,
            'New Year 2025'::TEXT
    """)

    print("\nTimestamp Events:")
    print("-" * 40)

    for row_idx in range(result.row_count()):
        var timestamp_us = result.get_int8(row_idx, 0)  # INT8 → Int64
        var event = result.get_value(row_idx, 1)

        print("  ", event)
        print("    Timestamp (μs): ", String(timestamp_us))

    # Calculate time difference
    var ts1 = result.get_int8(0, 0)
    var ts2 = result.get_int8(1, 0)
    var diff_us = ts2 - ts1
    var diff_days = diff_us / (1000000 * 60 * 60 * 24)

    print("\nTime difference:")
    print("  ", String(diff_days), " days between events")

    conn.close()
    print("\n✅ Example 3 complete\n")


fn example_trade_volumes() raises:
    """Example 4: Trade volumes and counts."""
    print("\n" + "=" * 70)
    print("Example 4: Trade Volumes and Counts")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create temporary trades table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE crypto_trades (
            id SERIAL PRIMARY KEY,
            symbol TEXT NOT NULL,
            volume INT8 NOT NULL,
            trade_count INT4 NOT NULL
        )
    """)

    var __ = conn.query("""
        INSERT INTO crypto_trades (symbol, volume, trade_count) VALUES
            ('BTC', 1500000, 1250),
            ('ETH', 5000000, 3420),
            ('SOL', 250000, 890)
    """)

    # Query and analyze
    var result = conn.query("""
        SELECT symbol, volume, trade_count
        FROM crypto_trades
        ORDER BY volume DESC
    """)

    print("\nTrade Statistics:")
    print("-" * 40)

    var total_volume: Int64 = 0
    var total_trades: Int32 = 0

    for row_idx in range(result.row_count()):
        var symbol = result.get_value(row_idx, 0)
        var volume = result.get_int8(row_idx, 1)      # INT8 → Int64
        var trade_count = result.get_int4(row_idx, 2) # INT4 → Int32

        print("  ", symbol)
        print("    Volume:       ", String(volume))
        print("    Trade count:  ", String(trade_count))
        print("    Avg per trade:", String(Float64(volume) / Float64(trade_count)))

        total_volume += volume
        total_trades += trade_count

    print("\nTotals:")
    print("  Total volume: ", String(total_volume))
    print("  Total trades: ", String(total_trades))

    conn.close()
    print("\n✅ Example 4 complete\n")


fn example_null_handling() raises:
    """Example 5: NULL handling with numeric types."""
    print("\n" + "=" * 70)
    print("Example 5: NULL Handling")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query with NULL values
    var result = conn.query("""
        SELECT * FROM (VALUES
            ('BTC'::TEXT, 50123.45::FLOAT8, 1000000::INT8),
            ('ETH'::TEXT, NULL::FLOAT8, 5000000::INT8),
            ('SOL'::TEXT, 142.89::FLOAT8, NULL::INT8)
        ) AS trades(symbol, price, volume)
    """)

    print("\nTrade Data (with NULLs):")
    print("-" * 40)

    for row_idx in range(result.row_count()):
        var symbol = result.get_value(row_idx, 0)
        print("\n  ", symbol, ":")

        # Check price (column 1)
        if result.is_null(row_idx, 1):
            print("    Price:  NULL (no price available)")
        else:
            var price = result.get_float8(row_idx, 1)
            print("    Price:  $", String(price))

        # Check volume (column 2)
        if result.is_null(row_idx, 2):
            print("    Volume: NULL (no volume data)")
        else:
            var volume = result.get_int8(row_idx, 2)
            print("    Volume: ", String(volume))

    print("\nBest practice:")
    print("  ✓ Always use is_null() before get_intX() / get_floatX()")
    print("  ✓ Typed accessors raise error on NULL")

    # Demonstrate error on NULL access
    print("\nAttempting to access NULL value:")
    try:
        var _ = result.get_float8(1, 1)  # This is NULL
        print("  ❌ This shouldn't happen!")
    except e:
        print("  ✓ Caught error:", str(e))

    conn.close()
    print("\n✅ Example 5 complete\n")


fn example_real_world_trading_system() raises:
    """Example 6: Real-world cryptocurrency trading system."""
    print("\n" + "=" * 70)
    print("Example 6: Real-World Trading System")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create OHLCV (Open, High, Low, Close, Volume) table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE ohlcv_1min (
            timestamp_us INT8 PRIMARY KEY,
            symbol TEXT NOT NULL,
            open FLOAT8 NOT NULL,
            high FLOAT8 NOT NULL,
            low FLOAT8 NOT NULL,
            close FLOAT8 NOT NULL,
            volume INT8 NOT NULL
        )
    """)

    # Insert sample 1-minute candles for BTC
    var __ = conn.query("""
        INSERT INTO ohlcv_1min VALUES
            (1704067200000000, 'BTC', 50000.00, 50150.50, 49980.25, 50123.45, 1500000),
            (1704067260000000, 'BTC', 50123.45, 50200.00, 50100.00, 50145.23, 1200000),
            (1704067320000000, 'BTC', 50145.23, 50250.75, 50120.00, 50234.56, 1800000)
    """)

    # Query and analyze
    var result = conn.query("""
        SELECT
            timestamp_us,
            open,
            high,
            low,
            close,
            volume
        FROM ohlcv_1min
        WHERE symbol = 'BTC'
        ORDER BY timestamp_us
    """)

    print("\nBTC 1-Minute OHLCV Data:")
    print("-" * 70)

    var total_volume: Int64 = 0
    var price_change: Float64 = 0.0

    for row_idx in range(result.row_count()):
        var timestamp = result.get_int8(row_idx, 0)
        var open = result.get_float8(row_idx, 1)
        var high = result.get_float8(row_idx, 2)
        var low = result.get_float8(row_idx, 3)
        var close = result.get_float8(row_idx, 4)
        var volume = result.get_int8(row_idx, 5)

        print("\nCandle #", String(row_idx + 1))
        print("  Timestamp: ", String(timestamp))
        print("  Open:      $", String(open))
        print("  High:      $", String(high))
        print("  Low:       $", String(low))
        print("  Close:     $", String(close))
        print("  Volume:    ", String(volume))

        # Calculate price range
        var range_pct = ((high - low) / low) * 100.0
        print("  Range:     ", String(range_pct), "%")

        total_volume += volume

        # Track price change from first to last
        if row_idx == 0:
            price_change = close
        elif row_idx == result.row_count() - 1:
            price_change = close - price_change

    print("\n" + "-" * 70)
    print("Summary:")
    print("  Total volume:   ", String(total_volume))
    print("  Price change:   $", String(price_change))
    print("  Change %:       ", String((price_change / result.get_float8(0, 1)) * 100.0), "%")

    conn.close()
    print("\n✅ Example 6 complete\n")


fn example_performance_comparison() raises:
    """Example 7: Performance - typed vs string access."""
    print("\n" + "=" * 70)
    print("Example 7: Performance Comparison")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query with numeric data
    var result = conn.query("""
        SELECT generate_series(1, 100)::INT4 AS id, 50000.0::FLOAT8 AS price
    """)

    print("\nTwo ways to access numeric data:")
    print("")

    print("1. String access (manual parsing required):")
    print("   var id_str = result.get_value(0, 0)  // \"1\" (String)")
    print("   var id = int(id_str)                 // Manual conversion")
    print("   - Requires manual parsing")
    print("   - Error-prone")
    print("   - Slower")
    print("")

    print("2. Typed access (automatic decoding):")
    print("   var id = result.get_int4(0, 0)       // 1 (Int32)")
    print("   var price = result.get_float8(0, 1)  // 50000.0 (Float64)")
    print("   - Type safe")
    print("   - No manual parsing")
    print("   - Faster (optimized decoders)")
    print("")

    # Demonstrate both approaches
    print("Demonstration:")
    var id_typed = result.get_int4(0, 0)
    var price_typed = result.get_float8(0, 1)

    print("  Typed:  id=", String(id_typed), " (Int32), price=$", String(price_typed), " (Float64)")

    print("\nRecommendation:")
    print("  ✅ Use typed accessors for numeric types")
    print("  ✅ Better performance, type safety, and readability")

    conn.close()
    print("\n✅ Example 7 complete\n")


fn main() raises:
    print("\n" + "=" * 70)
    print("mojo-postgres: Numeric Type Decoders Examples")
    print("=" * 70)
    print("")
    print("These examples demonstrate type-safe numeric data access")
    print("for high-performance applications like cryptocurrency trading.")
    print("=" * 70)

    # Run examples
    example_typed_accessors()
    example_crypto_prices()
    example_timestamps()
    example_trade_volumes()
    example_null_handling()
    example_real_world_trading_system()
    example_performance_comparison()

    # Summary
    print("\n" + "=" * 70)
    print("Summary: Numeric Type Decoders")
    print("=" * 70)
    print("")
    print("Supported Types:")
    print("  ✅ INT2 (SMALLINT)      - get_int2()  → Int16")
    print("  ✅ INT4 (INTEGER)       - get_int4()  → Int32")
    print("  ✅ INT8 (BIGINT)        - get_int8()  → Int64")
    print("  ✅ FLOAT4 (REAL)        - get_float4() → Float32")
    print("  ✅ FLOAT8 (DOUBLE)      - get_float8() → Float64")
    print("")
    print("Features:")
    print("  ✅ Type-safe access")
    print("  ✅ Automatic decoding")
    print("  ✅ NULL handling")
    print("  ✅ Overflow detection")
    print("  ✅ High performance")
    print("")
    print("Use Cases:")
    print("  • Cryptocurrency trading (prices, volumes)")
    print("  • TimescaleDB time series (timestamps)")
    print("  • Financial calculations (precise decimals)")
    print("  • Real-time analytics")
    print("")
    print("Next Steps:")
    print("  • Task 1.4: TEXT, VARCHAR, BOOLEAN types")
    print("  • Task 1.5: TIMESTAMP, DATE, TIME types")
    print("  • Task 1.6: NUMERIC, JSONB types")
    print("=" * 70)
