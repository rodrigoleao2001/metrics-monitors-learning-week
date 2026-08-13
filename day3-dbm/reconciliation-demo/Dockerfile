FROM python:3.11-slim

WORKDIR /demo
RUN pip install --no-cache-dir requests
COPY reconciliation_demo.py .

CMD ["python", "-u", "reconciliation_demo.py"]
