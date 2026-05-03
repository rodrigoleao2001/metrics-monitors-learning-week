FROM python:3.11-slim

WORKDIR /app
RUN pip install --no-cache-dir datadog
COPY iot_sensors.py .

CMD ["python", "-u", "iot_sensors.py"]
