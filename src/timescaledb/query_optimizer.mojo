"""
TimescaleDB Query Optimizer

Optimizes queries for TimescaleDB hypertables using:
- Chunk pruning based on time ranges
- Query rewriting for chunk-specific queries
- Cost estimation for query planning

Features:
- Automatic time range extraction from WHERE clauses
- Chunk constraint generation
- Query plan optimization
- Cost-based chunk selection

Usage:
    from src.timescaledb.query_optimizer import optimize_query_for_chunks

    var optimized = optimize_query_for_chunks(query, metadata, chunks)
    var result = conn.query(optimized)
"""

from src.timescaledb.metadata import HypertableMetadata, ChunkInfo, find_chunks_for_time_range
from collections import List


# ============================================================================
# Time Range Extraction
# ============================================================================

@value
struct TimeRange:
    """Represents a time range for queries."""
    var start_unix: Int64  # Unix timestamp (seconds)
    var end_unix: Int64    # Unix timestamp (seconds)
    var is_bounded: Bool    # False if range is unbounded (e.g., all data)

    fn __init__(inout self):
        """Initialize unbounded time range."""
        self.start_unix = 0
        self.end_unix = 9999999999  # Far future
        self.is_bounded = False

    fn __init__(inout self, start: Int64, end: Int64):
        """Initialize bounded time range."""
        self.start_unix = start
        self.end_unix = end
        self.is_bounded = True

    fn __str__(self) -> String:
        """String representation."""
        if not self.is_bounded:
            return "TimeRange(unbounded)"
        return "TimeRange(" + String(self.start_unix) + "-" + String(self.end_unix) + ")"

    fn duration_seconds(self) -> Int64:
        """Get duration of time range in seconds."""
        return self.end_unix - self.start_unix


fn extract_time_range_from_query(query: String, time_column: String = "time") -> TimeRange:
    """
    Extract time range from SQL query WHERE clause.

    Looks for patterns like:
    - WHERE time > '2024-01-01'
    - WHERE time BETWEEN '2024-01-01' AND '2024-01-02'
    - WHERE time > NOW() - INTERVAL '1 hour'

    Args:
        query: SQL query string
        time_column: Name of time column (default: "time")

    Returns:
        TimeRange extracted from query, or unbounded range if not found

    Note:
        This is a simple pattern-based extraction. For complex queries,
        it may return unbounded range and rely on PostgreSQL's planning.
    """
    var range = TimeRange()

    # Convert to lowercase for easier parsing
    var lower_query = query.lower()

    # Check for common time range patterns
    # Pattern 1: "WHERE time > NOW() - INTERVAL '1 hour'"
    if "now() - interval" in lower_query:
        # Simple heuristic: assume last 1 hour if we see this pattern
        # In production, we'd parse the actual interval
        var now_unix = 1704067200  # Example: 2024-01-01 00:00:00 UTC
        range.start_unix = now_unix - 3600  # 1 hour ago
        range.end_unix = now_unix
        range.is_bounded = True
        return range

    # Pattern 2: "WHERE time > '2024-01-01'"
    # For now, return unbounded - full parser would extract actual timestamps
    # This is a placeholder for demonstration

    return range  # Return unbounded if we can't extract


# ============================================================================
# Query Optimization
# ============================================================================

fn generate_chunk_constraint(chunk: ChunkInfo, time_column: String = "time") -> String:
    """
    Generate SQL constraint for a specific chunk's time range.

    Args:
        chunk: Chunk information
        time_column: Name of time column

    Returns:
        SQL constraint string

    Example:
        "time >= '2024-01-01 00:00:00' AND time < '2024-01-01 01:00:00'"
    """
    # Convert Unix timestamps to SQL timestamps
    # In production, we'd use proper timestamp formatting
    var start_ts = "to_timestamp(" + String(chunk.range_start_unix) + ")"
    var end_ts = "to_timestamp(" + String(chunk.range_end_unix) + ")"

    return time_column + " >= " + start_ts + " AND " + time_column + " < " + end_ts


fn optimize_query_for_chunks(
    query: String,
    metadata: HypertableMetadata,
    relevant_chunks: List[ChunkInfo]
) -> String:
    """
    Optimize query by adding chunk-specific constraints.

    This helps PostgreSQL's query planner by explicitly specifying
    which chunks to scan, enabling better index usage and parallel plans.

    Args:
        query: Original SQL query
        metadata: Hypertable metadata
        relevant_chunks: List of chunks to scan

    Returns:
        Optimized query with chunk constraints

    Example:
        var optimized = optimize_query_for_chunks(
            "SELECT * FROM orderbook_data WHERE symbol = 'BTC/USDT'",
            metadata,
            relevant_chunks
        )
    """
    # If only one chunk, add direct constraint
    if len(relevant_chunks) == 1:
        var chunk = relevant_chunks[0]
        var constraint = generate_chunk_constraint(chunk, metadata.time_column)

        # Simple query rewriting - add chunk constraint to WHERE clause
        if "WHERE" in query or "where" in query:
            return query.replace("WHERE", "WHERE " + constraint + " AND", 1)
        else:
            # Add WHERE clause
            var from_pos = query.find("FROM")
            if from_pos >= 0:
                var select_part = query[:from_pos + 4]  # "SELECT ... FROM"
                var rest = query[from_pos + 4:]
                return select_part + rest + " WHERE " + constraint
            return query

    # Multiple chunks - let PostgreSQL handle the planning
    # In production, we might generate UNION ALL queries for each chunk
    return query


fn estimate_query_cost(
    chunks: List[ChunkInfo],
    time_range: TimeRange
) -> Float64:
    """
    Estimate total cost of scanning chunks for a query.

    Args:
        chunks: Chunks to scan
        time_range: Time range of query

    Returns:
        Estimated cost (higher = more expensive)
    """
    var total_cost: Float64 = 0.0

    for i in range(len(chunks)):
        var chunk = chunks[i]
        if chunk.overlaps_range(time_range.start_unix, time_range.end_unix):
            # Base cost: number of rows
            var chunk_cost = Float64(chunk.row_count)

            # Compressed chunks are more expensive
            if chunk.is_compressed:
                chunk_cost *= 1.5

            total_cost += chunk_cost

    return total_cost


# ============================================================================
# Query Analysis
# ============================================================================

struct QueryPlan:
    """Represents an optimized query execution plan."""
    var original_query: String
    var optimized_query: String
    var chunks_to_scan: List[ChunkInfo]
    var estimated_cost: Float64
    var estimated_rows: Int
    var use_parallel: Bool

    fn __init__(inout self):
        """Initialize empty query plan."""
        self.original_query = ""
        self.optimized_query = ""
        self.chunks_to_scan = List[ChunkInfo]()
        self.estimated_cost = 0.0
        self.estimated_rows = 0
        self.use_parallel = False

    fn __str__(self) -> String:
        """String representation."""
        return (
            "QueryPlan(chunks=" + String(len(self.chunks_to_scan)) +
            ", cost=" + String(self.estimated_cost) +
            ", rows=" + String(self.estimated_rows) +
            ", parallel=" + ("yes" if self.use_parallel else "no") + ")"
        )


fn create_query_plan(
    query: String,
    metadata: HypertableMetadata,
    all_chunks: List[ChunkInfo],
    time_range: TimeRange
) raises -> QueryPlan:
    """
    Create optimized query plan for a TimescaleDB query.

    Args:
        query: Original SQL query
        metadata: Hypertable metadata
        all_chunks: All available chunks
        time_range: Time range for the query

    Returns:
        QueryPlan with optimization strategy

    Example:
        var plan = create_query_plan(query, metadata, chunks, time_range)
        print("Will scan", len(plan.chunks_to_scan), "chunks")
        var result = conn.query(plan.optimized_query)
    """
    var plan = QueryPlan()
    plan.original_query = query

    # Find relevant chunks for time range
    if time_range.is_bounded:
        plan.chunks_to_scan = find_chunks_for_time_range(
            all_chunks,
            time_range.start_unix,
            time_range.end_unix
        )
    else:
        # Scan all chunks if no time range specified
        plan.chunks_to_scan = all_chunks

    # Optimize query with chunk constraints
    plan.optimized_query = optimize_query_for_chunks(
        query,
        metadata,
        plan.chunks_to_scan
    )

    # Estimate cost and rows
    plan.estimated_cost = estimate_query_cost(plan.chunks_to_scan, time_range)
    plan.estimated_rows = 0
    for i in range(len(plan.chunks_to_scan)):
        plan.estimated_rows += plan.chunks_to_scan[i].row_count

    # Decide if parallel scan is worthwhile
    # Use parallel if scanning 4+ chunks or 100k+ rows
    plan.use_parallel = (
        len(plan.chunks_to_scan) >= 4 or
        plan.estimated_rows >= 100000
    )

    return plan


# ============================================================================
# Chunk Pruning Statistics
# ============================================================================

struct PruningStats:
    """Statistics about chunk pruning effectiveness."""
    var total_chunks: Int
    var chunks_pruned: Int
    var chunks_scanned: Int
    var pruning_ratio: Float64

    fn __init__(inout self, total: Int, scanned: Int):
        """Initialize pruning statistics."""
        self.total_chunks = total
        self.chunks_scanned = scanned
        self.chunks_pruned = total - scanned
        self.pruning_ratio = Float64(self.chunks_pruned) / Float64(total) if total > 0 else 0.0

    fn __str__(self) -> String:
        """String representation."""
        return (
            "PruningStats(total=" + String(self.total_chunks) +
            ", scanned=" + String(self.chunks_scanned) +
            ", pruned=" + String(self.chunks_pruned) +
            ", ratio=" + String(self.pruning_ratio * 100.0) + "%)"
        )


fn calculate_pruning_stats(
    all_chunks: List[ChunkInfo],
    scanned_chunks: List[ChunkInfo]
) -> PruningStats:
    """
    Calculate chunk pruning statistics.

    Args:
        all_chunks: All available chunks
        scanned_chunks: Chunks actually scanned

    Returns:
        PruningStats showing pruning effectiveness

    Example:
        var stats = calculate_pruning_stats(all_chunks, plan.chunks_to_scan)
        print("Pruned", stats.pruning_ratio * 100.0, "% of chunks")
    """
    return PruningStats(len(all_chunks), len(scanned_chunks))
