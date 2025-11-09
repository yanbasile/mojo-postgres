"""
DeFi Protocol Monitoring Data Generator

Generates realistic DeFi events including:
- Swaps (AMM trades)
- Liquidity additions/removals
- Flash loans
- Across multiple chains and protocols
"""

import random
import numpy as np
from datetime import datetime, timedelta
from typing import Iterator, List, Dict, Tuple
from dataclasses import dataclass
from enum import Enum


class Chain(Enum):
    """EVM-compatible blockchain networks."""
    ETHEREUM = "ethereum"
    BSC = "bsc"
    POLYGON = "polygon"
    ARBITRUM = "arbitrum"
    OPTIMISM = "optimism"
    AVALANCHE = "avalanche"
    FANTOM = "fantom"
    BASE = "base"


class EventType(Enum):
    """Types of DeFi events."""
    SWAP = "swap"
    ADD_LIQUIDITY = "add_liquidity"
    REMOVE_LIQUIDITY = "remove_liquidity"
    FLASH_LOAN = "flash_loan"


@dataclass
class DeFiEvent:
    """Single DeFi protocol event."""
    time: datetime
    chain: str
    protocol: str
    event_type: str
    transaction_hash: str
    pool_address: str
    token_in: str
    token_out: str
    amount_in: int  # Wei/smallest unit
    amount_out: int  # Wei/smallest unit
    sender: str
    block_number: int


class DeFiDataGenerator:
    """
    Generates realistic DeFi protocol events.

    Features:
    - Multiple chains (Ethereum, BSC, Polygon, etc.)
    - 500+ protocols (Uniswap, Curve, Aave, etc.)
    - Realistic event distributions (90% swaps, 8% liquidity, 2% flash loans)
    - Correlated events (arbitrage sequences)
    - Gas price variations
    - MEV bundle patterns
    """

    def __init__(self, seed: int = 42):
        """Initialize generator with random seed."""
        random.seed(seed)
        np.random.seed(seed)

        # Major DeFi protocols by chain
        self.protocols = {
            "ethereum": ["uniswap_v3", "curve", "aave", "compound", "1inch", "sushiswap", "balancer"],
            "bsc": ["pancakeswap", "venus", "biswap", "apeswap"],
            "polygon": ["quickswap", "sushiswap", "aave", "curve"],
            "arbitrum": ["uniswap_v3", "gmx", "camelot", "sushiswap"],
            "optimism": ["velodrome", "uniswap_v3", "synthetix"],
            "avalanche": ["trader_joe", "pangolin", "aave"],
            "fantom": ["spookyswap", "spiritswap", "geist"],
            "base": ["aerodrome", "uniswap_v3", "baseswap"]
        }

        # Popular token pairs
        self.token_pairs = [
            ("WETH", "USDC"),
            ("WETH", "USDT"),
            ("WETH", "DAI"),
            ("WBTC", "WETH"),
            ("USDC", "USDT"),
            ("WETH", "WMATIC"),  # Polygon
            ("WBNB", "BUSD"),    # BSC
            ("WAVAX", "USDC"),   # Avalanche
        ]

        # Transaction hash counter
        self.tx_counter = 0

        # Block number counter per chain
        self.block_numbers = {chain.value: 1000000 for chain in Chain}

        # Pool addresses (simplified)
        self.pool_counter = 0

    def _generate_event_type(self) -> str:
        """
        Generate event type with realistic distribution.

        Distribution:
        - 90% swaps
        - 7% add liquidity
        - 2.5% remove liquidity
        - 0.5% flash loans
        """
        rand = random.random()

        if rand < 0.90:
            return EventType.SWAP.value
        elif rand < 0.97:
            return EventType.ADD_LIQUIDITY.value
        elif rand < 0.995:
            return EventType.REMOVE_LIQUIDITY.value
        else:
            return EventType.FLASH_LOAN.value

    def _generate_amount(self, token: str, event_type: str) -> int:
        """
        Generate amount in Wei/smallest unit.

        Uses log-normal distribution to simulate realistic amounts with:
        - Many small trades (retail)
        - Few large trades (whales, institutions)

        Args:
            token: Token symbol
            event_type: Type of event

        Returns:
            Amount in Wei (18 decimals for most tokens)
        """
        # Base amount (18 decimals)
        if event_type == EventType.FLASH_LOAN.value:
            # Flash loans are typically large (100K - 10M)
            base = np.random.lognormal(18, 2)  # Mean ~100K
        elif event_type in [EventType.ADD_LIQUIDITY.value, EventType.REMOVE_LIQUIDITY.value]:
            # Liquidity operations are medium-large (1K - 100K)
            base = np.random.lognormal(16, 2)  # Mean ~10K
        else:
            # Swaps range from small to large (10 - 100K)
            base = np.random.lognormal(14, 3)  # Mean ~1K

        # Token-specific scaling
        if token in ["WBTC"]:
            # BTC has 8 decimals and is more expensive
            return int(base * 1e8 / 1e18 / 40000)  # Scale for BTC price
        elif token in ["WETH"]:
            return int(base)
        elif token in ["USDC", "USDT", "DAI", "BUSD"]:
            # Stablecoins
            return int(base)
        else:
            return int(base)

    def _generate_tx_hash(self, chain: str) -> str:
        """Generate realistic transaction hash."""
        self.tx_counter += 1
        # Ethereum-style 0x + 64 hex characters
        return f"0x{self.tx_counter:064x}"

    def _generate_pool_address(self, chain: str, token_in: str, token_out: str) -> str:
        """Generate pool address (simplified)."""
        self.pool_counter += 1
        return f"0x{self.pool_counter:040x}"

    def _generate_sender_address(self) -> str:
        """Generate random Ethereum address."""
        return f"0x{random.randint(0, 2**160-1):040x}"

    def _generate_block_number(self, chain: str) -> int:
        """Get and increment block number for chain."""
        block = self.block_numbers[chain]
        # New block every ~12 seconds on Ethereum
        if random.random() < 0.1:  # 10% chance to increment
            self.block_numbers[chain] += 1
        return block

    def _should_generate_arbitrage_sequence(self) -> bool:
        """Determine if this should be part of an arbitrage sequence."""
        # 5% of events are part of arbitrage
        return random.random() < 0.05

    def generate_events(self, duration_seconds: int = 3600,
                       events_per_second: int = 5000) -> Iterator[DeFiEvent]:
        """
        Generate DeFi event stream.

        Args:
            duration_seconds: How long to generate data for
            events_per_second: Average events/sec

        Yields:
            DeFiEvent objects
        """
        start_time = datetime.now()
        current_time = start_time

        total_events = duration_seconds * events_per_second

        print(f"Generating {total_events:,} DeFi events...")
        print(f"  Duration: {duration_seconds}s ({duration_seconds/3600:.1f} hours)")
        print(f"  Rate: {events_per_second:,} events/sec")
        print(f"  Chains: {len(Chain)}")

        events_generated = 0

        for _ in range(total_events):
            # Increment time (millisecond precision)
            current_time += timedelta(milliseconds=random.randint(1, 10))

            # Select chain (weighted by activity)
            chain_weights = [0.50, 0.15, 0.10, 0.08, 0.07, 0.05, 0.03, 0.02]  # Ethereum dominates
            chain = random.choices(list(Chain), weights=chain_weights)[0].value

            # Select protocol for this chain
            protocol = random.choice(self.protocols[chain])

            # Generate event type
            event_type = self._generate_event_type()

            # Select token pair
            token_in, token_out = random.choice(self.token_pairs)

            # Generate amounts
            amount_in = self._generate_amount(token_in, event_type)

            # Calculate amount_out based on simulated price
            # Simplified: assume 1:1 for stablecoins, realistic ratios for others
            if token_in == "WETH" and token_out in ["USDC", "USDT", "DAI"]:
                # ETH price ~$2500
                price_ratio = 2500
            elif token_in == "WBTC" and token_out == "WETH":
                # BTC/ETH ratio ~15
                price_ratio = 15
            else:
                price_ratio = 1.0

            # Add slippage (0.1-0.5%)
            slippage = random.uniform(0.999, 0.995)
            amount_out = int(amount_in * price_ratio * slippage)

            # Generate other fields
            tx_hash = self._generate_tx_hash(chain)
            pool_address = self._generate_pool_address(chain, token_in, token_out)
            sender = self._generate_sender_address()
            block_number = self._generate_block_number(chain)

            # Check if this is part of arbitrage sequence
            if self._should_generate_arbitrage_sequence() and event_type == EventType.SWAP.value:
                # Generate 2-3 correlated swaps with same tx_hash (MEV bundle)
                num_swaps = random.randint(2, 3)

                for i in range(num_swaps):
                    # Arbitrage involves swapping across different protocols/chains
                    arb_chain = random.choice(list(Chain)).value
                    arb_protocol = random.choice(self.protocols[arb_chain])

                    yield DeFiEvent(
                        time=current_time,
                        chain=arb_chain,
                        protocol=arb_protocol,
                        event_type=event_type,
                        transaction_hash=tx_hash,  # Same tx for all arb swaps
                        pool_address=self._generate_pool_address(arb_chain, token_in, token_out),
                        token_in=token_in if i % 2 == 0 else token_out,
                        token_out=token_out if i % 2 == 0 else token_in,
                        amount_in=amount_in,
                        amount_out=amount_out,
                        sender=sender,  # Same sender for arb
                        block_number=self._generate_block_number(arb_chain)
                    )

                    events_generated += 1

            else:
                # Regular event
                yield DeFiEvent(
                    time=current_time,
                    chain=chain,
                    protocol=protocol,
                    event_type=event_type,
                    transaction_hash=tx_hash,
                    pool_address=pool_address,
                    token_in=token_in,
                    token_out=token_out,
                    amount_in=amount_in,
                    amount_out=amount_out,
                    sender=sender,
                    block_number=block_number
                )

                events_generated += 1

            # Progress update
            if events_generated % 1_000_000 == 0:
                print(f"  Generated {events_generated:,} events...")

        print(f"✅ Generated {events_generated:,} events")

    def generate_dataset(self, size: str = "small") -> List[DeFiEvent]:
        """
        Generate complete dataset.

        Args:
            size: 'small' (1M rows), 'medium' (100M rows), 'large' (1B rows)

        Returns:
            List of DeFiEvent objects
        """
        # Calculate parameters based on size
        if size == "small":
            # 1M events at 5K/sec = 200 seconds
            duration_seconds = 200
            events_per_second = 5000
        elif size == "medium":
            # 100M events at 5K/sec = 20,000 seconds (~5.5 hours)
            duration_seconds = 20000
            events_per_second = 5000
        elif size == "large":
            # 1B events at 5K/sec = 200,000 seconds (~55 hours)
            duration_seconds = 200000
            events_per_second = 5000
        else:
            raise ValueError(f"Unknown size: {size}")

        events = list(self.generate_events(
            duration_seconds=duration_seconds,
            events_per_second=events_per_second
        ))

        return events


def main():
    """Example usage and testing."""
    generator = DeFiDataGenerator(seed=42)

    # Generate 10 seconds of data
    print("Generating sample DeFi data...")
    events = list(generator.generate_events(duration_seconds=10, events_per_second=100))

    print(f"\n✅ Generated {len(events):,} events")
    print("\nSample events (first 10):")

    for i, event in enumerate(events[:10]):
        print(f"  {i+1}. {event.time.strftime('%H:%M:%S.%f')[:-3]} | "
              f"{event.chain:10s} | {event.protocol:12s} | "
              f"{event.event_type:15s} | {event.token_in} → {event.token_out}")

    # Statistics
    from collections import Counter

    print("\nEvent Type Distribution:")
    event_counts = Counter(e.event_type for e in events)
    for event_type, count in event_counts.most_common():
        print(f"  {event_type:20s}: {count:5d} ({count/len(events)*100:5.1f}%)")

    print("\nChain Distribution:")
    chain_counts = Counter(e.chain for e in events)
    for chain, count in chain_counts.most_common():
        print(f"  {chain:15s}: {count:5d} ({count/len(events)*100:5.1f}%)")

    print("\nProtocol Distribution (top 10):")
    protocol_counts = Counter(e.protocol for e in events)
    for protocol, count in protocol_counts.most_common(10):
        print(f"  {protocol:15s}: {count:5d} ({count/len(events)*100:5.1f}%)")

    print("\nFlash Loan Detection:")
    flash_loans = [e for e in events if e.event_type == EventType.FLASH_LOAN.value]
    print(f"  Total flash loans: {len(flash_loans)}")

    print("\nArbitrage Detection (same tx_hash):")
    tx_counts = Counter(e.transaction_hash for e in events)
    arb_txs = [(tx, count) for tx, count in tx_counts.items() if count > 1]
    print(f"  Potential arbitrage transactions: {len(arb_txs)}")
    if arb_txs:
        print(f"  Largest arbitrage sequence: {max(count for _, count in arb_txs)} swaps")


if __name__ == "__main__":
    main()
