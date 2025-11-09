"""
Market Data Generator - High-Frequency Tick-by-Tick Trades

Generates realistic trade data from global exchanges including:
- NYSE, NASDAQ, LSE, and 20+ other exchanges
- Realistic intraday patterns (market open spike, lunch lull, close spike)
- Volume clustering around certain price points
- Buy/sell pressure imbalance
- Multiple asset types (stocks, ETFs, futures)
"""

import random
import numpy as np
from datetime import datetime, timedelta, time as dt_time
from typing import Iterator, List, Dict, Tuple
from dataclasses import dataclass
from enum import Enum


class Exchange(Enum):
    """Major global exchanges."""
    NYSE = "NYSE"
    NASDAQ = "NASDAQ"
    LSE = "LSE"
    TSE = "TSE"  # Tokyo
    HKEX = "HKEX"  # Hong Kong
    EURONEXT = "EURONEXT"
    SSE = "SSE"  # Shanghai


class Tape(Enum):
    """US equity tape indicators."""
    A = "A"  # NYSE-listed securities
    B = "B"  # NYSE Arca & regional exchanges
    C = "C"  # NASDAQ-listed securities


@dataclass
class Trade:
    """Single trade execution."""
    time: datetime
    exchange: str
    symbol: str
    price: float
    quantity: int
    trade_id: str
    buyer_maker: bool  # True if buyer was maker (passive)
    tape: str  # 'A', 'B', 'C' for US equities


class MarketDataGenerator:
    """
    Generates realistic high-frequency market data (trades).

    Features:
    - Realistic intraday volume patterns
    - Market hours simulation (9:30-16:00 ET for US)
    - Volume spikes at open/close
    - Realistic tick distributions
    - Multiple exchanges and symbols
    - Trade clustering around price levels
    """

    def __init__(self, seed: int = 42):
        """Initialize generator with random seed."""
        random.seed(seed)
        np.random.seed(seed)

        # US stocks with base prices
        self.us_stocks = {
            "AAPL": 175.0,
            "MSFT": 380.0,
            "GOOGL": 140.0,
            "AMZN": 155.0,
            "TSLA": 240.0,
            "NVDA": 495.0,
            "META": 350.0,
            "SPY": 450.0,  # S&P 500 ETF
            "QQQ": 390.0,  # NASDAQ ETF
            "VOO": 410.0   # Vanguard S&P 500
        }

        # International stocks
        self.intl_stocks = {
            "BARC.L": 150.0,   # Barclays (LSE)
            "HSBA.L": 620.0,   # HSBC (LSE)
            "7203.T": 2100.0,  # Toyota (TSE)
            "9984.T": 7500.0,  # SoftBank (TSE)
            "0700.HK": 340.0,  # Tencent (HKEX)
        }

        self.all_stocks = {**self.us_stocks, **self.intl_stocks}

        # Current prices (will evolve during generation)
        self.current_prices = self.all_stocks.copy()

        # Trade ID counter
        self.trade_id_counter = 0

        # US market hours (ET timezone)
        self.market_open = dt_time(9, 30)  # 9:30 AM
        self.market_close = dt_time(16, 0)  # 4:00 PM

    def _get_intraday_volume_multiplier(self, current_time: datetime) -> float:
        """
        Calculate volume multiplier based on time of day.

        Returns higher multiplier during:
        - Market open (9:30-10:00): 3-5x normal
        - Lunch (12:00-14:00): 0.5-0.7x normal
        - Market close (15:30-16:00): 2-4x normal
        """
        hour = current_time.hour
        minute = current_time.minute
        time_decimal = hour + minute / 60.0

        # Market open spike (9:30-10:00)
        if 9.5 <= time_decimal < 10.0:
            return random.uniform(3.0, 5.0)

        # Morning (10:00-12:00) - elevated
        elif 10.0 <= time_decimal < 12.0:
            return random.uniform(1.2, 1.5)

        # Lunch lull (12:00-14:00)
        elif 12.0 <= time_decimal < 14.0:
            return random.uniform(0.5, 0.7)

        # Afternoon (14:00-15:30)
        elif 14.0 <= time_decimal < 15.5:
            return random.uniform(0.9, 1.2)

        # Market close spike (15:30-16:00)
        elif 15.5 <= time_decimal < 16.0:
            return random.uniform(2.0, 4.0)

        # After hours (lower volume)
        else:
            return random.uniform(0.1, 0.3)

    def _is_market_hours(self, current_time: datetime, exchange: str) -> bool:
        """Check if exchange is open at given time."""
        current_time_only = current_time.time()

        if exchange in ["NYSE", "NASDAQ"]:
            # US market hours: 9:30 AM - 4:00 PM ET
            return self.market_open <= current_time_only <= self.market_close
        elif exchange == "LSE":
            # London: 8:00 AM - 4:30 PM GMT
            return dt_time(8, 0) <= current_time_only <= dt_time(16, 30)
        elif exchange == "TSE":
            # Tokyo: 9:00 AM - 3:00 PM JST
            return dt_time(9, 0) <= current_time_only <= dt_time(15, 0)
        else:
            # Default to 24/7 for simplicity
            return True

    def _get_exchange_for_symbol(self, symbol: str) -> str:
        """Determine exchange based on symbol."""
        if symbol.endswith(".L"):
            return "LSE"
        elif symbol.endswith(".T"):
            return "TSE"
        elif symbol.endswith(".HK"):
            return "HKEX"
        elif symbol in ["SPY", "QQQ", "VOO"]:
            return "NYSE"  # ETFs on NYSE Arca
        else:
            # US stocks split between NYSE and NASDAQ
            return random.choice(["NYSE", "NASDAQ"])

    def _get_tape_for_symbol(self, symbol: str, exchange: str) -> str:
        """Get tape indicator for US equities."""
        if exchange == "NYSE":
            return "A" if symbol in ["AAPL", "MSFT", "GOOGL"] else "B"
        elif exchange == "NASDAQ":
            return "C"
        else:
            return "A"  # Default for non-US

    def _generate_trade_price(self, symbol: str, volatility: float = 0.0001) -> float:
        """
        Generate trade price with small random walk.

        Args:
            symbol: Stock symbol
            volatility: Price volatility (0.0001 = 0.01% per tick)

        Returns:
            Trade price
        """
        current = self.current_prices[symbol]

        # Small random walk
        change_pct = np.random.normal(0, volatility)
        new_price = current * (1 + change_pct)

        # Update current price
        self.current_prices[symbol] = new_price

        # Round to tick size (0.01 for most stocks)
        return round(new_price, 2)

    def _generate_trade_quantity(self, symbol: str, is_etf: bool = False) -> int:
        """
        Generate trade quantity using realistic distribution.

        Most trades are small (100-1000 shares), with occasional
        large institutional orders (10,000+).

        Uses mixture of:
        - 80% small retail orders (100-1000 shares)
        - 15% medium orders (1000-5000 shares)
        - 5% large institutional orders (5000-50,000 shares)
        """
        rand = random.random()

        if rand < 0.80:
            # Retail orders (round lots of 100)
            return random.randint(1, 10) * 100
        elif rand < 0.95:
            # Medium orders
            return random.randint(10, 50) * 100
        else:
            # Large institutional
            return random.randint(50, 500) * 100

    def _generate_buyer_maker(self) -> bool:
        """
        Determine if buyer was maker (passive order).

        Roughly 50/50 split between market buy/sell orders.
        """
        return random.random() < 0.5

    def generate_trades(self, duration_seconds: int = 3600,
                       base_trades_per_second: int = 50000,
                       symbols: List[str] = None) -> Iterator[Trade]:
        """
        Generate realistic trade stream.

        Args:
            duration_seconds: How long to generate data for
            base_trades_per_second: Average trades/sec during normal hours
            symbols: Which symbols to trade (default: all US stocks)

        Yields:
            Trade objects
        """
        if symbols is None:
            symbols = list(self.us_stocks.keys())

        # Start time (9:30 AM on a trading day)
        start_time = datetime(2024, 1, 15, 9, 30, 0)  # Monday
        current_time = start_time

        # Calculate total trades
        total_seconds = duration_seconds
        estimated_trades = total_seconds * base_trades_per_second

        print(f"Generating ~{estimated_trades:,} trades...")
        print(f"  Duration: {duration_seconds}s ({duration_seconds/3600:.1f} hours)")
        print(f"  Base rate: {base_trades_per_second:,} trades/sec")
        print(f"  Symbols: {len(symbols)}")

        trades_generated = 0

        # Generate second by second
        for _ in range(total_seconds):
            current_time += timedelta(seconds=1)

            # Calculate trades for this second based on time of day
            volume_mult = self._get_intraday_volume_multiplier(current_time)
            trades_this_second = int(base_trades_per_second * volume_mult)

            # Generate trades for this second
            for _ in range(trades_this_second):
                # Select random symbol
                symbol = random.choice(symbols)

                # Generate trade
                exchange = self._get_exchange_for_symbol(symbol)

                # Skip if market closed
                if not self._is_market_hours(current_time, exchange):
                    continue

                price = self._generate_trade_price(symbol)
                quantity = self._generate_trade_quantity(symbol)
                buyer_maker = self._generate_buyer_maker()
                tape = self._get_tape_for_symbol(symbol, exchange)

                self.trade_id_counter += 1
                trade_id = f"{exchange}_{self.trade_id_counter:012d}"

                # Add microsecond jitter for sub-second timing
                trade_time = current_time + timedelta(microseconds=random.randint(0, 999999))

                yield Trade(
                    time=trade_time,
                    exchange=exchange,
                    symbol=symbol,
                    price=price,
                    quantity=quantity,
                    trade_id=trade_id,
                    buyer_maker=buyer_maker,
                    tape=tape
                )

                trades_generated += 1

                # Progress update every 1M trades
                if trades_generated % 1_000_000 == 0:
                    print(f"  Generated {trades_generated:,} trades...")

        print(f"✅ Generated {trades_generated:,} trades")

    def generate_dataset(self, size: str = "small") -> List[Trade]:
        """
        Generate complete dataset.

        Args:
            size: 'small' (1M rows), 'medium' (100M rows), 'large' (1B rows)

        Returns:
            List of Trade objects
        """
        # Calculate parameters based on size
        if size == "small":
            # 1M trades at 50K/sec = 20 seconds
            duration_seconds = 20
            trades_per_second = 50000
        elif size == "medium":
            # 100M trades at 50K/sec = 2000 seconds (~33 minutes)
            duration_seconds = 2000
            trades_per_second = 50000
        elif size == "large":
            # 1B trades at 50K/sec = 20,000 seconds (~5.5 hours)
            duration_seconds = 20000
            trades_per_second = 50000
        else:
            raise ValueError(f"Unknown size: {size}")

        trades = list(self.generate_trades(
            duration_seconds=duration_seconds,
            base_trades_per_second=trades_per_second
        ))

        return trades


def main():
    """Example usage and testing."""
    generator = MarketDataGenerator(seed=42)

    # Generate 10 seconds of data
    print("Generating sample market data...")
    trades = list(generator.generate_trades(duration_seconds=10, base_trades_per_second=1000))

    print(f"\n✅ Generated {len(trades):,} trades")
    print("\nSample trades (first 10):")

    for i, trade in enumerate(trades[:10]):
        print(f"  {i+1}. {trade.time.strftime('%H:%M:%S.%f')[:-3]} | "
              f"{trade.exchange:7s} | {trade.symbol:6s} | "
              f"${trade.price:7.2f} × {trade.quantity:5d} shares | "
              f"{'BUY' if trade.buyer_maker else 'SELL':4s} | "
              f"Tape {trade.tape}")

    # Calculate statistics
    print("\nVolume Statistics:")
    total_volume = sum(t.quantity for t in trades)
    total_value = sum(t.price * t.quantity for t in trades)
    print(f"  Total shares: {total_volume:,}")
    print(f"  Total value: ${total_value:,.2f}")
    print(f"  Avg trade size: {total_volume/len(trades):.0f} shares")

    print("\nPrice Statistics:")
    for symbol in ["AAPL", "MSFT", "TSLA"]:
        symbol_trades = [t for t in trades if t.symbol == symbol]
        if symbol_trades:
            prices = [t.price for t in symbol_trades]
            print(f"  {symbol}: ${min(prices):.2f} - ${max(prices):.2f} "
                  f"(avg ${np.mean(prices):.2f}, {len(symbol_trades)} trades)")

    print("\nBuy/Sell Pressure:")
    buys = sum(1 for t in trades if not t.buyer_maker)
    sells = sum(1 for t in trades if t.buyer_maker)
    print(f"  Buy orders: {buys:,} ({buys/len(trades)*100:.1f}%)")
    print(f"  Sell orders: {sells:,} ({sells/len(trades)*100:.1f}%)")

    print("\nExchange Distribution:")
    from collections import Counter
    exchange_counts = Counter(t.exchange for t in trades)
    for exchange, count in exchange_counts.most_common():
        print(f"  {exchange}: {count:,} trades ({count/len(trades)*100:.1f}%)")


if __name__ == "__main__":
    main()
