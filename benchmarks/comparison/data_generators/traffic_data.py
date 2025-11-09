"""
Smart City Traffic Data Generator

Generates realistic traffic sensor data for urban traffic management:
- Traffic sensors at intersections
- Vehicle counts and speeds
- Congestion patterns
- Rush hour simulation
- Incidents (accidents, construction)
- Traffic flow optimization
"""

import random
import numpy as np
from datetime import datetime, timedelta
from typing import Iterator, List, Dict, Tuple, Optional
from dataclasses import dataclass
from enum import Enum


class IncidentType(Enum):
    """Types of traffic incidents."""
    NONE = "none"
    ACCIDENT = "accident"
    CONSTRUCTION = "construction"
    ROAD_CLOSURE = "road_closure"
    WEATHER = "weather"
    EVENT = "event"


@dataclass
class TrafficReading:
    """Single traffic sensor reading."""
    time: datetime
    sensor_id: int
    intersection_name: str
    latitude: float
    longitude: float
    vehicle_count: int  # Vehicles per minute
    avg_speed: float  # mph
    congestion_level: int  # 0-10 scale
    incident_type: str
    incident_severity: int  # 0-10 scale
    traffic_light_cycle: int  # seconds
    queue_length: int  # vehicles waiting


class TrafficDataGenerator:
    """
    Generates realistic smart city traffic data.

    Features:
    - 10,000+ traffic sensors at major intersections
    - Realistic rush hour patterns (7-9am, 5-7pm)
    - Weekend vs weekday patterns
    - Incident simulation (accidents, construction)
    - Congestion propagation (spillover to nearby intersections)
    - Traffic light optimization simulation
    - Weather impact on traffic
    - Special event traffic (concerts, sports)
    """

    def __init__(self, seed: int = 42, num_sensors: int = 10000):
        """Initialize generator with random seed."""
        random.seed(seed)
        np.random.seed(seed)

        self.num_sensors = num_sensors

        # City bounds (approximate NYC)
        self.lat_min, self.lat_max = 40.5, 40.9
        self.lon_min, self.lon_max = -74.3, -73.7

        # Generate sensor locations (grid layout with some randomness)
        self.sensors = self._generate_sensors()

        # Track active incidents
        self.active_incidents: Dict[int, Dict] = {}

        # Traffic network (adjacency for congestion propagation)
        self.sensor_neighbors = self._generate_sensor_network()

        print(f"Initialized TrafficDataGenerator with {num_sensors:,} sensors")

    def _generate_sensors(self) -> List[Dict]:
        """Generate sensor metadata (location, intersection name)."""
        sensors = []

        # Generate grid of intersections
        lat_step = (self.lat_max - self.lat_min) / int(np.sqrt(self.num_sensors))
        lon_step = (self.lon_max - self.lon_min) / int(np.sqrt(self.num_sensors))

        sensor_id = 0
        current_lat = self.lat_min

        while current_lat < self.lat_max and sensor_id < self.num_sensors:
            current_lon = self.lon_min

            while current_lon < self.lon_max and sensor_id < self.num_sensors:
                # Add some randomness to grid
                lat = current_lat + random.uniform(-lat_step * 0.3, lat_step * 0.3)
                lon = current_lon + random.uniform(-lon_step * 0.3, lon_step * 0.3)

                # Generate street names
                streets = [
                    "Broadway", "Main St", "1st Ave", "2nd Ave", "Park Ave",
                    "Madison Ave", "5th Ave", "Lexington Ave", "Broadway",
                    "Amsterdam Ave", "Columbus Ave", "Central Park West"
                ]
                cross_streets = [
                    f"{random.randint(1, 200)}th St",
                    f"{random.randint(1, 200)}th St",
                    f"{random.choice(streets)}"
                ]

                street1 = random.choice(streets)
                street2 = random.choice(cross_streets)
                intersection_name = f"{street1} & {street2}"

                sensors.append({
                    "id": sensor_id,
                    "intersection": intersection_name,
                    "lat": lat,
                    "lon": lon
                })

                sensor_id += 1
                current_lon += lon_step

            current_lat += lat_step

        print(f"Generated {len(sensors)} traffic sensors")
        return sensors

    def _generate_sensor_network(self) -> Dict[int, List[int]]:
        """
        Generate sensor network for congestion propagation.

        Each sensor has 2-4 neighboring sensors (adjacent intersections).
        """
        neighbors = {}

        for sensor in self.sensors:
            # Find 2-4 nearest neighbors
            distances = []
            for other in self.sensors:
                if sensor["id"] != other["id"]:
                    dist = np.sqrt(
                        (sensor["lat"] - other["lat"]) ** 2 +
                        (sensor["lon"] - other["lon"]) ** 2
                    )
                    distances.append((other["id"], dist))

            # Sort by distance and take 2-4 nearest
            distances.sort(key=lambda x: x[1])
            num_neighbors = random.randint(2, 4)
            neighbors[sensor["id"]] = [d[0] for d in distances[:num_neighbors]]

        return neighbors

    def _get_time_of_day_multiplier(self, current_time: datetime) -> float:
        """
        Calculate traffic multiplier based on time of day.

        Returns higher multiplier during rush hours.
        """
        hour = current_time.hour
        day_of_week = current_time.weekday()  # 0=Monday, 6=Sunday

        # Weekend pattern (lighter traffic)
        if day_of_week >= 5:  # Saturday or Sunday
            if 10 <= hour < 14:  # Lunch/shopping hours
                return random.uniform(1.5, 2.0)
            elif 18 <= hour < 21:  # Evening entertainment
                return random.uniform(1.3, 1.7)
            else:
                return random.uniform(0.5, 0.8)

        # Weekday pattern
        if 7 <= hour < 9:  # Morning rush
            return random.uniform(3.0, 5.0)
        elif 9 <= hour < 16:  # Mid-day
            return random.uniform(1.0, 1.5)
        elif 16 <= hour < 19:  # Evening rush
            return random.uniform(3.5, 5.5)  # Slightly worse than morning
        elif 0 <= hour < 6:  # Late night
            return random.uniform(0.2, 0.5)
        else:
            return random.uniform(0.7, 1.2)

    def _generate_incident(self, sensor_id: int, current_time: datetime) -> Tuple[str, int]:
        """
        Generate random traffic incident.

        Returns:
            (incident_type, severity)

        Incident rates:
        - None: 98%
        - Accident: 1.5%
        - Construction: 0.3%
        - Road closure: 0.1%
        - Weather: 0.1%
        """
        # Check if sensor already has active incident
        if sensor_id in self.active_incidents:
            incident = self.active_incidents[sensor_id]
            # Check if incident expired
            if current_time > incident["end_time"]:
                del self.active_incidents[sensor_id]
                return (IncidentType.NONE.value, 0)
            else:
                return (incident["type"], incident["severity"])

        # Generate new incident
        rand = random.random()

        if rand < 0.98:
            return (IncidentType.NONE.value, 0)
        elif rand < 0.995:
            # Accident (lasts 30-120 minutes)
            incident_type = IncidentType.ACCIDENT.value
            severity = random.randint(3, 8)
            duration_min = random.randint(30, 120)
        elif rand < 0.998:
            # Construction (lasts 2-8 hours)
            incident_type = IncidentType.CONSTRUCTION.value
            severity = random.randint(5, 9)
            duration_min = random.randint(120, 480)
        elif rand < 0.999:
            # Road closure (lasts 1-4 hours)
            incident_type = IncidentType.ROAD_CLOSURE.value
            severity = 10
            duration_min = random.randint(60, 240)
        else:
            # Weather (lasts 1-3 hours)
            incident_type = IncidentType.WEATHER.value
            severity = random.randint(4, 7)
            duration_min = random.randint(60, 180)

        # Store incident
        self.active_incidents[sensor_id] = {
            "type": incident_type,
            "severity": severity,
            "end_time": current_time + timedelta(minutes=duration_min)
        }

        return (incident_type, severity)

    def _calculate_congestion(self, vehicle_count: int, avg_speed: float,
                             incident_severity: int, nearby_congestion: float = 0.0) -> int:
        """
        Calculate congestion level (0-10 scale).

        Factors:
        - Vehicle count (higher = more congestion)
        - Average speed (lower = more congestion)
        - Active incidents (higher severity = more congestion)
        - Nearby congestion (spillover effect)
        """
        # Base congestion from vehicle count
        # Assume capacity of 60 vehicles/min
        congestion = min(vehicle_count / 60.0, 1.0) * 5.0

        # Speed factor (lower speed = higher congestion)
        # Normal speed: 25-35 mph, congested: 5-15 mph
        if avg_speed < 10:
            congestion += 3.0
        elif avg_speed < 20:
            congestion += 1.5

        # Incident impact
        congestion += incident_severity * 0.3

        # Nearby congestion spillover
        congestion += nearby_congestion * 0.2

        # Clamp to 0-10
        return int(max(min(congestion, 10), 0))

    def _calculate_queue_length(self, vehicle_count: int, congestion_level: int) -> int:
        """Calculate queue length at intersection based on congestion."""
        if congestion_level < 3:
            return random.randint(0, 5)
        elif congestion_level < 6:
            return random.randint(5, 15)
        elif congestion_level < 8:
            return random.randint(15, 30)
        else:
            return random.randint(30, 100)

    def _generate_vehicle_count(self, sensor: Dict, current_time: datetime,
                               incident_severity: int) -> int:
        """
        Generate vehicle count per minute.

        Args:
            sensor: Sensor metadata
            current_time: Current timestamp
            incident_severity: Incident severity (0-10)

        Returns:
            Vehicle count per minute
        """
        # Base count (average 30 vehicles/min)
        base_count = 30

        # Time of day multiplier
        time_mult = self._get_time_of_day_multiplier(current_time)

        # Random variation
        variation = random.uniform(0.7, 1.3)

        # Calculate count
        count = int(base_count * time_mult * variation)

        # Incident impact (reduces throughput)
        if incident_severity > 0:
            reduction = incident_severity / 10.0
            count = int(count * (1 - reduction * 0.7))

        return max(count, 0)

    def _generate_avg_speed(self, vehicle_count: int, incident_severity: int,
                           congestion_level: int) -> float:
        """
        Generate average speed (mph).

        Speed decreases with:
        - Higher vehicle count
        - Active incidents
        - Higher congestion
        """
        # Base speed (free flow: 30-35 mph)
        base_speed = random.uniform(28, 35)

        # Vehicle count impact
        if vehicle_count > 60:
            base_speed *= 0.4  # Heavy traffic
        elif vehicle_count > 40:
            base_speed *= 0.6  # Moderate traffic
        elif vehicle_count > 20:
            base_speed *= 0.8  # Light traffic

        # Incident impact
        if incident_severity > 0:
            base_speed *= (1 - incident_severity / 10.0 * 0.6)

        # Congestion impact
        if congestion_level > 7:
            base_speed *= 0.3
        elif congestion_level > 5:
            base_speed *= 0.5

        return round(max(base_speed, 2.0), 1)

    def _optimize_traffic_light_cycle(self, vehicle_count: int, congestion_level: int) -> int:
        """
        Calculate optimal traffic light cycle (seconds).

        Adaptive traffic lights adjust cycle based on traffic volume.
        """
        # Base cycle: 60 seconds
        base_cycle = 60

        # Increase cycle for high traffic
        if congestion_level > 7:
            return random.randint(90, 120)
        elif congestion_level > 5:
            return random.randint(75, 90)
        elif vehicle_count > 40:
            return random.randint(60, 75)
        else:
            return random.randint(45, 60)

    def generate_readings(self, duration_seconds: int = 3600,
                         reading_frequency_sec: int = 60) -> Iterator[TrafficReading]:
        """
        Generate traffic sensor reading stream.

        Args:
            duration_seconds: How long to generate data for
            reading_frequency_sec: How often each sensor reports (default: 60 sec)

        Yields:
            TrafficReading objects
        """
        start_time = datetime.now()
        current_time = start_time

        # Calculate total readings
        num_intervals = duration_seconds // reading_frequency_sec
        total_readings = len(self.sensors) * num_intervals

        print(f"Generating {total_readings:,} traffic readings...")
        print(f"  Duration: {duration_seconds}s ({duration_seconds/3600:.1f} hours)")
        print(f"  Sensors: {len(self.sensors):,}")
        print(f"  Frequency: {reading_frequency_sec}s")
        print(f"  Readings/min: {len(self.sensors)}")

        readings_generated = 0

        # Track congestion for spillover calculation
        current_congestion = {s["id"]: 0 for s in self.sensors}

        for _ in range(num_intervals):
            current_time += timedelta(seconds=reading_frequency_sec)

            # Generate reading for each sensor
            for sensor in self.sensors:
                sensor_id = sensor["id"]

                # Generate incident
                incident_type, incident_severity = self._generate_incident(sensor_id, current_time)

                # Calculate nearby congestion (average of neighbors)
                neighbor_ids = self.sensor_neighbors.get(sensor_id, [])
                nearby_congestion = np.mean([current_congestion[nid] for nid in neighbor_ids]) if neighbor_ids else 0

                # Generate vehicle count
                vehicle_count = self._generate_vehicle_count(sensor, current_time, incident_severity)

                # Calculate congestion (preliminary)
                congestion_level = self._calculate_congestion(
                    vehicle_count, 25.0, incident_severity, nearby_congestion
                )

                # Generate speed based on congestion
                avg_speed = self._generate_avg_speed(vehicle_count, incident_severity, congestion_level)

                # Recalculate congestion with actual speed
                congestion_level = self._calculate_congestion(
                    vehicle_count, avg_speed, incident_severity, nearby_congestion
                )

                # Update current congestion for spillover
                current_congestion[sensor_id] = congestion_level

                # Calculate queue length
                queue_length = self._calculate_queue_length(vehicle_count, congestion_level)

                # Optimize traffic light cycle
                traffic_light_cycle = self._optimize_traffic_light_cycle(vehicle_count, congestion_level)

                yield TrafficReading(
                    time=current_time,
                    sensor_id=sensor_id,
                    intersection_name=sensor["intersection"],
                    latitude=sensor["lat"],
                    longitude=sensor["lon"],
                    vehicle_count=vehicle_count,
                    avg_speed=avg_speed,
                    congestion_level=congestion_level,
                    incident_type=incident_type,
                    incident_severity=incident_severity,
                    traffic_light_cycle=traffic_light_cycle,
                    queue_length=queue_length
                )

                readings_generated += 1

            # Progress update
            if readings_generated % 1_000_000 == 0:
                print(f"  Generated {readings_generated:,} readings...")

        print(f"✅ Generated {readings_generated:,} readings")

    def generate_dataset(self, size: str = "small") -> List[TrafficReading]:
        """
        Generate complete dataset.

        Args:
            size: 'small' (1M rows), 'medium' (100M rows), 'large' (1B rows)

        Returns:
            List of TrafficReading objects
        """
        # Calculate parameters based on size
        if size == "small":
            # 1M readings with 10K sensors = 100 readings/sensor = 100 minutes
            duration_seconds = 6000
            reading_frequency_sec = 60
        elif size == "medium":
            # 100M readings
            duration_seconds = 600000
            reading_frequency_sec = 60
        elif size == "large":
            # 1B readings
            duration_seconds = 6000000
            reading_frequency_sec = 60
        else:
            raise ValueError(f"Unknown size: {size}")

        readings = list(self.generate_readings(
            duration_seconds=duration_seconds,
            reading_frequency_sec=reading_frequency_sec
        ))

        return readings


def main():
    """Example usage and testing."""
    # Use smaller number for testing
    generator = TrafficDataGenerator(seed=42, num_sensors=100)

    # Generate 1 hour of data
    print("\nGenerating sample traffic data...")
    readings = list(generator.generate_readings(duration_seconds=3600, reading_frequency_sec=60))

    print(f"\n✅ Generated {len(readings):,} readings")
    print("\nSample readings (first 20):")

    for i, reading in enumerate(readings[:20]):
        incident = f"[{reading.incident_type}]" if reading.incident_type != "none" else ""
        print(f"  {i+1}. {reading.time.strftime('%H:%M:%S')} | "
              f"S{reading.sensor_id:04d} | {reading.intersection_name[:25]:25s} | "
              f"{reading.vehicle_count:3d} veh/min | {reading.avg_speed:5.1f} mph | "
              f"Cong:{reading.congestion_level:2d} | Q:{reading.queue_length:3d} | {incident}")

    # Statistics
    print("\nTraffic Statistics:")
    print(f"  Avg vehicle count: {np.mean([r.vehicle_count for r in readings]):.1f} veh/min")
    print(f"  Avg speed: {np.mean([r.avg_speed for r in readings]):.1f} mph")
    print(f"  Avg congestion: {np.mean([r.congestion_level for r in readings]):.1f}/10")
    print(f"  Avg queue length: {np.mean([r.queue_length for r in readings]):.1f} vehicles")

    print("\nCongestion Distribution:")
    from collections import Counter
    congestion_counts = Counter(r.congestion_level for r in readings)
    for level in sorted(congestion_counts.keys()):
        count = congestion_counts[level]
        bar = "█" * int(count / len(readings) * 50)
        print(f"  Level {level:2d}: {count:5d} ({count/len(readings)*100:5.1f}%) {bar}")

    print("\nIncident Analysis:")
    incidents = [r for r in readings if r.incident_type != "none"]
    if incidents:
        incident_counts = Counter(r.incident_type for r in incidents)
        print(f"  Total incidents: {len(incidents)} ({len(incidents)/len(readings)*100:.2f}%)")
        for incident_type, count in incident_counts.most_common():
            print(f"    {incident_type:15s}: {count:5d}")

        print(f"  Avg incident severity: {np.mean([r.incident_severity for r in incidents]):.1f}/10")

    print("\nSpeed Distribution:")
    speeds = [r.avg_speed for r in readings]
    print(f"  Min: {min(speeds):.1f} mph")
    print(f"  p25: {np.percentile(speeds, 25):.1f} mph")
    print(f"  p50: {np.percentile(speeds, 50):.1f} mph")
    print(f"  p75: {np.percentile(speeds, 75):.1f} mph")
    print(f"  Max: {max(speeds):.1f} mph")

    print("\nTraffic Light Optimization:")
    cycles = [r.traffic_light_cycle for r in readings]
    print(f"  Avg cycle: {np.mean(cycles):.1f} seconds")
    print(f"  Min cycle: {min(cycles)} seconds")
    print(f"  Max cycle: {max(cycles)} seconds")


if __name__ == "__main__":
    main()
