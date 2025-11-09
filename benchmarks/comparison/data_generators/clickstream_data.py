"""
E-commerce Clickstream Data Generator

Generates realistic user clickstream for e-commerce site:
- Page views (home, category, product, cart, checkout)
- Conversion funnels
- User sessions with realistic bounce rates
- A/B testing variants
- User segments (new vs returning)
- Shopping cart abandonment
"""

import random
import numpy as np
from datetime import datetime, timedelta
from typing import Iterator, List, Dict, Tuple, Optional
from dataclasses import dataclass
from enum import Enum
import hashlib


class EventType(Enum):
    """Types of clickstream events."""
    PAGE_VIEW = "page_view"
    PRODUCT_VIEW = "product_view"
    ADD_TO_CART = "add_to_cart"
    REMOVE_FROM_CART = "remove_from_cart"
    CHECKOUT_START = "checkout_start"
    CHECKOUT_COMPLETE = "checkout_complete"
    SEARCH = "search"
    FILTER = "filter"


class PageType(Enum):
    """Types of pages."""
    HOME = "home"
    CATEGORY = "category"
    PRODUCT = "product"
    CART = "cart"
    CHECKOUT = "checkout"
    SEARCH_RESULTS = "search_results"
    ACCOUNT = "account"


@dataclass
class ClickEvent:
    """Single clickstream event."""
    time: datetime
    session_id: str
    user_id: Optional[int]  # None for anonymous users
    event_type: str
    page_type: str
    page_url: str
    product_id: Optional[str]
    category: Optional[str]
    price: Optional[float]
    quantity: int
    ab_test_variant: str  # 'A' or 'B'
    referrer: Optional[str]
    device_type: str  # 'desktop', 'mobile', 'tablet'
    browser: str
    country: str


class ClickstreamDataGenerator:
    """
    Generates realistic e-commerce clickstream data.

    Features:
    - 10M+ users (70% anonymous, 30% logged in)
    - Realistic conversion funnels (3-5% conversion rate)
    - Session tracking with bounce rates
    - A/B test variants
    - Device/browser distribution
    - Cart abandonment (70% abandon rate)
    - Multi-step checkout flow
    """

    def __init__(self, seed: int = 42, num_users: int = 10_000_000):
        """Initialize generator with random seed."""
        random.seed(seed)
        np.random.seed(seed)

        self.num_users = num_users

        # Categories and products
        self.categories = [
            "electronics", "clothing", "home", "sports", "books",
            "toys", "beauty", "automotive", "grocery", "jewelry"
        ]

        self.products_per_category = 500
        self.total_products = len(self.categories) * self.products_per_category

        # Session tracking
        self.session_counter = 0
        self.active_sessions: Dict[str, Dict] = {}

        # Devices
        self.devices = {
            "mobile": 0.55,    # 55% mobile
            "desktop": 0.35,   # 35% desktop
            "tablet": 0.10     # 10% tablet
        }

        # Browsers
        self.browsers = {
            "chrome": 0.65,
            "safari": 0.20,
            "firefox": 0.10,
            "edge": 0.05
        }

        # Countries
        self.countries = {
            "US": 0.45,
            "UK": 0.15,
            "CA": 0.10,
            "DE": 0.08,
            "FR": 0.07,
            "AU": 0.05,
            "JP": 0.05,
            "IN": 0.03,
            "BR": 0.02
        }

        # Referrers
        self.referrers = [
            "google", "facebook", "instagram", "twitter",
            "email", "direct", "bing", "youtube"
        ]

        print(f"Initialized ClickstreamDataGenerator with {num_users:,} potential users")

    def _generate_session_id(self, user_id: Optional[int]) -> str:
        """Generate unique session ID."""
        self.session_counter += 1
        user_part = str(user_id) if user_id else "anon"
        return f"sess_{user_part}_{self.session_counter:010d}"

    def _generate_user_id(self) -> Optional[int]:
        """Generate user ID (70% anonymous, 30% logged in)."""
        if random.random() < 0.70:
            return None  # Anonymous
        else:
            return random.randint(1, self.num_users)

    def _select_device(self) -> str:
        """Select device type."""
        devices = list(self.devices.keys())
        probs = list(self.devices.values())
        return random.choices(devices, weights=probs)[0]

    def _select_browser(self) -> str:
        """Select browser."""
        browsers = list(self.browsers.keys())
        probs = list(self.browsers.values())
        return random.choices(browsers, weights=probs)[0]

    def _select_country(self) -> str:
        """Select country."""
        countries = list(self.countries.keys())
        probs = list(self.countries.values())
        return random.choices(countries, weights=probs)[0]

    def _select_referrer(self) -> str:
        """Select referrer source."""
        return random.choice(self.referrers)

    def _select_ab_variant(self) -> str:
        """Select A/B test variant (50/50 split)."""
        return "A" if random.random() < 0.5 else "B"

    def _generate_product_id(self, category: str) -> str:
        """Generate product ID for category."""
        product_num = random.randint(1, self.products_per_category)
        return f"{category[:4].upper()}{product_num:04d}"

    def _generate_product_price(self, category: str) -> float:
        """Generate realistic product price based on category."""
        price_ranges = {
            "electronics": (50, 2000),
            "clothing": (20, 200),
            "home": (30, 500),
            "sports": (25, 400),
            "books": (10, 50),
            "toys": (15, 150),
            "beauty": (15, 100),
            "automotive": (50, 500),
            "grocery": (5, 50),
            "jewelry": (100, 5000)
        }

        min_price, max_price = price_ranges.get(category, (10, 100))
        return round(random.uniform(min_price, max_price), 2)

    def _should_bounce(self, device: str) -> bool:
        """
        Determine if session should bounce (single page visit).

        Bounce rates:
        - Mobile: 60% (higher bounce)
        - Desktop: 40%
        - Tablet: 50%
        """
        bounce_rates = {
            "mobile": 0.60,
            "desktop": 0.40,
            "tablet": 0.50
        }
        return random.random() < bounce_rates.get(device, 0.50)

    def _should_convert(self, device: str, ab_variant: str) -> bool:
        """
        Determine if session converts to purchase.

        Conversion rates:
        - Desktop: 5% (baseline)
        - Mobile: 3%
        - Tablet: 4%
        - A/B variant B: +20% lift
        """
        conversion_rates = {
            "desktop": 0.05,
            "mobile": 0.03,
            "tablet": 0.04
        }

        base_rate = conversion_rates.get(device, 0.04)

        # A/B test effect
        if ab_variant == "B":
            base_rate *= 1.20  # 20% lift for variant B

        return random.random() < base_rate

    def _should_abandon_cart(self, device: str) -> bool:
        """
        Determine if user abandons cart.

        Abandonment rates:
        - Mobile: 80%
        - Desktop: 65%
        - Tablet: 70%
        """
        abandon_rates = {
            "mobile": 0.80,
            "desktop": 0.65,
            "tablet": 0.70
        }
        return random.random() < abandon_rates.get(device, 0.70)

    def _generate_session_events(self, current_time: datetime) -> List[ClickEvent]:
        """
        Generate all events for a single user session.

        Returns:
            List of ClickEvent objects
        """
        events = []

        # Initialize session
        user_id = self._generate_user_id()
        session_id = self._generate_session_id(user_id)
        device = self._select_device()
        browser = self._select_browser()
        country = self._select_country()
        referrer = self._select_referrer()
        ab_variant = self._select_ab_variant()

        session_time = current_time

        # Check if bounce
        if self._should_bounce(device):
            # Single page view (bounce)
            events.append(ClickEvent(
                time=session_time,
                session_id=session_id,
                user_id=user_id,
                event_type=EventType.PAGE_VIEW.value,
                page_type=PageType.HOME.value,
                page_url="/",
                product_id=None,
                category=None,
                price=None,
                quantity=0,
                ab_test_variant=ab_variant,
                referrer=referrer,
                device_type=device,
                browser=browser,
                country=country
            ))
            return events

        # Non-bounce session: Generate browsing flow
        # 1. Home page
        events.append(ClickEvent(
            time=session_time,
            session_id=session_id,
            user_id=user_id,
            event_type=EventType.PAGE_VIEW.value,
            page_type=PageType.HOME.value,
            page_url="/",
            product_id=None,
            category=None,
            price=None,
            quantity=0,
            ab_test_variant=ab_variant,
            referrer=referrer,
            device_type=device,
            browser=browser,
            country=country
        ))

        session_time += timedelta(seconds=random.randint(5, 30))

        # 2. Category browse (1-3 categories)
        num_categories = random.randint(1, 3)
        viewed_products = []

        for _ in range(num_categories):
            category = random.choice(self.categories)

            # Category page view
            events.append(ClickEvent(
                time=session_time,
                session_id=session_id,
                user_id=user_id,
                event_type=EventType.PAGE_VIEW.value,
                page_type=PageType.CATEGORY.value,
                page_url=f"/category/{category}",
                product_id=None,
                category=category,
                price=None,
                quantity=0,
                ab_test_variant=ab_variant,
                referrer=None,
                device_type=device,
                browser=browser,
                country=country
            ))

            session_time += timedelta(seconds=random.randint(10, 60))

            # View 2-5 products in category
            num_products = random.randint(2, 5)

            for _ in range(num_products):
                product_id = self._generate_product_id(category)
                price = self._generate_product_price(category)

                # Product page view
                events.append(ClickEvent(
                    time=session_time,
                    session_id=session_id,
                    user_id=user_id,
                    event_type=EventType.PRODUCT_VIEW.value,
                    page_type=PageType.PRODUCT.value,
                    page_url=f"/product/{product_id}",
                    product_id=product_id,
                    category=category,
                    price=price,
                    quantity=0,
                    ab_test_variant=ab_variant,
                    referrer=None,
                    device_type=device,
                    browser=browser,
                    country=country
                ))

                viewed_products.append((product_id, category, price))

                session_time += timedelta(seconds=random.randint(20, 120))

                # 30% chance to add to cart
                if random.random() < 0.30:
                    quantity = random.randint(1, 3)
                    events.append(ClickEvent(
                        time=session_time,
                        session_id=session_id,
                        user_id=user_id,
                        event_type=EventType.ADD_TO_CART.value,
                        page_type=PageType.PRODUCT.value,
                        page_url=f"/product/{product_id}",
                        product_id=product_id,
                        category=category,
                        price=price,
                        quantity=quantity,
                        ab_test_variant=ab_variant,
                        referrer=None,
                        device_type=device,
                        browser=browser,
                        country=country
                    ))

                    session_time += timedelta(seconds=random.randint(2, 10))

        # 3. Cart interaction (if items in cart)
        cart_events = [e for e in events if e.event_type == EventType.ADD_TO_CART.value]

        if cart_events:
            # View cart
            events.append(ClickEvent(
                time=session_time,
                session_id=session_id,
                user_id=user_id,
                event_type=EventType.PAGE_VIEW.value,
                page_type=PageType.CART.value,
                page_url="/cart",
                product_id=None,
                category=None,
                price=None,
                quantity=0,
                ab_test_variant=ab_variant,
                referrer=None,
                device_type=device,
                browser=browser,
                country=country
            ))

            session_time += timedelta(seconds=random.randint(10, 60))

            # Check if cart abandoned
            if self._should_abandon_cart(device):
                # Cart abandoned (session ends)
                return events

            # 4. Checkout flow (if not abandoned)
            # Start checkout
            events.append(ClickEvent(
                time=session_time,
                session_id=session_id,
                user_id=user_id,
                event_type=EventType.CHECKOUT_START.value,
                page_type=PageType.CHECKOUT.value,
                page_url="/checkout",
                product_id=None,
                category=None,
                price=None,
                quantity=0,
                ab_test_variant=ab_variant,
                referrer=None,
                device_type=device,
                browser=browser,
                country=country
            ))

            session_time += timedelta(seconds=random.randint(30, 120))

            # Check if converts
            if self._should_convert(device, ab_variant):
                # Calculate total order value
                total_value = sum(e.price * e.quantity for e in cart_events)

                # Complete checkout
                events.append(ClickEvent(
                    time=session_time,
                    session_id=session_id,
                    user_id=user_id,
                    event_type=EventType.CHECKOUT_COMPLETE.value,
                    page_type=PageType.CHECKOUT.value,
                    page_url="/checkout/complete",
                    product_id=None,
                    category=None,
                    price=total_value,
                    quantity=sum(e.quantity for e in cart_events),
                    ab_test_variant=ab_variant,
                    referrer=None,
                    device_type=device,
                    browser=browser,
                    country=country
                ))

        return events

    def generate_events(self, duration_seconds: int = 3600,
                       sessions_per_second: int = 1000) -> Iterator[ClickEvent]:
        """
        Generate clickstream event stream.

        Args:
            duration_seconds: How long to generate data for
            sessions_per_second: New sessions started per second

        Yields:
            ClickEvent objects
        """
        start_time = datetime.now()

        total_sessions = duration_seconds * sessions_per_second

        print(f"Generating ~{total_sessions:,} clickstream sessions...")
        print(f"  Duration: {duration_seconds}s ({duration_seconds/3600:.1f} hours)")
        print(f"  Sessions/sec: {sessions_per_second:,}")

        events_generated = 0
        sessions_generated = 0
        current_time = start_time

        # Generate sessions throughout duration
        for _ in range(duration_seconds):
            current_time += timedelta(seconds=1)

            # Generate sessions for this second (with variance)
            sessions_this_second = int(sessions_per_second * random.uniform(0.8, 1.2))

            for _ in range(sessions_this_second):
                # Generate all events for session
                session_events = self._generate_session_events(current_time)

                for event in session_events:
                    yield event
                    events_generated += 1

                sessions_generated += 1

                # Progress update
                if events_generated % 1_000_000 == 0:
                    print(f"  Generated {events_generated:,} events ({sessions_generated:,} sessions)...")

        print(f"✅ Generated {events_generated:,} events from {sessions_generated:,} sessions")
        print(f"   Avg {events_generated/sessions_generated:.1f} events per session")

    def generate_dataset(self, size: str = "small") -> List[ClickEvent]:
        """
        Generate complete dataset.

        Args:
            size: 'small' (1M rows), 'medium' (100M rows), 'large' (1B rows)

        Returns:
            List of ClickEvent objects
        """
        # Calculate parameters based on size
        # Avg ~10 events per session
        if size == "small":
            # 1M events ≈ 100K sessions at 1K sessions/sec = 100 seconds
            duration_seconds = 100
            sessions_per_second = 1000
        elif size == "medium":
            # 100M events ≈ 10M sessions
            duration_seconds = 10000
            sessions_per_second = 1000
        elif size == "large":
            # 1B events ≈ 100M sessions
            duration_seconds = 100000
            sessions_per_second = 1000
        else:
            raise ValueError(f"Unknown size: {size}")

        events = list(self.generate_events(
            duration_seconds=duration_seconds,
            sessions_per_second=sessions_per_second
        ))

        return events


def main():
    """Example usage and testing."""
    generator = ClickstreamDataGenerator(seed=42, num_users=10000)

    # Generate 60 seconds of data
    print("\nGenerating sample clickstream data...")
    events = list(generator.generate_events(duration_seconds=60, sessions_per_second=100))

    print(f"\n✅ Generated {len(events):,} events")
    print("\nSample events (first 20):")

    for i, event in enumerate(events[:20]):
        user = f"U{event.user_id:05d}" if event.user_id else "ANON "
        prod = f"[{event.product_id}]" if event.product_id else ""
        price = f"${event.price:.2f}" if event.price else ""

        print(f"  {i+1}. {event.time.strftime('%H:%M:%S')} | "
              f"{user} | {event.session_id[:15]:15s} | "
              f"{event.event_type:18s} | {event.page_type:15s} | "
              f"{event.device_type:7s} | {prod:12s} {price}")

    # Statistics
    from collections import Counter

    print("\nEvent Type Distribution:")
    event_counts = Counter(e.event_type for e in events)
    for event_type, count in event_counts.most_common():
        print(f"  {event_type:20s}: {count:5d} ({count/len(events)*100:5.1f}%)")

    print("\nPage Type Distribution:")
    page_counts = Counter(e.page_type for e in events)
    for page, count in page_counts.most_common():
        print(f"  {page:20s}: {count:5d} ({count/len(events)*100:5.1f}%)")

    print("\nDevice Distribution:")
    device_counts = Counter(e.device_type for e in events)
    for device, count in device_counts.most_common():
        print(f"  {device:10s}: {count:5d} ({count/len(events)*100:5.1f}%)")

    print("\nA/B Test Distribution:")
    ab_counts = Counter(e.ab_test_variant for e in events)
    for variant, count in ab_counts.most_common():
        print(f"  Variant {variant}: {count:5d} ({count/len(events)*100:5.1f}%)")

    print("\nConversion Analysis:")
    sessions = set(e.session_id for e in events)
    add_to_cart_sessions = set(e.session_id for e in events if e.event_type == "add_to_cart")
    checkout_start_sessions = set(e.session_id for e in events if e.event_type == "checkout_start")
    checkout_complete_sessions = set(e.session_id for e in events if e.event_type == "checkout_complete")

    print(f"  Total sessions: {len(sessions)}")
    print(f"  Sessions with cart adds: {len(add_to_cart_sessions)} ({len(add_to_cart_sessions)/len(sessions)*100:.1f}%)")
    print(f"  Sessions starting checkout: {len(checkout_start_sessions)} ({len(checkout_start_sessions)/len(sessions)*100:.1f}%)")
    print(f"  Sessions completing purchase: {len(checkout_complete_sessions)} ({len(checkout_complete_sessions)/len(sessions)*100:.1f}%)")

    if checkout_start_sessions:
        checkout_conversion = len(checkout_complete_sessions) / len(checkout_start_sessions) * 100
        print(f"  Checkout conversion rate: {checkout_conversion:.1f}%")

    if add_to_cart_sessions:
        cart_abandon_rate = (1 - len(checkout_start_sessions) / len(add_to_cart_sessions)) * 100
        print(f"  Cart abandonment rate: {cart_abandon_rate:.1f}%")

    print("\nBounce Rate Analysis:")
    single_event_sessions = [sid for sid in sessions if sum(1 for e in events if e.session_id == sid) == 1]
    bounce_rate = len(single_event_sessions) / len(sessions) * 100
    print(f"  Bounce rate: {bounce_rate:.1f}%")

    print("\nRevenue Analysis:")
    purchases = [e for e in events if e.event_type == "checkout_complete"]
    if purchases:
        total_revenue = sum(e.price for e in purchases if e.price)
        print(f"  Total revenue: ${total_revenue:,.2f}")
        print(f"  Avg order value: ${total_revenue/len(purchases):.2f}")


if __name__ == "__main__":
    main()
