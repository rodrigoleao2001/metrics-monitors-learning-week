FROM python:3.11-slim

WORKDIR /app
RUN pip install --no-cache-dir datadog
COPY ecommerce.py .

CMD ["python", "-u", "ecommerce.py"]
