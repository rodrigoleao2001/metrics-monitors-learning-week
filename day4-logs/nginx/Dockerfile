FROM nginx:1.25-alpine

COPY nginx.conf /etc/nginx/nginx.conf

LABEL com.datadoghq.ad.logs='[{"source": "nginx", "service": "nginx-proxy"}]'

EXPOSE 80
