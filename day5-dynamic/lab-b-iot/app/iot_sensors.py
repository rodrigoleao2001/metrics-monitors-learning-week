"""
Lab B - Farm IoT Sensors
Custom metrics via DogStatsD simulating IoT sensors on a Brazilian farm.

Metrics:
- iot.sensor.temperature (gauge): Temperature in Celsius, by sensor_id and zone
- iot.sensor.humidity (gauge): Humidity percentage, by sensor_id and zone
- iot.sensor.battery (gauge): Battery level 0-100%, by sensor_id
- iot.sensor.readings.count (count): Number of readings, by sensor_id and zone
- iot.sensor.signal_strength (gauge): Signal strength in dBm, by sensor_id
"""

import random
import time
from datadog import initialize, statsd

initialize(statsd_host="datadog-agent", statsd_port=8125)

ZONES = {
    "greenhouse": {"temp_range": (22, 30), "humidity_range": (60, 80), "sensors": ["gh-01", "gh-02", "gh-03"]},
    "field": {"temp_range": (15, 35), "humidity_range": (30, 70), "sensors": ["fd-01", "fd-02", "fd-03", "fd-04"]},
    "storage": {"temp_range": (5, 15), "humidity_range": (20, 40), "sensors": ["st-01", "st-02"]},
}

battery_levels = {}
cycle_count = 0


def init_batteries():
    for zone_config in ZONES.values():
        for sensor_id in zone_config["sensors"]:
            battery_levels[sensor_id] = random.uniform(70, 100)


def emit_sensor_data():
    global cycle_count
    cycle_count += 1

    for zone_name, zone_config in ZONES.items():
        for sensor_id in zone_config["sensors"]:
            base_tags = [f"sensor_id:{sensor_id}", f"zone:{zone_name}", "env:learning-week", "day:5"]

            if zone_name == "storage" and random.random() < 0.30:
                continue

            if sensor_id == "fd-03":
                temp = random.choice([
                    random.uniform(-40, 80),
                    random.uniform(zone_config["temp_range"][0], zone_config["temp_range"][1]),
                    999.9,
                    -999.9,
                ])
                humidity = random.choice([
                    random.uniform(0, 100),
                    random.uniform(-10, 110),
                ])
            elif zone_name == "greenhouse":
                if cycle_count % 10 < 4:
                    temp = random.uniform(38, 48)
                else:
                    temp = random.uniform(*zone_config["temp_range"])
                humidity = random.uniform(*zone_config["humidity_range"])
            else:
                temp = random.uniform(*zone_config["temp_range"])
                humidity = random.uniform(*zone_config["humidity_range"])

            statsd.gauge("iot.sensor.temperature", round(temp, 1), tags=base_tags)
            statsd.gauge("iot.sensor.humidity", round(humidity, 1), tags=base_tags)
            statsd.increment("iot.sensor.readings.count", tags=base_tags)

            # Battery drain
            if sensor_id in battery_levels:
                if zone_name == "field":
                    drain = random.uniform(0.3, 0.8)
                else:
                    drain = random.uniform(0.01, 0.05)

                battery_levels[sensor_id] = max(0, battery_levels[sensor_id] - drain)
                statsd.gauge("iot.sensor.battery", round(battery_levels[sensor_id], 1),
                             tags=[f"sensor_id:{sensor_id}", f"zone:{zone_name}", "env:learning-week", "day:5"])

            signal = random.randint(-90, -30)
            if zone_name == "storage":
                signal = random.randint(-95, -60)
            statsd.gauge("iot.sensor.signal_strength", signal, tags=base_tags)


if __name__ == "__main__":
    print("Starting IoT Farm Sensors metrics generator...")
    time.sleep(10)
    init_batteries()

    while True:
        emit_sensor_data()
        time.sleep(random.uniform(5, 15))
