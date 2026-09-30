FROM python:3.12-slim
WORKDIR /app
COPY server.py /app/server.py
RUN useradd --uid 10001 --create-home voce && mkdir /app/data && chown voce:voce /app/data
USER voce
ENV VOCE_HOST=0.0.0.0 VOCE_DB=/app/data/voce.sqlite3 PORT=8787 PYTHONUNBUFFERED=1
EXPOSE 8787
CMD ["python", "server.py"]
