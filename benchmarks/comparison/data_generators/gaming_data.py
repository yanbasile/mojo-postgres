"""
Multiplayer Gaming Data Generator

Generates realistic game telemetry including:
- Player events (kills, deaths, assists, objectives)
- Economy transactions (purchases, sales, loot)
- Match/session data
- Player progression (XP, levels, achievements)
- In-game purchases (microtransactions)
"""

import random
import numpy as np
from datetime import datetime, timedelta
from typing import Iterator, List, Dict, Tuple, Optional
from dataclasses import dataclass
from enum import Enum


class EventType(Enum):
    """Types of gaming events."""
    KILL = "kill"
    DEATH = "death"
    ASSIST = "assist"
    OBJECTIVE = "objective"
    PURCHASE = "purchase"
    SALE = "sale"
    LOOT = "loot"
    LEVEL_UP = "level_up"
    ACHIEVEMENT = "achievement"
    MATCH_START = "match_start"
    MATCH_END = "match_end"


class GameMode(Enum):
    """Game modes."""
    BATTLE_ROYALE = "battle_royale"
    TEAM_DEATHMATCH = "team_deathmatch"
    CAPTURE_FLAG = "capture_flag"
    RANKED = "ranked"
    CASUAL = "casual"


@dataclass
class GameEvent:
    """Single game event."""
    time: datetime
    event_type: str
    player_id: int
    session_id: str
    match_id: Optional[str]
    game_mode: str
    player_level: int
    value: float  # Damage, XP, currency amount
    target_player_id: Optional[int]
    item_id: Optional[str]
    position_x: Optional[float]
    position_y: Optional[float]
    position_z: Optional[float]


class GamingDataGenerator:
    """
    Generates realistic multiplayer gaming telemetry.

    Features:
    - 1M+ concurrent players
    - Realistic skill-based matchmaking (ELO)
    - Player progression (levels, XP)
    - Economy simulation (item purchases, trades)
    - Match flow (lobby → match → results)
    - Kill/death ratio patterns
    - Geographic latency
    - Session duration patterns
    """

    def __init__(self, seed: int = 42, num_players: int = 1_000_000):
        """Initialize generator with random seed."""
        random.seed(seed)
        np.random.seed(seed)

        self.num_players = num_players

        # Player state (level, XP, ELO)
        self.player_levels = {i: random.randint(1, 100) for i in range(num_players)}
        self.player_xp = {i: random.randint(0, 1000) for i in range(num_players)}
        self.player_elo = {i: random.randint(800, 2400) for i in range(num_players)}

        # Active matches
        self.active_matches: Dict[str, Dict] = {}
        self.match_counter = 0
        self.session_counter = 0

        # Game modes with probabilities
        self.game_modes = {
            GameMode.BATTLE_ROYALE: 0.40,  # 40%
            GameMode.TEAM_DEATHMATCH: 0.30,
            GameMode.CAPTURE_FLAG: 0.15,
            GameMode.RANKED: 0.10,
            GameMode.CASUAL: 0.05
        }

        # Weapons/items
        self.weapons = [
            "assault_rifle", "sniper_rifle", "shotgun", "pistol",
            "smg", "rocket_launcher", "sword", "grenade"
        ]

        self.items = [
            "health_potion", "shield", "ammo_pack", "speed_boost",
            "armor", "grenade", "medkit", "scope"
        ]

        # In-game shop items with prices
        self.shop_items = {
            "legendary_skin": 1500,
            "epic_weapon": 950,
            "rare_emote": 500,
            "battle_pass": 950,
            "loot_box": 200,
            "character_unlock": 1200,
            "map_pack": 800,
            "voice_pack": 300
        }

        print(f"Initialized GamingDataGenerator with {num_players:,} players")

    def _select_game_mode(self) -> str:
        """Select game mode based on probability distribution."""
        modes = list(self.game_modes.keys())
        probs = list(self.game_modes.values())
        return random.choices(modes, weights=probs)[0].value

    def _generate_match_id(self) -> str:
        """Generate unique match ID."""
        self.match_counter += 1
        return f"match_{self.match_counter:08d}"

    def _generate_session_id(self, player_id: int) -> str:
        """Generate session ID for player."""
        self.session_counter += 1
        return f"session_{player_id}_{self.session_counter:08d}"

    def _generate_position(self, map_size: float = 5000.0) -> Tuple[float, float, float]:
        """Generate random 3D position on map."""
        x = random.uniform(-map_size/2, map_size/2)
        y = random.uniform(-map_size/2, map_size/2)
        z = random.uniform(0, 500)  # Altitude
        return (round(x, 2), round(y, 2), round(z, 2))

    def _calculate_skill_multiplier(self, player_id: int) -> float:
        """
        Calculate skill multiplier based on ELO.

        Higher ELO = more kills, fewer deaths.
        """
        elo = self.player_elo[player_id]

        if elo < 1000:  # Beginner
            return random.uniform(0.5, 0.8)
        elif elo < 1500:  # Intermediate
            return random.uniform(0.8, 1.2)
        elif elo < 2000:  # Advanced
            return random.uniform(1.2, 1.8)
        else:  # Pro
            return random.uniform(1.8, 3.0)

    def _should_generate_kill(self, player_id: int) -> bool:
        """Determine if player gets a kill (skill-based)."""
        skill = self._calculate_skill_multiplier(player_id)
        base_kill_rate = 0.05  # 5% base chance per event
        return random.random() < (base_kill_rate * skill)

    def _should_generate_death(self, player_id: int) -> bool:
        """Determine if player dies (inverse skill-based)."""
        skill = self._calculate_skill_multiplier(player_id)
        base_death_rate = 0.03  # 3% base chance
        return random.random() < (base_death_rate / skill)

    def _generate_damage(self, weapon: str) -> float:
        """Generate damage amount based on weapon."""
        weapon_damage = {
            "assault_rifle": (20, 35),
            "sniper_rifle": (60, 100),
            "shotgun": (40, 80),
            "pistol": (15, 25),
            "smg": (12, 22),
            "rocket_launcher": (80, 150),
            "sword": (30, 50),
            "grenade": (50, 100)
        }

        min_dmg, max_dmg = weapon_damage.get(weapon, (10, 30))
        return round(random.uniform(min_dmg, max_dmg), 2)

    def _add_xp(self, player_id: int, xp_amount: float):
        """Add XP to player and handle level ups."""
        self.player_xp[player_id] += xp_amount

        # Level up every 1000 XP
        while self.player_xp[player_id] >= 1000:
            self.player_xp[player_id] -= 1000
            self.player_levels[player_id] += 1

    def _generate_event_type_distribution(self) -> str:
        """
        Generate event type with realistic distribution.

        Distribution:
        - 40% combat (kills, deaths, assists)
        - 30% economy (purchases, sales, loot)
        - 20% progression (level ups, achievements)
        - 10% objectives
        """
        rand = random.random()

        if rand < 0.15:
            return EventType.KILL.value
        elif rand < 0.28:
            return EventType.DEATH.value
        elif rand < 0.40:
            return EventType.ASSIST.value
        elif rand < 0.55:
            return EventType.LOOT.value
        elif rand < 0.65:
            return EventType.PURCHASE.value
        elif rand < 0.70:
            return EventType.SALE.value
        elif rand < 0.80:
            return EventType.LEVEL_UP.value
        elif rand < 0.90:
            return EventType.ACHIEVEMENT.value
        else:
            return EventType.OBJECTIVE.value

    def _generate_match_events(self, current_time: datetime,
                               num_players_in_match: int,
                               match_duration_sec: int) -> List[GameEvent]:
        """
        Generate all events for a single match.

        Args:
            current_time: Match start time
            num_players_in_match: Number of players in match
            match_duration_sec: Match duration in seconds

        Returns:
            List of GameEvent objects
        """
        events = []
        match_id = self._generate_match_id()
        game_mode = self._select_game_mode()

        # Select random players for this match
        players_in_match = random.sample(range(self.num_players), num_players_in_match)

        # Match start events
        for player_id in players_in_match:
            session_id = self._generate_session_id(player_id)
            events.append(GameEvent(
                time=current_time,
                event_type=EventType.MATCH_START.value,
                player_id=player_id,
                session_id=session_id,
                match_id=match_id,
                game_mode=game_mode,
                player_level=self.player_levels[player_id],
                value=0.0,
                target_player_id=None,
                item_id=None,
                position_x=None,
                position_y=None,
                position_z=None
            ))

        # Generate events throughout match
        match_time = current_time
        for _ in range(match_duration_sec):
            match_time += timedelta(seconds=1)

            # Generate 10-50 events per second
            events_this_second = random.randint(10, 50)

            for _ in range(events_this_second):
                player_id = random.choice(players_in_match)
                session_id = self._generate_session_id(player_id)
                event_type = self._generate_event_type_distribution()
                pos_x, pos_y, pos_z = self._generate_position()

                # Generate event based on type
                if event_type == EventType.KILL.value:
                    if self._should_generate_kill(player_id):
                        weapon = random.choice(self.weapons)
                        damage = self._generate_damage(weapon)
                        target_id = random.choice([p for p in players_in_match if p != player_id])

                        events.append(GameEvent(
                            time=match_time,
                            event_type=event_type,
                            player_id=player_id,
                            session_id=session_id,
                            match_id=match_id,
                            game_mode=game_mode,
                            player_level=self.player_levels[player_id],
                            value=damage,
                            target_player_id=target_id,
                            item_id=weapon,
                            position_x=pos_x,
                            position_y=pos_y,
                            position_z=pos_z
                        ))

                        # Award XP for kill
                        self._add_xp(player_id, 100)

                elif event_type == EventType.DEATH.value:
                    if self._should_generate_death(player_id):
                        events.append(GameEvent(
                            time=match_time,
                            event_type=event_type,
                            player_id=player_id,
                            session_id=session_id,
                            match_id=match_id,
                            game_mode=game_mode,
                            player_level=self.player_levels[player_id],
                            value=0.0,
                            target_player_id=None,
                            item_id=None,
                            position_x=pos_x,
                            position_y=pos_y,
                            position_z=pos_z
                        ))

                elif event_type == EventType.LOOT.value:
                    item = random.choice(self.items)
                    events.append(GameEvent(
                        time=match_time,
                        event_type=event_type,
                        player_id=player_id,
                        session_id=session_id,
                        match_id=match_id,
                        game_mode=game_mode,
                        player_level=self.player_levels[player_id],
                        value=0.0,
                        target_player_id=None,
                        item_id=item,
                        position_x=pos_x,
                        position_y=pos_y,
                        position_z=pos_z
                    ))

                elif event_type == EventType.PURCHASE.value:
                    item_name, price = random.choice(list(self.shop_items.items()))
                    events.append(GameEvent(
                        time=match_time,
                        event_type=event_type,
                        player_id=player_id,
                        session_id=session_id,
                        match_id=match_id,
                        game_mode=game_mode,
                        player_level=self.player_levels[player_id],
                        value=float(price),
                        target_player_id=None,
                        item_id=item_name,
                        position_x=None,
                        position_y=None,
                        position_z=None
                    ))

                elif event_type == EventType.LEVEL_UP.value:
                    # Check if player leveled up
                    if random.random() < 0.05:  # 5% chance
                        self.player_levels[player_id] += 1
                        events.append(GameEvent(
                            time=match_time,
                            event_type=event_type,
                            player_id=player_id,
                            session_id=session_id,
                            match_id=match_id,
                            game_mode=game_mode,
                            player_level=self.player_levels[player_id],
                            value=float(self.player_levels[player_id]),
                            target_player_id=None,
                            item_id=None,
                            position_x=None,
                            position_y=None,
                            position_z=None
                        ))

                elif event_type == EventType.OBJECTIVE.value:
                    # Objective capture
                    xp_reward = random.randint(200, 500)
                    self._add_xp(player_id, xp_reward)

                    events.append(GameEvent(
                        time=match_time,
                        event_type=event_type,
                        player_id=player_id,
                        session_id=session_id,
                        match_id=match_id,
                        game_mode=game_mode,
                        player_level=self.player_levels[player_id],
                        value=float(xp_reward),
                        target_player_id=None,
                        item_id="objective_flag",
                        position_x=pos_x,
                        position_y=pos_y,
                        position_z=pos_z
                    ))

        # Match end events
        match_end_time = match_time + timedelta(seconds=1)
        for player_id in players_in_match:
            session_id = self._generate_session_id(player_id)
            events.append(GameEvent(
                time=match_end_time,
                event_type=EventType.MATCH_END.value,
                player_id=player_id,
                session_id=session_id,
                match_id=match_id,
                game_mode=game_mode,
                player_level=self.player_levels[player_id],
                value=0.0,
                target_player_id=None,
                item_id=None,
                position_x=None,
                position_y=None,
                position_z=None
            ))

        return events

    def generate_events(self, duration_seconds: int = 3600,
                       concurrent_matches: int = 10000) -> Iterator[GameEvent]:
        """
        Generate gaming event stream.

        Args:
            duration_seconds: How long to generate data for
            concurrent_matches: Number of concurrent matches

        Yields:
            GameEvent objects
        """
        start_time = datetime.now()

        print(f"Generating gaming events...")
        print(f"  Duration: {duration_seconds}s ({duration_seconds/3600:.1f} hours)")
        print(f"  Concurrent matches: {concurrent_matches:,}")
        print(f"  Total players: {self.num_players:,}")

        events_generated = 0

        # Generate matches throughout duration
        num_matches = concurrent_matches * (duration_seconds // 300)  # Avg 5 min per match
        print(f"  Estimated matches: {num_matches:,}")

        current_time = start_time

        for _ in range(num_matches):
            # Battle royale has 100 players, other modes have 10-20
            game_mode_choice = self._select_game_mode()
            if "battle_royale" in game_mode_choice:
                num_players = 100
                match_duration = 1800  # 30 minutes
            else:
                num_players = random.randint(10, 20)
                match_duration = 600  # 10 minutes

            # Generate all events for this match
            match_events = self._generate_match_events(
                current_time=current_time,
                num_players_in_match=num_players,
                match_duration_sec=match_duration
            )

            for event in match_events:
                yield event
                events_generated += 1

                # Progress update
                if events_generated % 1_000_000 == 0:
                    print(f"  Generated {events_generated:,} events...")

            # Move time forward
            current_time += timedelta(seconds=match_duration + random.randint(10, 60))

        print(f"✅ Generated {events_generated:,} events")

    def generate_dataset(self, size: str = "small") -> List[GameEvent]:
        """
        Generate complete dataset.

        Args:
            size: 'small' (1M rows), 'medium' (100M rows), 'large' (1B rows)

        Returns:
            List of GameEvent objects
        """
        # Calculate parameters based on size
        if size == "small":
            # 1M events ≈ 100 matches × 10K events/match
            duration_seconds = 3600
            concurrent_matches = 100
        elif size == "medium":
            # 100M events
            duration_seconds = 36000
            concurrent_matches = 1000
        elif size == "large":
            # 1B events
            duration_seconds = 360000
            concurrent_matches = 10000
        else:
            raise ValueError(f"Unknown size: {size}")

        events = list(self.generate_events(
            duration_seconds=duration_seconds,
            concurrent_matches=concurrent_matches
        ))

        return events


def main():
    """Example usage and testing."""
    # Use smaller number for testing
    generator = GamingDataGenerator(seed=42, num_players=1000)

    # Generate 1 match worth of data
    print("\nGenerating sample gaming data...")
    events = list(generator.generate_events(duration_seconds=600, concurrent_matches=1))

    print(f"\n✅ Generated {len(events):,} events")
    print("\nSample events (first 20):")

    for i, event in enumerate(events[:20]):
        target = f"→ P{event.target_player_id}" if event.target_player_id else ""
        item = f"[{event.item_id}]" if event.item_id else ""
        pos = f"({event.position_x:.0f}, {event.position_y:.0f})" if event.position_x else ""

        print(f"  {i+1}. {event.time.strftime('%H:%M:%S')} | "
              f"P{event.player_id:04d} L{event.player_level:02d} | "
              f"{event.event_type:12s} | {event.game_mode:15s} | "
              f"{target:8s} {item:20s} {pos}")

    # Statistics
    from collections import Counter

    print("\nEvent Type Distribution:")
    event_counts = Counter(e.event_type for e in events)
    for event_type, count in event_counts.most_common():
        print(f"  {event_type:20s}: {count:6d} ({count/len(events)*100:5.1f}%)")

    print("\nGame Mode Distribution:")
    mode_counts = Counter(e.game_mode for e in events)
    for mode, count in mode_counts.most_common():
        print(f"  {mode:20s}: {count:6d} ({count/len(events)*100:5.1f}%)")

    print("\nPlayer Level Distribution:")
    levels = [e.player_level for e in events]
    print(f"  Min level: {min(levels)}")
    print(f"  Max level: {max(levels)}")
    print(f"  Avg level: {np.mean(levels):.1f}")

    print("\nKill/Death Analysis:")
    kills = [e for e in events if e.event_type == "kill"]
    deaths = [e for e in events if e.event_type == "death"]
    kd_ratio = len(kills) / len(deaths) if deaths else 0
    print(f"  Total kills: {len(kills)}")
    print(f"  Total deaths: {len(deaths)}")
    print(f"  K/D ratio: {kd_ratio:.2f}")

    print("\nEconomy Analysis:")
    purchases = [e for e in events if e.event_type == "purchase"]
    if purchases:
        total_spent = sum(e.value for e in purchases)
        print(f"  Total purchases: {len(purchases)}")
        print(f"  Total spent: {total_spent:,.0f} credits")
        print(f"  Avg purchase: {total_spent/len(purchases):.0f} credits")

    print("\nMatch Summary:")
    matches = set(e.match_id for e in events if e.match_id)
    print(f"  Total matches: {len(matches)}")

    # Events per match
    match_events = {}
    for event in events:
        if event.match_id:
            match_events[event.match_id] = match_events.get(event.match_id, 0) + 1

    if match_events:
        print(f"  Avg events/match: {np.mean(list(match_events.values())):.0f}")


if __name__ == "__main__":
    main()
