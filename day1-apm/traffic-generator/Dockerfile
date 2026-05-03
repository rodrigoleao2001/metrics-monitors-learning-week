FROM python:3.11-slim

WORKDIR /app
RUN pip install --no-cache-dir requests datadog
COPY generate.py .

CMD ["python", "-u", "generate.py"]
