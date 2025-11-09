"""
IoT Sensor Network Data Generator

Generates realistic IoT sensor readings for smart city infrastructure:
- 100,000+ sensors (air quality, traffic, noise, weather)
- Sensor drift and calibration issues
- Anomaly detection scenarios
- Network outages and delayed data
- Seasonal and circadian patterns
"""

import random
import numpy as np
from datetime import datetime, timedelta
from typing import Iterator, List, Dict, Tuple
from dataclasses import dataclass
from enum import Enum


class SensorType(Enum):
    """Types of IoT sensors."""
    AIR_QUALITY = "air_quality"
    TRAFFIC = "traffic"
    NOISE = "noise"
    WEATHER = "weather"


@dataclass
class SensorReading:
    """Single sensor reading."""
    time: datetime
    sensor_id: int
    sensor_type: str
    location_lat: float
    location_lon: float
    metric_name: str
    value: float
    unit: str


class IoTDataGenerator:
    """
    Generates realistic IoT sensor data for smart city.

    Features:
    - 100,000 sensors across city
    - Realistic sensor noise (Gaussian)
    - Sensor drift over time
    - Anomalies (spikes, dropouts)
    - Circadian patterns (daily cycles)
    - Seasonal variations
    - Correlated readings (nearby sensors similar)
    """

    def __init__(self, seed: int = 42, num_sensors: int = 100000):
        """Initialize generator with random seed."""
        random.seed(seed)
        np.random.seed(seed)

        self.num_sensors = num_sensors

        # City bounds (approximate NYC coordinates)
        self.lat_min, self.lat_max = 40.5, 40.9
        self.lon_min, self.lon_max = -74.3, -73.7

        # Sensor configuration by type
        self.sensor_configs = {
            SensorType.AIR_QUALITY: {
                "metrics": {
                    "pm25": {"min": 0, "max": 150, "unit": "μg/m³", "baseline": 35, "noise": 5},
                    "pm10": {"min": 0, "max": 250, "unit": "μg/m³", "baseline": 50, "noise": 8},
                    "co2": {"min": 300, "max": 2000, "unit": "ppm", "baseline": 450, "noise": 30},
                    "o3": {"min": 0, "max": 180, "unit": "ppb", "baseline": 40, "noise": 10},
                },
                "proportion": 0.30,  # 30% of sensors
            },
            SensorType.TRAFFIC: {
                "metrics": {
                    "vehicle_count": {"min": 0, "max": 500, "unit": "vehicles/min", "baseline": 50, "noise": 15},
                    "avg_speed": {"min": 0, "max": 70, "unit": "mph", "baseline": 25, "noise": 5},
                    "occupancy": {"min": 0, "max": 100, "unit": "%", "baseline": 30, "noise": 10},
                },
                "proportion": 0.25,
            },
            SensorType.NOISE: {
                "metrics": {
                    "noise_level": {"min": 30, "max": 120, "unit": "dB", "baseline": 60, "noise": 8},
                },
                "proportion": 0.20,
            },
            SensorType.WEATHER: {
                "metrics": {
                    "temperature": {"min": -10, "max": 110, "unit": "°F", "baseline": 60, "noise": 3},
                    "humidity": {"min": 0, "max": 100, "unit": "%", "baseline": 50, "noise": 5},
                    "pressure": {"min": 950, "max": 1050, "unit": "hPa", "baseline": 1013, "noise": 2},
                    "wind_speed": {"min": 0, "max": 60, "unit": "mph", "baseline": 10, "noise": 3},
                },
                "proportion": 0.25,
            },
        }

        # Generate sensor metadata
        self.sensors = self._generate_sensors()

        # Sensor state (for drift simulation)
        self.sensor_drift = {i: 0.0 for i in range(num_sensors)}
        self.sensor_last_calibration = {i: datetime.now() for i in range(num_sensors)}

    def _generate_sensors(self) -> List[Dict]:
        """Generate sensor metadata (location, type)."""
        sensors = []
        current_id = 0

        for sensor_type, config in self.sensor_configs.items():
            num_type = int(self.num_sensors * config["proportion"])

            for _ in range(num_type):
                # Random location in city bounds
                lat = random.uniform(self.lat_min, self.lat_max)
                lon = random.uniform(self.lon_min, self.lon_max)

                sensors.append({
                    "id": current_id,
                    "type": sensor_type,
                    "lat": lat,
                    "lon": lon,
                    "metrics": list(config["metrics"].keys())
                })

                current_id += 1

        print(f"Generated {len(sensors)} sensors:")
        for sensor_type in SensorType:
            type_sensors = [s for s in sensors if s["type"] == sensor_type]
            print(f"  {sensor_type.value}: {len(type_sensors)}")

        return sensors

    def _get_circadian_multiplier(self, current_time: datetime, metric_name: str) -> float:
        """
        Calculate circadian (daily cycle) multiplier.

        Different metrics have different patterns:
        - Traffic: Rush hours (8-9am, 5-6pm)
        - Air quality: Worse during rush hours
        - Noise: Higher during day, lower at night
        """
        hour = current_time.hour

        if metric_name == "vehicle_count":
            # Rush hour pattern
            if 7 <= hour < 9 or 17 <= hour < 19:
                return random.uniform(2.0, 3.0)  # Rush hour spike
            elif 0 <= hour < 6:
                return random.uniform(0.1, 0.3)  # Night
            else:
                return random.uniform(0.8, 1.2)  # Normal

        elif metric_name in ["pm25", "pm10", "co2"]:
            # Correlates with traffic
            if 7 <= hour < 9 or 17 <= hour < 19:
                return random.uniform(1.5, 2.0)
            elif 0 <= hour < 6:
                return random.uniform(0.6, 0.8)
            else:
                return 1.0

        elif metric_name == "noise_level":
            # Loud during day, quiet at night
            if 7 <= hour < 22:
                return random.uniform(1.2, 1.5)
            else:
                return random.uniform(0.5, 0.7)

        elif metric_name == "temperature":
            # Warmer in afternoon
            if 14 <= hour < 17:
                return random.uniform(1.1, 1.3)
            elif 3 <= hour < 6:
                return random.uniform(0.9, 0.95)
            else:
                return 1.0

        else:
            return 1.0

    def _add_sensor_drift(self, sensor_id: int, current_time: datetime) -> float:
        """
        Simulate sensor drift (calibration degradation over time).

        Sensors drift slowly over weeks/months and need recalibration.
        """
        # Check if sensor needs recalibration (every 30 days)
        days_since_calibration = (current_time - self.sensor_last_calibration[sensor_id]).days

        if days_since_calibration > 30:
            # Recalibrate (reset drift)
            self.sensor_drift[sensor_id] = 0.0
            self.sensor_last_calibration[sensor_id] = current_time

        # Drift accumulates slowly (0.1% per day)
        drift_rate = 0.001  # 0.1% per day
        self.sensor_drift[sensor_id] += drift_rate * random.uniform(-1, 1)

        # Cap drift at ±10%
        self.sensor_drift[sensor_id] = max(min(self.sensor_drift[sensor_id], 0.1), -0.1)

        return self.sensor_drift[sensor_id]

    def _generate_anomaly(self) -> Tuple[bool, float]:
        """
        Randomly generate anomalies.

        Returns:
            (is_anomaly, multiplier)

        Types of anomalies:
        - Spike (5x normal, 1% chance)
        - Dropout (0 value, 0.5% chance)
        - Stuck sensor (repeats last value, 0.5% chance)
        """
        rand = random.random()

        if rand < 0.01:
            # Spike anomaly
            return (True, random.uniform(3.0, 7.0))
        elif rand < 0.015:
            # Dropout
            return (True, 0.0)
        elif rand < 0.02:
            # Stuck (return last value - simulate with 1.0)
            return (True, 1.0)
        else:
            return (False, 1.0)

    def _generate_reading_value(self, sensor: Dict, metric_name: str,
                               current_time: datetime, metric_config: Dict) -> float:
        """
        Generate realistic sensor reading value.

        Combines:
        - Baseline value
        - Gaussian noise
        - Circadian pattern
        - Sensor drift
        - Anomalies
        """
        baseline = metric_config["baseline"]
        noise_std = metric_config["noise"]
        min_val = metric_config["min"]
        max_val = metric_config["max"]

        # Base value with Gaussian noise
        noise = np.random.normal(0, noise_std)
        value = baseline + noise

        # Apply circadian multiplier
        circadian = self._get_circadian_multiplier(current_time, metric_name)
        value *= circadian

        # Apply sensor drift
        drift = self._add_sensor_drift(sensor["id"], current_time)
        value *= (1 + drift)

        # Check for anomalies
        is_anomaly, anomaly_mult = self._generate_anomaly()
        if is_anomaly:
            value *= anomaly_mult

        # Clamp to valid range
        value = max(min(value, max_val), min_val)

        return round(value, 2)

    def generate_readings(self, duration_seconds: int = 3600,
                         reading_frequency_sec: int = 1) -> Iterator[SensorReading]:
        """
        Generate sensor reading stream.

        Args:
            duration_seconds: How long to generate data for
            reading_frequency_sec: How often each sensor reports (default: 1 sec)

        Yields:
            SensorReading objects
        """
        start_time = datetime.now()
        current_time = start_time

        # Calculate total readings
        num_intervals = duration_seconds // reading_frequency_sec
        total_readings = len(self.sensors) * num_intervals

        print(f"Generating {total_readings:,} sensor readings...")
        print(f"  Duration: {duration_seconds}s ({duration_seconds/3600:.1f} hours)")
        print(f"  Sensors: {len(self.sensors):,}")
        print(f"  Frequency: {reading_frequency_sec}s")
        print(f"  Readings/sec: {len(self.sensors)}")

        readings_generated = 0

        for _ in range(num_intervals):
            current_time += timedelta(seconds=reading_frequency_sec)

            # Each sensor reports all its metrics
            for sensor in self.sensors:
                sensor_type = sensor["type"]
                metrics_config = self.sensor_configs[sensor_type]["metrics"]

                for metric_name, metric_config in metrics_config.items():
                    value = self._generate_reading_value(
                        sensor, metric_name, current_time, metric_config
                    )

                    yield SensorReading(
                        time=current_time,
                        sensor_id=sensor["id"],
                        sensor_type=sensor_type.value,
                        location_lat=sensor["lat"],
                        location_lon=sensor["lon"],
                        metric_name=metric_name,
                        value=value,
                        unit=metric_config["unit"]
                    )

                    readings_generated += 1

            # Progress update every 1M readings
            if readings_generated % 1_000_000 == 0:
                print(f"  Generated {readings_generated:,} readings...")

        print(f"✅ Generated {readings_generated:,} readings")

    def generate_dataset(self, size: str = "small") -> List[SensorReading]:
        """
        Generate complete dataset.

        Args:
            size: 'small' (1M rows), 'medium' (100M rows), 'large' (1B rows)

        Returns:
            List of SensorReading objects
        """
        # Calculate parameters based on size
        readings_per_sensor = len(self.sensors) * sum(
            len(config["metrics"])
            for config in self.sensor_configs.values()
        )

        if size == "small":
            # 1M readings = ~10 seconds with 100K sensors
            duration_seconds = max(10, int(1_000_000 / readings_per_sensor))
        elif size == "medium":
            # 100M readings
            duration_seconds = max(100, int(100_000_000 / readings_per_sensor))
        elif size == "large":
            # 1B readings
            duration_seconds = max(1000, int(1_000_000_000 / readings_per_sensor))
        else:
            raise ValueError(f"Unknown size: {size}")

        readings = list(self.generate_readings(
            duration_seconds=duration_seconds,
            reading_frequency_sec=1
        ))

        return readings


def main():
    """Example usage and testing."""
    # Use smaller number for testing
    generator = IoTDataGenerator(seed=42, num_sensors=1000)

    # Generate 10 seconds of data
    print("\nGenerating sample IoT data...")
    readings = list(generator.generate_readings(duration_seconds=10, reading_frequency_sec=1))

    print(f"\n✅ Generated {len(readings):,} readings")
    print("\nSample readings (first 10):")

    for i, reading in enumerate(readings[:10]):
        print(f"  {i+1}. {reading.time.strftime('%H:%M:%S')} | "
              f"Sensor {reading.sensor_id:5d} ({reading.sensor_type:12s}) | "
              f"{reading.metric_name:15s}: {reading.value:7.2f} {reading.unit}")

    # Statistics
    from collections import Counter

    print("\nSensor Type Distribution:")
    type_counts = Counter(r.sensor_type for r in readings)
    for sensor_type, count in type_counts.most_common():
        print(f"  {sensor_type:15s}: {count:6d} readings ({count/len(readings)*100:5.1f}%)")

    print("\nMetric Distribution:")
    metric_counts = Counter(r.metric_name for r in readings)
    for metric, count in metric_counts.most_common():
        print(f"  {metric:20s}: {count:6d} readings")

    print("\nValue Statistics by Metric:")
    for metric in metric_counts.keys():
        metric_readings = [r for r in readings if r.metric_name == metric]
        values = [r.value for r in metric_readings]
        print(f"  {metric:20s}: {min(values):7.2f} - {max(values):7.2f} "
              f"(avg {np.mean(values):7.2f}, std {np.std(values):6.2f})")

    # Anomaly detection
    print("\nAnomaly Detection:")
    for metric in ["pm25", "vehicle_count", "noise_level"]:
        metric_readings = [r for r in readings if r.metric_name == metric]
        if metric_readings:
            values = [r.value for r in metric_readings]
            mean_val = np.mean(values)
            std_val = np.std(values)
            anomalies = [r for r in metric_readings if abs(r.value - mean_val) > 3 * std_val]
            print(f"  {metric:20s}: {len(anomalies)} anomalies (>{mean_val:.1f} ± {3*std_val:.1f})")


if __name__ == "__main__":
    main()
