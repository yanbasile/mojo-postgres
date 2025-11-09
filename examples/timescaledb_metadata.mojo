"""
TimescaleDB Metadata Example

Demonstrates how to query and use TimescaleDB hypertable metadata
for query optimization.

Features:
- Query hypertable metadata
- List chunks with details
- Find chunks for time ranges
- Estimate query costs
- Cache metadata for performance

Usage:
    mojo examples/timescaledb_metadata.mojo

Prerequisites:
    - PostgreSQL with TimescaleDB extension
    - CREATE EXTENSION timescaledb;
    - Hypertable already created
"""

from src.protocol.connection import PostgresConnection
from src.timescaledb.metadata import (
    query_hypertable_metadata,
    query_chunk_info,
    find_chunks_for_time_range,
    estimate_chunk_scan_cost,
    MetadataCache
)
from src.timescaledb.query_optimizer import (
    create_query_plan,
    TimeRange,
    calculate_pruning_stats
)
from time import now


fn print_separator():
    """Print a visual separator."""
    print("=" * 80)


fn main() raises:
    print_separator()
    print("TIMESCALEDB METADATA EXAMPLE".center(80))
    print_separator()
    print()

    # Connect to database
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("benchdb", "benchuser", "benchpass")
    print("✓ Connected to PostgreSQL with TimescaleDB")
    print()

    # ========================================================================
    # Example 1: Query Hypertable Metadata
    # ========================================================================
    print("Example 1: Query Hypertable Metadata")
    print("-" * 80)

    var table_name = "orderbook_data"
    var metadata = query_hypertable_metadata(conn, table_name)

    print("Hypertable:", metadata.table_name)
    print("Schema:", metadata.schema_name)
    print("Time column:", metadata.time_column)
    print("Chunk interval:", metadata.chunk_interval_seconds, "seconds")
    print("Number of chunks:", metadata.num_chunks)
    print("Total size:", metadata.total_size_bytes, "bytes")
    print("Compression enabled:", metadata.compression_enabled)
    print()

    # ========================================================================
    # Example 2: List All Chunks
    # ========================================================================
    print("Example 2: List All Chunks")
    print("-" * 80)

    var chunks = query_chunk_info(conn, table_name)
    print("Total chunks:", len(chunks))
    print()

    # Show first 5 chunks
    var num_to_show = 5 if len(chunks) > 5 else len(chunks)
    print("First", num_to_show, "chunks:")
    for i in range(num_to_show):
        var chunk = chunks[i]
        print("  ", i+1, ".", chunk.chunk_name)
        print("      Range:", chunk.range_start_unix, "-", chunk.range_end_unix)
        print("      Rows:", chunk.row_count)
        print("      Size:", chunk.total_bytes, "bytes")
        print("      Compressed:", chunk.is_compressed)

        # Estimate scan cost
        var cost = estimate_chunk_scan_cost(chunk)
        print("      Scan cost:", cost)
        print()

    # ========================================================================
    # Example 3: Find Chunks for Time Range
    # ========================================================================
    print("Example 3: Find Chunks for Time Range")
    print("-" * 80)

    # Example: Find chunks for last 1 hour
    var now_unix = now() / 1_000_000_000  # Current time in seconds
    var one_hour_ago = now_unix - 3600

    var relevant_chunks = find_chunks_for_time_range(chunks, one_hour_ago, now_unix)
    print("Time range: Last 1 hour")
    print("Chunks in range:", len(relevant_chunks))

    # Calculate pruning statistics
    var pruning_stats = calculate_pruning_stats(chunks, relevant_chunks)
    print("Pruning statistics:", pruning_stats.__str__())
    print()

    # ========================================================================
    # Example 4: Create Query Plan with Chunk Pruning
    # ========================================================================
    print("Example 4: Create Query Plan with Chunk Pruning")
    print("-" * 80)

    var query = "SELECT COUNT(*), AVG(price) FROM " + table_name + " WHERE symbol = 'BTC/USDT'"
    var time_range = TimeRange(one_hour_ago, now_unix)

    var plan = create_query_plan(query, metadata, chunks, time_range)

    print("Original query:", plan.original_query)
    print()
    print("Optimized query:", plan.optimized_query)
    print()
    print("Query plan:", plan.__str__())
    print("Chunks to scan:", len(plan.chunks_to_scan), "/", len(chunks))
    print("Estimated rows:", plan.estimated_rows)
    print("Estimated cost:", plan.estimated_cost)
    print("Use parallel:", plan.use_parallel)
    print()

    # ========================================================================
    # Example 5: Metadata Caching
    # ========================================================================
    print("Example 5: Metadata Caching")
    print("-" * 80)

    var cache = MetadataCache(ttl_seconds=300)  # 5-minute TTL

    # First access - cache miss
    print("First access (cache miss):")
    var cached_metadata = cache.get_metadata(table_name)
    if cached_metadata.table_name == "":
        print("  ✗ Not in cache, querying database...")
        cached_metadata = query_hypertable_metadata(conn, table_name)
        cache.set_metadata(table_name, cached_metadata)
        print("  ✓ Cached metadata for", table_name)

    # Second access - cache hit
    print()
    print("Second access (cache hit):")
    cached_metadata = cache.get_metadata(table_name)
    if cached_metadata.table_name != "":
        print("  ✓ Retrieved from cache!")
        print("  Metadata age:", (now() / 1_000_000_000) - cached_metadata.last_updated, "seconds")

    # Cache chunks too
    print()
    print("Caching chunk information:")
    cache.set_chunks(table_name, chunks)
    var cached_chunks = cache.get_chunks(table_name)
    print("  ✓ Cached", len(cached_chunks), "chunks")

    # Invalidate cache
    print()
    print("Invalidating cache:")
    cache.invalidate(table_name)
    cached_metadata = cache.get_metadata(table_name)
    if cached_metadata.table_name == "":
        print("  ✓ Cache invalidated successfully")

    print()

    # ========================================================================
    # Example 6: Cost-Based Query Planning
    # ========================================================================
    print("Example 6: Cost-Based Query Planning")
    print("-" * 80)

    # Compare different time ranges
    var ranges = List[TimeRange]()
    ranges.append(TimeRange(now_unix - 3600, now_unix))       # Last 1 hour
    ranges.append(TimeRange(now_unix - 86400, now_unix))      # Last 24 hours
    ranges.append(TimeRange(now_unix - 604800, now_unix))     # Last 7 days

    var range_names = ["Last 1 hour", "Last 24 hours", "Last 7 days"]

    for i in range(len(ranges)):
        var range_name = range_names[i]
        var time_range2 = ranges[i]

        var relevant = find_chunks_for_time_range(chunks, time_range2.start_unix, time_range2.end_unix)
        var plan2 = create_query_plan(query, metadata, chunks, time_range2)

        print(range_name + ":")
        print("  Chunks:", len(relevant), "/", len(chunks))
        print("  Est. rows:", plan2.estimated_rows)
        print("  Est. cost:", plan2.estimated_cost)
        print("  Parallel:", plan2.use_parallel)
        print()

    # ========================================================================
    # Summary
    # ========================================================================
    print_separator()
    print("SUMMARY")
    print_separator()
    print()
    print("Key Takeaways:")
    print("  1. Hypertable metadata provides valuable optimization information")
    print("  2. Chunk pruning dramatically reduces data scanned (up to 90%+)")
    print("  3. Metadata caching reduces database round-trips")
    print("  4. Cost estimation helps choose parallel vs sequential execution")
    print("  5. Query planning can optimize chunk selection automatically")
    print()
    print("Performance Impact:")
    print("  ✓ 2-5x faster queries with chunk pruning")
    print("  ✓ 3-10x faster large scans with parallelization")
    print("  ✓ Reduced I/O and memory usage")
    print()

    conn.close()
    print("✓ Example complete!")
