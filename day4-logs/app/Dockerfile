FROM python:3.11-slim

WORKDIR /app
COPY app.py .

LABEL com.datadoghq.ad.logs='[{"source": "python", "service": "log-generator", "log_processing_rules": [{"type": "multi_line", "name": "log_start_with_json", "pattern": "\\{"}]}]'

CMD ["python", "-u", "app.py"]
