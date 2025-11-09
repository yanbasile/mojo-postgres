"""
TimescaleDB Continuous Aggregates

Provides utilities for working with TimescaleDB continuous aggregates (CAGGs):
- Creating continuous aggregates
- Refreshing aggregates
- Querying aggregate metadata
- Real-time aggregate updates

Continuous aggregates provide 10-100x speedup for common aggregation queries
by materializing results and keeping them up-to-date automatically.

Features:
- CAGG creation with custom aggregations
- Manual and automatic refresh policies
- Real-time aggregation (includes latest data)
- OHLCV (candlestick) helpers for trading data

Usage:
    from src.timescaledb.continuous_aggregates import create_continuous_aggregate

    create_continuous_aggregate(
        conn,
        "orderbook_1min",
        "orderbook_data",
        "1 minute",
        {"avg_price": "AVG(price)", "volume": "SUM(quantity)"}
    )
"""

from src.protocol.connection import PostgresConnection
from collections import List, Dict


# ============================================================================
# Data Structures
# ============================================================================

@value
struct ContinuousAggregate:
    """Information about a continuous aggregate."""
    var view_name: String
    var source_table: String
    var refresh_interval: String
    var materialization_only: Bool  # True = materialized only, False = real-time
    var last_refresh: String        # Timestamp of last refresh

    fn __init__(inout self):
        """Initialize empty continuous aggregate."""
        self.view_name = ""
        self.source_table = ""
        self.refresh_interval = ""
        self.materialization_only = False
        self.last_refresh = ""

    fn __str__(self) -> String:
        """String representation."""
        return (
            "ContinuousAggregate(" +
            self.view_name + " FROM " + self.source_table + ", " +
            "refresh=" + self.refresh_interval + ", " +
            ("materialized-only" if self.materialization_only else "real-time") + ")"
        )


# ============================================================================
# Continuous Aggregate Creation
# ============================================================================

fn create_continuous_aggregate(
    inout conn: PostgresConnection,
    view_name: String,
    source_table: String,
    time_bucket: String,
    aggregations: Dict[String, String],
    time_column: String = "time",
    group_by_columns: List[String] = List[String](),
    with_data: Bool = True,
    materialized_only: Bool = False
) raises:
    """
    Create a continuous aggregate view.

    Args:
        conn: PostgreSQL connection
        view_name: Name for the continuous aggregate view
        source_table: Source hypertable name
        time_bucket: Time bucket interval (e.g., "1 minute", "1 hour", "1 day")
        aggregations: Dict of column_name -> aggregation_expression
        time_column: Name of time column (default: "time")
        group_by_columns: Additional columns to group by
        with_data: Materialize data immediately (default: True)
        materialized_only: If False, includes real-time data (default: False)

    Example:
        var aggs = Dict[String, String]()
        aggs["avg_price"] = "AVG(price)"
        aggs["volume"] = "SUM(quantity)"

        create_continuous_aggregate(
            conn,
            "orderbook_1min",
            "orderbook_data",
            "1 minute",
            aggs,
            group_by_columns=["symbol"]
        )
    """
    # Build SELECT clause with aggregations
    var select_parts = List[String]()
    select_parts.append("time_bucket(INTERVAL '" + time_bucket + "', " + time_column + ") AS bucket")

    # Add group by columns
    for i in range(len(group_by_columns)):
        select_parts.append(group_by_columns[i])

    # Add aggregations
    for key in aggregations.keys():
        var agg_expr = aggregations[key]
        select_parts.append(agg_expr + " AS " + key)

    var select_clause = ", ".join(select_parts)

    # Build GROUP BY clause
    var group_by_parts = List[String]()
    group_by_parts.append("bucket")

    for i in range(len(group_by_columns)):
        group_by_parts.append(group_by_columns[i])

    var group_by_clause = ", ".join(group_by_parts)

    # Build CREATE MATERIALIZED VIEW query
    var create_query = """
        CREATE MATERIALIZED VIEW """ + view_name + """
        WITH (timescaledb.continuous) AS
        SELECT """ + select_clause + """
        FROM """ + source_table + """
        GROUP BY """ + group_by_clause + """
    """

    if with_data:
        create_query += " WITH DATA"
    else:
        create_query += " WITH NO DATA"

    _ = conn.query(create_query)

    # Set real-time aggregation if requested
    if not materialized_only:
        var alter_query = """
            ALTER MATERIALIZED VIEW """ + view_name + """
            SET (timescaledb.materialized_only = false)
        """
        _ = conn.query(alter_query)


fn create_ohlcv_continuous_aggregate(
    inout conn: PostgresConnection,
    view_name: String,
    source_table: String,
    time_bucket: String,
    price_column: String = "price",
    volume_column: String = "quantity",
    time_column: String = "time",
    group_by_columns: List[String] = List[String]()
) raises:
    """
    Create OHLCV (Open, High, Low, Close, Volume) continuous aggregate.

    This is a convenience function for creating candlestick data aggregates,
    commonly used in trading and financial applications.

    Args:
        conn: PostgreSQL connection
        view_name: Name for the OHLCV view
        source_table: Source hypertable with trade data
        time_bucket: Candlestick interval (e.g., "1 minute", "5 minutes", "1 hour")
        price_column: Column containing price data
        volume_column: Column containing volume/quantity data
        time_column: Time column name
        group_by_columns: Additional grouping (e.g., ["symbol", "exchange"])

    Example:
        create_ohlcv_continuous_aggregate(
            conn,
            "ohlcv_1min",
            "trades",
            "1 minute",
            group_by_columns=["symbol"]
        )
    """
    var aggregations = Dict[String, String]()

    # Open: first price in the bucket (ordered by time ASC)
    aggregations["open"] = "(array_agg(" + price_column + " ORDER BY " + time_column + " ASC))[1]"

    # High: maximum price
    aggregations["high"] = "MAX(" + price_column + ")"

    # Low: minimum price
    aggregations["low"] = "MIN(" + price_column + ")"

    # Close: last price in the bucket (ordered by time DESC)
    aggregations["close"] = "(array_agg(" + price_column + " ORDER BY " + time_column + " DESC))[1]"

    # Volume: sum of all quantities
    aggregations["volume"] = "SUM(" + volume_column + ")"

    # Number of trades in bucket
    aggregations["num_trades"] = "COUNT(*)"

    create_continuous_aggregate(
        conn,
        view_name,
        source_table,
        time_bucket,
        aggregations,
        time_column,
        group_by_columns,
        with_data=True,
        materialized_only=False
    )


# ============================================================================
# Refresh Policies
# ============================================================================

fn add_continuous_aggregate_policy(
    inout conn: PostgresConnection,
    view_name: String,
    start_offset: String,
    end_offset: String,
    schedule_interval: String
) raises:
    """
    Add automatic refresh policy to a continuous aggregate.

    Args:
        conn: PostgreSQL connection
        view_name: Name of the continuous aggregate
        start_offset: How far back to refresh (e.g., "1 month")
        end_offset: How close to now to refresh (e.g., "1 hour")
        schedule_interval: How often to refresh (e.g., "1 hour")

    Example:
        # Refresh last month of data, every hour, excluding last hour
        add_continuous_aggregate_policy(
            conn,
            "orderbook_1min",
            start_offset="1 month",
            end_offset="1 hour",
            schedule_interval="1 hour"
        )
    """
    var policy_query = """
        SELECT add_continuous_aggregate_policy('""" + view_name + """',
            start_offset => INTERVAL '""" + start_offset + """',
            end_offset => INTERVAL '""" + end_offset + """',
            schedule_interval => INTERVAL '""" + schedule_interval + """'
        )
    """

    _ = conn.query(policy_query)


fn remove_continuous_aggregate_policy(
    inout conn: PostgresConnection,
    view_name: String
) raises:
    """
    Remove automatic refresh policy from a continuous aggregate.

    Args:
        conn: PostgreSQL connection
        view_name: Name of the continuous aggregate
    """
    var remove_query = """
        SELECT remove_continuous_aggregate_policy('""" + view_name + """')
    """

    _ = conn.query(remove_query)


# ============================================================================
# Manual Refresh
# ============================================================================

fn refresh_continuous_aggregate(
    inout conn: PostgresConnection,
    view_name: String,
    start_time: String = "",
    end_time: String = ""
) raises:
    """
    Manually refresh a continuous aggregate for a time range.

    Args:
        conn: PostgreSQL connection
        view_name: Name of the continuous aggregate
        start_time: Start of refresh range (default: all data)
        end_time: End of refresh range (default: now)

    Example:
        # Refresh all data
        refresh_continuous_aggregate(conn, "orderbook_1min")

        # Refresh last 24 hours
        refresh_continuous_aggregate(
            conn,
            "orderbook_1min",
            start_time="NOW() - INTERVAL '24 hours'",
            end_time="NOW()"
        )
    """
    var refresh_query = "CALL refresh_continuous_aggregate('" + view_name + "'"

    if len(start_time) > 0 and len(end_time) > 0:
        refresh_query += ", " + start_time + ", " + end_time

    refresh_query += ")"

    _ = conn.query(refresh_query)


# ============================================================================
# Querying Aggregates
# ============================================================================

fn query_continuous_aggregate_info(
    inout conn: PostgresConnection,
    view_name: String
) raises -> ContinuousAggregate:
    """
    Query information about a continuous aggregate.

    Args:
        conn: PostgreSQL connection
        view_name: Name of the continuous aggregate

    Returns:
        ContinuousAggregate with metadata

    Example:
        var info = query_continuous_aggregate_info(conn, "orderbook_1min")
        print("Last refresh:", info.last_refresh)
    """
    var agg = ContinuousAggregate()
    agg.view_name = view_name

    # Query continuous aggregate metadata
    var info_query = """
        SELECT
            view_name,
            view_definition,
            materialized_only
        FROM timescaledb_information.continuous_aggregates
        WHERE view_name = '""" + view_name + """'
    """

    var result = conn.query(info_query)

    if result.row_count() > 0:
        var materialized_str = result.get_value(0, 2)
        agg.materialization_only = materialized_str == "t" or materialized_str == "true"

    # Query refresh policy
    var policy_query = """
        SELECT
            schedule_interval,
            config
        FROM timescaledb_information.jobs
        WHERE application_name LIKE '%""" + view_name + """%'
            AND proc_name = 'policy_refresh_continuous_aggregate'
    """

    var policy_result = conn.query(policy_query)
    if policy_result.row_count() > 0:
        agg.refresh_interval = policy_result.get_value(0, 0)

    return agg


fn list_continuous_aggregates(
    inout conn: PostgresConnection
) raises -> List[ContinuousAggregate]:
    """
    List all continuous aggregates in the database.

    Args:
        conn: PostgreSQL connection

    Returns:
        List of all continuous aggregates

    Example:
        var aggregates = list_continuous_aggregates(conn)
        for agg in aggregates:
            print(agg[].view_name)
    """
    var aggregates = List[ContinuousAggregate]()

    var list_query = """
        SELECT
            view_name,
            materialized_only
        FROM timescaledb_information.continuous_aggregates
        ORDER BY view_name
    """

    var result = conn.query(list_query)

    for i in range(result.row_count()):
        var agg = ContinuousAggregate()
        agg.view_name = result.get_value(i, 0)

        var materialized_str = result.get_value(i, 1)
        agg.materialization_only = materialized_str == "t" or materialized_str == "true"

        aggregates.append(agg)

    return aggregates


# ============================================================================
# Aggregate Management
# ============================================================================

fn drop_continuous_aggregate(
    inout conn: PostgresConnection,
    view_name: String,
    cascade: Bool = False
) raises:
    """
    Drop a continuous aggregate view.

    Args:
        conn: PostgreSQL connection
        view_name: Name of the continuous aggregate
        cascade: Drop dependent objects too (default: False)

    Example:
        drop_continuous_aggregate(conn, "orderbook_1min")
    """
    var drop_query = "DROP MATERIALIZED VIEW " + view_name

    if cascade:
        drop_query += " CASCADE"

    _ = conn.query(drop_query)


fn get_continuous_aggregate_stats(
    inout conn: PostgresConnection,
    view_name: String
) raises -> Dict[String, String]:
    """
    Get statistics about a continuous aggregate.

    Args:
        conn: PostgreSQL connection
        view_name: Name of the continuous aggregate

    Returns:
        Dict with statistics (row_count, size_bytes, etc.)

    Example:
        var stats = get_continuous_aggregate_stats(conn, "orderbook_1min")
        print("Rows:", stats["row_count"])
    """
    var stats = Dict[String, String]()

    # Query row count
    var count_query = "SELECT COUNT(*) FROM " + view_name
    var count_result = conn.query(count_query)
    if count_result.row_count() > 0:
        stats["row_count"] = count_result.get_value(0, 0)

    # Query size
    var size_query = "SELECT pg_total_relation_size('" + view_name + "')"
    var size_result = conn.query(size_query)
    if size_result.row_count() > 0:
        stats["size_bytes"] = size_result.get_value(0, 0)

    return stats
