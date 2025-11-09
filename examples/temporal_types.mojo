"""
Example: PostgreSQL Temporal Type Decoders

Demonstrates:
1. Using typed accessors (get_timestamp, get_timestamptz, get_date, get_time)
2. Working with TimescaleDB time series data
3. Working with cryptocurrency OHLCV (candle) data
4. Sensor data with timestamps
5. Date-based queries
6. NULL handling with temporal types

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
    print("Example 1: Typed Accessors (get_timestamp, get_timestamptz, get_date, get_time)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query with different temporal types
    var result = conn.query("""
        SELECT
            '2024-01-15 10:30:45'::TIMESTAMP AS ts,
            '2024-01-15 10:30:45+00'::TIMESTAMPTZ AS tstz,
            '2024-01-15'::DATE AS date_col,
            '10:30:45'::TIME AS time_col
    """)

    print("\nUsing typed accessors:")
    print("")

    # TIMESTAMP
    var ts = result.get_timestamp(0, 0)
    print("  timestamp:   ", String(ts.year), "-", String(ts.month), "-", String(ts.day), " ",
          String(ts.hour), ":", String(ts.minute), ":", String(ts.second))

    # TIMESTAMPTZ
    var tstz = result.get_timestamptz(0, 1)
    print("  timestamptz: ", String(tstz.year), "-", String(tstz.month), "-", String(tstz.day), " ",
          String(tstz.hour), ":", String(tstz.minute), ":", String(tstz.second),
          " (tz offset:", String(tstz.timezone_offset_seconds), "s)")

    # DATE
    var date_val = result.get_date(0, 2)
    print("  date:        ", String(date_val.year), "-", String(date_val.month), "-", String(date_val.day))

    # TIME
    var time_val = result.get_time(0, 3)
    print("  time:        ", String(time_val.hour), ":", String(time_val.minute), ":", String(time_val.second))

    print("\nBenefits:")
    print("  ✓ Type safety - compiler checks types")
    print("  ✓ Microsecond precision preserved")
    print("  ✓ Timezone information available")

    conn.close()
    print("\n✅ Example 1 complete\n")


fn example_timescaledb_sensor_data() raises:
    """Example 2: TimescaleDB-style sensor data."""
    print("\n" + "=" * 70)
    print("Example 2: TimescaleDB Sensor Data (Time Series)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create hypertable-style table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE sensor_readings (
            time TIMESTAMPTZ NOT NULL,
            sensor_id INT NOT NULL,
            temperature FLOAT8,
            humidity FLOAT8,
            pressure FLOAT8
        )
    """)

    # Insert sample sensor data (1-second intervals)
    var __ = conn.query("""
        INSERT INTO sensor_readings (time, sensor_id, temperature, humidity, pressure)
        VALUES
            ('2024-01-15 10:00:00+00', 1, 23.5, 55.2, 1013.25),
            ('2024-01-15 10:00:01+00', 1, 23.6, 55.1, 1013.26),
            ('2024-01-15 10:00:02+00', 1, 23.5, 55.3, 1013.24),
            ('2024-01-15 10:00:03+00', 1, 23.7, 55.0, 1013.27),
            ('2024-01-15 10:00:04+00', 1, 23.6, 55.2, 1013.25)
    """)

    # Query recent readings
    var result = conn.query("""
        SELECT time, sensor_id, temperature, humidity, pressure
        FROM sensor_readings
        ORDER BY time
    """)

    print("\nSensor Readings (TimescaleDB style):")
    print("-" * 70)

    for row_idx in range(result.row_count()):
        var time = result.get_timestamptz(row_idx, 0)
        var sensor_id = result.get_int4(row_idx, 1)
        var temp = result.get_float8(row_idx, 2)
        var humidity = result.get_float8(row_idx, 3)
        var pressure = result.get_float8(row_idx, 4)

        print("\nTime: ", String(time.year), "-", String(time.month), "-", String(time.day), " ",
              String(time.hour), ":", String(time.minute), ":", String(time.second))
        print("  Sensor ID:    ", String(sensor_id))
        print("  Temperature:  ", String(temp), "°C")
        print("  Humidity:     ", String(humidity), "%")
        print("  Pressure:     ", String(pressure), " hPa")

    conn.close()
    print("\n✅ Example 2 complete\n")


fn example_crypto_ohlcv_candles() raises:
    """Example 3: Cryptocurrency OHLCV (candle) data."""
    print("\n" + "=" * 70)
    print("Example 3: Cryptocurrency OHLCV Candles")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create OHLCV table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE ohlcv_1min (
            time TIMESTAMPTZ NOT NULL,
            symbol VARCHAR(20) NOT NULL,
            open FLOAT8 NOT NULL,
            high FLOAT8 NOT NULL,
            low FLOAT8 NOT NULL,
            close FLOAT8 NOT NULL,
            volume INT8 NOT NULL
        )
    """)

    # Insert sample 1-minute candles
    var __ = conn.query("""
        INSERT INTO ohlcv_1min (time, symbol, open, high, low, close, volume) VALUES
            ('2024-01-15 10:00:00+00', 'BTC/USD', 50000.00, 50150.50, 49980.25, 50123.45, 1500000),
            ('2024-01-15 10:01:00+00', 'BTC/USD', 50123.45, 50200.00, 50100.00, 50145.23, 1200000),
            ('2024-01-15 10:02:00+00', 'BTC/USD', 50145.23, 50250.75, 50120.00, 50234.56, 1800000),
            ('2024-01-15 10:03:00+00', 'BTC/USD', 50234.56, 50300.00, 50150.00, 50287.12, 1600000),
            ('2024-01-15 10:04:00+00', 'BTC/USD', 50287.12, 50350.00, 50200.00, 50312.34, 1400000)
    """)

    # Query and analyze candles
    var result = conn.query("""
        SELECT time, symbol, open, high, low, close, volume
        FROM ohlcv_1min
        ORDER BY time
    """)

    print("\nBTC/USD 1-Minute Candles:")
    print("-" * 70)

    var total_volume: Int64 = 0
    var first_price: Float64 = 0.0
    var last_price: Float64 = 0.0

    for row_idx in range(result.row_count()):
        var time = result.get_timestamptz(row_idx, 0)
        var symbol = result.get_varchar(row_idx, 1)
        var open = result.get_float8(row_idx, 2)
        var high = result.get_float8(row_idx, 3)
        var low = result.get_float8(row_idx, 4)
        var close = result.get_float8(row_idx, 5)
        var volume = result.get_int8(row_idx, 6)

        print("\n", String(time.hour), ":", String(time.minute).zfill(2), " ", symbol)
        print("  Open:   $", String(open))
        print("  High:   $", String(high))
        print("  Low:    $", String(low))
        print("  Close:  $", String(close))
        print("  Volume: ", String(volume))

        # Calculate range
        var range_pct = ((high - low) / low) * 100.0
        print("  Range:  ", String(range_pct), "%")

        total_volume += volume
        if row_idx == 0:
            first_price = open
        last_price = close

    print("\n" + "-" * 70)
    print("Summary:")
    print("  Total volume:   ", String(total_volume))
    print("  Price change:   $", String(last_price - first_price))
    print("  Change %:       ", String(((last_price - first_price) / first_price) * 100.0), "%")

    conn.close()
    print("\n✅ Example 3 complete\n")


fn example_date_based_queries() raises:
    """Example 4: Date-based queries and filtering."""
    print("\n" + "=" * 70)
    print("Example 4: Date-Based Queries")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create events table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE trading_events (
            id SERIAL PRIMARY KEY,
            event_date DATE NOT NULL,
            event_type VARCHAR(50) NOT NULL,
            description TEXT NOT NULL
        )
    """)

    # Insert sample events
    var __ = conn.query("""
        INSERT INTO trading_events (event_date, event_type, description) VALUES
            ('2024-01-15', 'HALVING', 'Bitcoin halving event'),
            ('2024-02-14', 'UPGRADE', 'Ethereum network upgrade'),
            ('2024-03-20', 'LISTING', 'New exchange listing'),
            ('2024-06-01', 'CONFERENCE', 'Crypto conference'),
            ('2024-12-31', 'YEAR_END', 'End of fiscal year')
    """)

    # Query events in Q1 2024
    var result = conn.query("""
        SELECT event_date, event_type, description
        FROM trading_events
        WHERE event_date >= '2024-01-01' AND event_date < '2024-04-01'
        ORDER BY event_date
    """)

    print("\nQ1 2024 Trading Events:")
    print("-" * 70)

    for row_idx in range(result.row_count()):
        var event_date = result.get_date(row_idx, 0)
        var event_type = result.get_varchar(row_idx, 1)
        var description = result.get_text(row_idx, 2)

        print("\n  Date: ", String(event_date.year), "-", 
              String(event_date.month).zfill(2), "-", 
              String(event_date.day).zfill(2))
        print("  Type: ", event_type)
        print("  Description: ", description)

    conn.close()
    print("\n✅ Example 4 complete\n")


fn example_time_of_day_analysis() raises:
    """Example 5: Time-of-day analysis for trading."""
    print("\n" + "=" * 70)
    print("Example 5: Time-of-Day Analysis")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create trading hours table
    var _ = conn.query("""
        CREATE TEMPORARY TABLE trading_hours (
            id SERIAL PRIMARY KEY,
            market VARCHAR(20) NOT NULL,
            open_time TIME NOT NULL,
            close_time TIME NOT NULL
        )
    """)

    # Insert sample trading hours
    var __ = conn.query("""
        INSERT INTO trading_hours (market, open_time, close_time) VALUES
            ('NYSE', '09:30:00', '16:00:00'),
            ('NASDAQ', '09:30:00', '16:00:00'),
            ('LSE', '08:00:00', '16:30:00'),
            ('TSE', '09:00:00', '15:00:00'),
            ('CRYPTO', '00:00:00', '23:59:59')
    """)

    # Query trading hours
    var result = conn.query("""
        SELECT market, open_time, close_time
        FROM trading_hours
        ORDER BY market
    """)

    print("\nGlobal Trading Hours:")
    print("-" * 70)

    for row_idx in range(result.row_count()):
        var market = result.get_varchar(row_idx, 0)
        var open_time = result.get_time(row_idx, 1)
        var close_time = result.get_time(row_idx, 2)

        print("\n  ", market)
        print("    Opens:  ", String(open_time.hour).zfill(2), ":", 
              String(open_time.minute).zfill(2), ":", 
              String(open_time.second).zfill(2))
        print("    Closes: ", String(close_time.hour).zfill(2), ":", 
              String(close_time.minute).zfill(2), ":", 
              String(close_time.second).zfill(2))

        # Calculate trading hours
        var hours = close_time.hour - open_time.hour
        var minutes = close_time.minute - open_time.minute
        if minutes < 0:
            hours -= 1
            minutes += 60
        print("    Duration: ", String(hours), "h ", String(minutes), "m")

    conn.close()
    print("\n✅ Example 5 complete\n")


fn example_timezone_handling() raises:
    """Example 6: Timezone handling with TIMESTAMPTZ."""
    print("\n" + "=" * 70)
    print("Example 6: Timezone Handling")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query same time in different timezones
    var result = conn.query("""
        SELECT * FROM (VALUES
            ('2024-01-15 12:00:00+00'::TIMESTAMPTZ, 'UTC'),
            ('2024-01-15 07:00:00-05'::TIMESTAMPTZ, 'EST'),
            ('2024-01-15 17:30:00+05:30'::TIMESTAMPTZ, 'IST'),
            ('2024-01-15 21:00:00+09'::TIMESTAMPTZ, 'JST')
        ) AS times(time, timezone_name)
    """)

    print("\nSame Moment in Different Timezones:")
    print("-" * 70)

    for row_idx in range(result.row_count()):
        var time = result.get_timestamptz(row_idx, 0)
        var tz_name = result.get_text(row_idx, 1)

        var tz_hours = time.timezone_offset_seconds / 3600
        var tz_sign = "+" if tz_hours >= 0 else "-"

        print("\n  ", tz_name)
        print("    Time: ", String(time.year), "-", String(time.month), "-", String(time.day), " ",
              String(time.hour), ":", String(time.minute), ":", String(time.second))
        print("    Timezone offset: ", tz_sign, String(abs(tz_hours)), " hours")

    conn.close()
    print("\n✅ Example 6 complete\n")


fn example_null_handling() raises:
    """Example 7: NULL handling with temporal types."""
    print("\n" + "=" * 70)
    print("Example 7: NULL Handling")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query with NULL values
    var result = conn.query("""
        SELECT * FROM (VALUES
            ('Event 1', '2024-01-15 10:00:00+00'::TIMESTAMPTZ, '2024-01-15'::DATE),
            ('Event 2', NULL::TIMESTAMPTZ, '2024-01-16'::DATE),
            ('Event 3', '2024-01-17 10:00:00+00'::TIMESTAMPTZ, NULL::DATE)
        ) AS events(name, timestamp, date)
    """)

    print("\nEvents (with NULLs):")
    print("-" * 70)

    for row_idx in range(result.row_count()):
        var name = result.get_text(row_idx, 0)
        print("\n  ", name, ":")

        # Check timestamp
        if result.is_null(row_idx, 1):
            print("    Timestamp: NULL (not recorded)")
        else:
            var timestamp = result.get_timestamptz(row_idx, 1)
            print("    Timestamp: ", String(timestamp.year), "-", String(timestamp.month), "-", String(timestamp.day))

        # Check date
        if result.is_null(row_idx, 2):
            print("    Date:      NULL (pending)")
        else:
            var date = result.get_date(row_idx, 2)
            print("    Date:      ", String(date.year), "-", String(date.month), "-", String(date.day))

    print("\nBest practice:")
    print("  ✓ Always use is_null() before get_timestamp*()")
    print("  ✓ Typed accessors raise error on NULL")

    conn.close()
    print("\n✅ Example 7 complete\n")


fn main() raises:
    print("\n" + "=" * 70)
    print("mojo-postgres: Temporal Type Decoders Examples")
    print("=" * 70)
    print("")
    print("These examples demonstrate type-safe temporal data access")
    print("for TimescaleDB and high-frequency cryptocurrency trading.")
    print("=" * 70)

    # Run examples
    example_typed_accessors()
    example_timescaledb_sensor_data()
    example_crypto_ohlcv_candles()
    example_date_based_queries()
    example_time_of_day_analysis()
    example_timezone_handling()
    example_null_handling()

    # Summary
    print("\n" + "=" * 70)
    print("Summary: Temporal Type Decoders")
    print("=" * 70)
    print("")
    print("Supported Types:")
    print("  ✅ TIMESTAMP        - get_timestamp()    → Timestamp")
    print("  ✅ TIMESTAMPTZ      - get_timestamptz()  → TimestampTZ")
    print("  ✅ DATE             - get_date()         → Date")
    print("  ✅ TIME             - get_time()         → Time")
    print("")
    print("Features:")
    print("  ✅ Microsecond precision")
    print("  ✅ Timezone support (offset in seconds)")
    print("  ✅ Type-safe access")
    print("  ✅ NULL handling")
    print("  ✅ TimescaleDB ready")
    print("")
    print("Use Cases:")
    print("  • TimescaleDB time series (sensor data, metrics)")
    print("  • Cryptocurrency OHLCV candles")
    print("  • Trading hours and schedules")
    print("  • Date-based event tracking")
    print("  • Global timezone handling")
    print("")
    print("Next Steps:")
    print("  • Task 1.6: NUMERIC, JSONB types")
    print("  • Task 1.7: CI/CD setup")
    print("  • Phase 1 v0.1.0 release")
    print("=" * 70)
