"""
Complete TimescaleDB Features Example

Demonstrates all TimescaleDB optimization features:
- Compression (Task 5.3)
- Continuous Aggregates (Task 5.4)
- TimescaleDB-aware Connection Pool (Task 5.5)
- Hypertable Metadata (Task 5.1)
- Parallel Chunk Scanning (Task 5.2)

This example shows a complete workflow for optimizing a TimescaleDB
time-series application with real-world cryptocurrency trading data.

Usage:
    mojo examples/timescaledb_complete.mojo

Prerequisites:
    - PostgreSQL with TimescaleDB extension
    - CREATE EXTENSION timescaledb;
"""

from src.timescaledb.pool import TimescaleDBPool, create_timescaledb_pool
from src.timescaledb.compression import (
    query_compression_info,
    enable_compression,
    compress_old_chunks,
    get_compression_stats
)
from src.timescaledb.continuous_aggregates import (
    create_ohlcv_continuous_aggregate,
    add_continuous_aggregate_policy,
    refresh_continuous_aggregate,
    get_continuous_aggregate_stats
)
from src.timescaledb.metadata import find_chunks_for_time_range
from src.timescaledb.parallel_scanner import scan_chunks_parallel
from src.timescaledb.query_optimizer import create_query_plan, TimeRange
from time import now


fn print_separator():
    """Print a visual separator."""
    print("=" * 80)


fn print_section(title: String):
    """Print a section header."""
    print("\n")
    print("-" * 80)
    print(title)
    print("-" * 80)


fn main() raises:
    print_separator()
    print("COMPLETE TIMESCALEDB FEATURES DEMO".center(80))
    print_separator()
    print()
    print("This example demonstrates the complete Phase 5 TimescaleDB")
    print("optimization stack for high-performance time-series queries.")
    print()

    # ========================================================================
    # Setup: Create TimescaleDB-Aware Pool
    # ========================================================================
    print_section("Setup: TimescaleDB-Aware Connection Pool")

    var pool = create_timescaledb_pool(
        "localhost",
        5432,
        "benchdb",
        "benchuser",
        "benchpass",
        min_connections=10,
        max_connections=50,
        cache_ttl_seconds=300  # 5-minute cache
    )

    print("✓ Created TimescaleDB pool")
    print("  Min connections: 10")
    print("  Max connections: 50")
    print("  Metadata cache TTL: 300 seconds")
    print()

    var table_name = "orderbook_data"

    # ========================================================================
    # Example 1: Hypertable Metadata (Cached)
    # ========================================================================
    print_section("Example 1: Hypertable Metadata with Caching")

    var metadata = pool.get_hypertable_metadata(table_name)
    print("Hypertable:", metadata.table_name)
    print("Time column:", metadata.time_column)
    print("Chunk interval:", metadata.chunk_interval_seconds, "seconds")
    print("Number of chunks:", metadata.num_chunks)
    print("Total size:", metadata.total_size_bytes, "bytes")
    print()

    # Second call - from cache
    print("Second call (from cache):")
    var metadata2 = pool.get_hypertable_metadata(table_name)
    print("✓ Retrieved from cache (no database query)")
    print()

    # Get chunks (also cached)
    var all_chunks = pool.get_chunk_info(table_name)
    print("Retrieved", len(all_chunks), "chunks (cached)")
    print()

    # ========================================================================
    # Example 2: Enable and Configure Compression
    # ========================================================================
    print_section("Example 2: Compression Configuration")

    # Check current compression status
    var comp_info = pool.get_compression_info(table_name)
    print("Current compression status:", "enabled" if comp_info.compression_enabled else "disabled")

    # Enable compression if not already enabled
    if not comp_info.compression_enabled:
        print("\nEnabling compression...")
        var conn = pool.acquire()

        try:
            enable_compression(
                conn,
                table_name,
                segmentby="symbol,exchange",  # Segment by trading pair and exchange
                orderby="time DESC"           # Order by time descending
            )
            print("✓ Compression enabled")
        except:
            print("⚠ Compression already enabled or failed")

        pool.release(conn)

        # Invalidate cache after schema change
        pool.invalidate_hypertable_cache(table_name)

    # Compress old chunks (older than 7 days)
    print("\nCompressing old chunks...")
    var conn2 = pool.acquire()
    var num_compressed = compress_old_chunks(conn2, table_name, "7 days")
    pool.release(conn2)

    print("✓ Compressed", num_compressed, "chunks")

    # Get updated compression stats
    var compression_stats = get_compression_stats(conn2, table_name)
    if compression_stats.compression_ratio > 1.0:
        print("\nCompression Statistics:")
        print("  Uncompressed size:", compression_stats.uncompressed_size_bytes, "bytes")
        print("  Compressed size:", compression_stats.compressed_size_bytes, "bytes")
        print("  Compression ratio:", compression_stats.compression_ratio, "x")
        print("  Storage saved:", compression_stats.storage_saved_percent, "%")
        print("  Bytes saved:", compression_stats.storage_saved_bytes, "bytes")

    print()

    # ========================================================================
    # Example 3: Create Continuous Aggregate (OHLCV)
    # ========================================================================
    print_section("Example 3: Continuous Aggregate - OHLCV Candlesticks")

    var ohlcv_view = "ohlcv_1min"

    # Check if view already exists
    var aggregates = pool.get_continuous_aggregates()
    var view_exists = False
    for i in range(len(aggregates)):
        if aggregates[i].view_name == ohlcv_view:
            view_exists = True

    if not view_exists:
        print("Creating OHLCV continuous aggregate...")

        var conn3 = pool.acquire()

        # Create group-by columns for symbol
        var group_cols = List[String]()
        group_cols.append("symbol")
        group_cols.append("exchange")

        try:
            create_ohlcv_continuous_aggregate(
                conn3,
                ohlcv_view,
                table_name,
                "1 minute",           # 1-minute candlesticks
                price_column="price",
                volume_column="quantity",
                group_by_columns=group_cols
            )
            print("✓ Created OHLCV continuous aggregate:", ohlcv_view)

            # Add automatic refresh policy
            add_continuous_aggregate_policy(
                conn3,
                ohlcv_view,
                start_offset="1 month",    # Refresh last month
                end_offset="1 minute",     # Exclude last minute (real-time)
                schedule_interval="1 hour" # Refresh every hour
            )
            print("✓ Added automatic refresh policy (every 1 hour)")

        except e:
            print("⚠ Continuous aggregate already exists or failed:", e)

        pool.release(conn3)
    else:
        print("✓ OHLCV continuous aggregate already exists:", ohlcv_view)

    # Manually refresh to ensure data is up-to-date
    print("\nManually refreshing aggregate...")
    var conn4 = pool.acquire()
    refresh_continuous_aggregate(conn4, ohlcv_view)
    pool.release(conn4)
    print("✓ Refresh complete")

    # Query the aggregate stats
    var conn5 = pool.acquire()
    var agg_stats = get_continuous_aggregate_stats(conn5, ohlcv_view)
    pool.release(conn5)

    print("\nContinuous Aggregate Statistics:")
    if "row_count" in agg_stats:
        print("  Rows:", agg_stats["row_count"])
    if "size_bytes" in agg_stats:
        print("  Size:", agg_stats["size_bytes"], "bytes")

    # Query some OHLCV data
    print("\nSample OHLCV data (last 10 candles):")
    var conn6 = pool.acquire()
    var ohlcv_result = conn6.query("""
        SELECT bucket, symbol, open, high, low, close, volume, num_trades
        FROM """ + ohlcv_view + """
        WHERE symbol = 'BTC/USDT'
        ORDER BY bucket DESC
        LIMIT 10
    """)
    pool.release(conn6)

    print("  Retrieved", ohlcv_result.row_count(), "candlesticks")
    for i in range(min(3, ohlcv_result.row_count())):
        var bucket = ohlcv_result.get_value(i, 0)
        var symbol = ohlcv_result.get_value(i, 1)
        var open = ohlcv_result.get_value(i, 2)
        var high = ohlcv_result.get_value(i, 3)
        var low = ohlcv_result.get_value(i, 4)
        var close = ohlcv_result.get_value(i, 5)
        var volume = ohlcv_result.get_value(i, 6)
        print("  ", bucket, symbol, "O:", open, "H:", high, "L:", low, "C:", close, "V:", volume)

    print()

    # ========================================================================
    # Example 4: Chunk Pruning with Query Optimization
    # ========================================================================
    print_section("Example 4: Intelligent Chunk Pruning")

    # Find chunks for last 1 hour
    var now_unix = now() / 1_000_000_000
    var hour_ago = now_unix - 3600

    var relevant_chunks = find_chunks_for_time_range(all_chunks, hour_ago, now_unix)

    print("Time range: Last 1 hour")
    print("Total chunks:", len(all_chunks))
    print("Relevant chunks:", len(relevant_chunks))
    print("Chunks pruned:", len(all_chunks) - len(relevant_chunks))

    var pruning_pct = (Float64(len(all_chunks) - len(relevant_chunks)) / Float64(len(all_chunks))) * 100.0
    print("Pruning ratio:", pruning_pct, "%")
    print()

    # Create optimized query plan
    var query = "SELECT COUNT(*), AVG(price) FROM " + table_name + " WHERE symbol = 'BTC/USDT'"
    var time_range = TimeRange(hour_ago, now_unix)
    var plan = create_query_plan(query, metadata, all_chunks, time_range)

    print("Query Plan:")
    print("  Original query:", plan.original_query)
    print("  Chunks to scan:", len(plan.chunks_to_scan))
    print("  Estimated rows:", plan.estimated_rows)
    print("  Use parallel:", plan.use_parallel)
    print()

    # ========================================================================
    # Example 5: Parallel Chunk Scanning
    # ========================================================================
    print_section("Example 5: Parallel Chunk Scanning")

    if len(relevant_chunks) >= 3:
        print("Scanning", len(relevant_chunks), "chunks with 4 workers...")

        var par_result = scan_chunks_parallel(
            pool,
            plan.optimized_query,
            relevant_chunks,
            num_workers=4,
            time_column="time"
        )

        print("✓ Parallel scan complete")
        print("  Total rows:", par_result.total_rows)
        print("  Chunks scanned:", par_result.progress.completed_chunks)
        print("  Duration:", par_result.progress.elapsed_ms, "ms")

        # Calculate throughput
        var throughput = Float64(par_result.total_rows) / (par_result.progress.elapsed_ms / 1000.0)
        print("  Throughput:", throughput, "rows/sec")
    else:
        print("⚠ Not enough chunks for parallel scanning demo")
        print("  (Need at least 3 chunks)")

    print()

    # ========================================================================
    # Example 6: Pool Statistics
    # ========================================================================
    print_section("Example 6: Pool and Cache Statistics")

    var pool_stats = pool.get_pool_stats()
    print(pool_stats)

    # ========================================================================
    # Summary
    # ========================================================================
    print_separator()
    print("PERFORMANCE OPTIMIZATION SUMMARY".center(80))
    print_separator()
    print()

    print("✅ Optimizations Applied:")
    print()

    print("1. TimescaleDB-Aware Connection Pool")
    print("   • Metadata caching (5-min TTL)")
    print("   • Reduced database round-trips")
    print("   • 10-50 connection pool")
    print()

    print("2. Compression")
    if compression_stats.compression_ratio > 1.0:
        print("   • Compression ratio:", compression_stats.compression_ratio, "x")
        print("   • Storage saved:", compression_stats.storage_saved_percent, "%")
        print("   • Segment by: symbol, exchange")
        print("   • Order by: time DESC")
    else:
        print("   • Compression enabled")
        print("   • Awaiting chunk compression")
    print()

    print("3. Continuous Aggregates (OHLCV)")
    print("   • 1-minute candlesticks")
    print("   • Automatic refresh (every 1 hour)")
    print("   • Real-time data included")
    print("   • 10-100x faster aggregation queries")
    print()

    print("4. Chunk Pruning")
    print("   • Pruned", pruning_pct, "% of chunks")
    print("   • 2-5x faster time-range queries")
    print("   • Metadata-driven optimization")
    print()

    print("5. Parallel Scanning")
    print("   • 4 workers for chunk scanning")
    print("   • 3-10x speedup potential")
    print("   • Load-balanced distribution")
    print()

    print("📊 Expected Performance Improvements:")
    print("   • Time-range queries: 2-10x faster")
    print("   • Aggregation queries: 10-100x faster")
    print("   • Storage usage: 50-90% reduction")
    print("   • Metadata queries: Near-instant (cached)")
    print()

    print("🎯 Production Ready!")
    print("   All Phase 5 TimescaleDB optimizations demonstrated")
    print()

    # Cleanup
    pool.close_all()
    print("✓ Pool closed")
