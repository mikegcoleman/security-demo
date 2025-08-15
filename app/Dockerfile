FROM python:3.11-slim

WORKDIR /app

# copy requirements first for better caching
COPY requirements.txt .

# install deps
RUN pip install --no-cache-dir -r requirements.txt

# copy app and required files
COPY app.py .
COPY wizexercise.txt .

# expose port
EXPOSE 8080

# run app
CMD ["python", "app.py"]