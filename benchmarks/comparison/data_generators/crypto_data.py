"""
Cryptocurrency Trading Data Generator

Generates realistic orderbook updates for cryptocurrency exchanges using:
- Brownian motion for price movements
- Power law distribution for quantities
- Realistic exchange patterns (100Hz updates)
- Multiple symbols and exchanges
"""

import random
import numpy as np
from datetime import datetime, timedelta
from typing import Iterator, List, Tuple
from dataclasses import dataclass


@dataclass
class OrderbookUpdate:
    """Single orderbook update."""
    time: datetime
    exchange: str
    symbol: str
    side: str  # 'bid' or 'ask'
    price_level: int  # 0-19 for top 20 levels
    price: float
    quantity: float
    update_id: int


class CryptoDataGenerator:
    """
    Generates realistic cryptocurrency orderbook data.

    Features:
    - Brownian motion for price evolution
    - Realistic spread (0.01-0.1%)
    - Volume clustering (Pareto distribution)
    - Multiple exchanges with correlated prices
    - High-frequency updates (100Hz+)
    """

    def __init__(self, seed: int = 42):
        """Initialize generator with random seed."""
        random.seed(seed)
        np.random.seed(seed)

        # Exchange configurations
        self.exchanges = ["binance", "coinbase", "kraken"]

        # Symbol configurations with base prices
        self.symbols = {
            "BTC/USDT": 45000.0,
            "ETH/USDT": 2500.0,
            "SOL/USDT": 100.0,
            "BNB/USDT": 350.0,
            "ADA/USDT": 0.50
        }

        # Current prices per exchange/symbol
        self.current_prices = {}
        for exchange in self.exchanges:
            for symbol, base_price in self.symbols.items():
                # Add small exchange-specific variation
                variation = 1.0 + random.uniform(-0.001, 0.001)
                self.current_prices[(exchange, symbol)] = base_price * variation

    def _brownian_motion(self, current_price: float, dt: float = 0.01,
                        volatility: float = 0.02) -> float:
        """
        Generate price movement using Geometric Brownian Motion.

        Args:
            current_price: Current price level
            dt: Time step (0.01 = 10ms for 100Hz)
            volatility: Annual volatility (0.02 = 2%)

        Returns:
            New price after random walk
        """
        drift = 0.0  # Assume no drift for symmetric walk
        shock = np.random.normal(0, 1)
        price_change = current_price * (drift * dt + volatility * np.sqrt(dt) * shock)

        new_price = current_price + price_change

        # Ensure price doesn't go negative or too far from base
        base_price = self.symbols[list(self.symbols.keys())[0]]  # Placeholder
        new_price = max(new_price, current_price * 0.95)  # Max 5% drop per step
        new_price = min(new_price, current_price * 1.05)  # Max 5% rise per step

        return new_price

    def _generate_spread(self, mid_price: float) -> Tuple[float, float]:
        """
        Generate realistic bid/ask spread.

        Returns:
            (best_bid, best_ask) tuple
        """
        # Spread in basis points (0.01% - 0.1%)
        spread_bps = random.uniform(1, 10)
        spread_dollars = mid_price * (spread_bps / 10000.0)

        best_bid = mid_price - spread_dollars / 2
        best_ask = mid_price + spread_dollars / 2

        return (best_bid, best_ask)

    def _generate_quantity(self, symbol: str) -> float:
        """
        Generate order quantity using power law distribution.

        Power law creates realistic clustering with:
        - Many small orders (retail)
        - Few large orders (institutional)
        """
        # Pareto distribution (alpha=1.5 gives realistic distribution)
        base_quantity = np.random.pareto(1.5) + 0.01

        # Scale based on symbol
        if "BTC" in symbol:
            return base_quantity * 0.1  # BTC quantities are smaller
        elif "ETH" in symbol:
            return base_quantity * 1.0
        elif "SOL" in symbol:
            return base_quantity * 10.0
        else:
            return base_quantity * 5.0

    def _generate_orderbook_levels(self, mid_price: float, symbol: str,
                                   num_levels: int = 20) -> List[Tuple[float, float]]:
        """
        Generate orderbook levels (price, quantity) for multiple depth levels.

        Returns:
            List of (price, quantity) tuples for bid or ask side
        """
        levels = []

        # Generate prices with increasing distance from mid
        for i in range(num_levels):
            # Distance increases exponentially
            distance_bps = (i + 1) * random.uniform(1, 5)
            distance = mid_price * (distance_bps / 10000.0)

            price = mid_price - distance  # Bid side (adjust sign for ask)
            quantity = self._generate_quantity(symbol)

            levels.append((price, quantity))

        return levels

    def generate_updates(self, duration_seconds: int = 3600,
                        updates_per_second: int = 100,
                        num_price_levels: int = 5) -> Iterator[OrderbookUpdate]:
        """
        Generate orderbook updates over time.

        Args:
            duration_seconds: How long to generate data for
            updates_per_second: Update frequency per exchange (100Hz = 100 updates/sec)
            num_price_levels: Number of price levels to generate (0-4 = top 5)

        Yields:
            OrderbookUpdate objects
        """
        start_time = datetime.now()
        total_updates = duration_seconds * updates_per_second * len(self.exchanges) * len(self.symbols)

        print(f"Generating {total_updates:,} orderbook updates...")
        print(f"  Duration: {duration_seconds}s")
        print(f"  Frequency: {updates_per_second}Hz per exchange/symbol")
        print(f"  Exchanges: {len(self.exchanges)}")
        print(f"  Symbols: {len(self.symbols)}")

        update_id = 0
        current_time = start_time

        for _ in range(duration_seconds * updates_per_second):
            # Update timestamp (10ms intervals for 100Hz)
            current_time += timedelta(milliseconds=10)

            for exchange in self.exchanges:
                for symbol in self.symbols.keys():
                    # Update price using Brownian motion
                    key = (exchange, symbol)
                    old_price = self.current_prices[key]
                    new_price = self._brownian_motion(old_price, dt=0.01)
                    self.current_prices[key] = new_price

                    # Generate spread
                    best_bid, best_ask = self._generate_spread(new_price)

                    # Generate bid levels
                    for level in range(num_price_levels):
                        price = best_bid - (level * new_price * 0.0001)  # Decreasing prices
                        quantity = self._generate_quantity(symbol)

                        yield OrderbookUpdate(
                            time=current_time,
                            exchange=exchange,
                            symbol=symbol,
                            side="bid",
                            price_level=level,
                            price=price,
                            quantity=quantity,
                            update_id=update_id
                        )
                        update_id += 1

                    # Generate ask levels
                    for level in range(num_price_levels):
                        price = best_ask + (level * new_price * 0.0001)  # Increasing prices
                        quantity = self._generate_quantity(symbol)

                        yield OrderbookUpdate(
                            time=current_time,
                            exchange=exchange,
                            symbol=symbol,
                            side="ask",
                            price_level=level,
                            price=price,
                            quantity=quantity,
                            update_id=update_id
                        )
                        update_id += 1

    def generate_dataset(self, size: str = "small") -> List[OrderbookUpdate]:
        """
        Generate complete dataset.

        Args:
            size: 'small' (1M rows), 'medium' (100M rows), 'large' (1B rows)

        Returns:
            List of OrderbookUpdate objects
        """
        # Calculate parameters based on size
        if size == "small":
            duration_seconds = 100  # ~1M rows
        elif size == "medium":
            duration_seconds = 10000  # ~100M rows
        elif size == "large":
            duration_seconds = 100000  # ~1B rows
        else:
            raise ValueError(f"Unknown size: {size}")

        updates = list(self.generate_updates(
            duration_seconds=duration_seconds,
            updates_per_second=100,
            num_price_levels=5
        ))

        print(f"✅ Generated {len(updates):,} updates")
        return updates


def main():
    """Example usage and testing."""
    generator = CryptoDataGenerator(seed=42)

    # Generate small sample
    print("Generating sample data...")
    updates = list(generator.generate_updates(duration_seconds=1, updates_per_second=100))

    print(f"\n✅ Generated {len(updates):,} updates")
    print("\nSample updates:")

    # Show first 10
    for i, update in enumerate(updates[:10]):
        print(f"  {i+1}. {update.time.strftime('%H:%M:%S.%f')[:-3]} | "
              f"{update.exchange:8s} | {update.symbol:10s} | "
              f"{update.side:4s} L{update.price_level} | "
              f"${update.price:10.2f} × {update.quantity:8.4f}")

    # Statistics
    print("\nPrice Statistics:")
    for symbol in generator.symbols.keys():
        prices = [u.price for u in updates if u.symbol == symbol and u.side == "bid" and u.price_level == 0]
        if prices:
            print(f"  {symbol}: ${min(prices):.2f} - ${max(prices):.2f} "
                  f"(avg ${np.mean(prices):.2f}, std ${np.std(prices):.2f})")

    print("\nQuantity Statistics:")
    quantities = [u.quantity for u in updates]
    print(f"  Min: {min(quantities):.4f}")
    print(f"  Max: {max(quantities):.4f}")
    print(f"  Avg: {np.mean(quantities):.4f}")
    print(f"  Median: {np.median(quantities):.4f}")


if __name__ == "__main__":
    main()
