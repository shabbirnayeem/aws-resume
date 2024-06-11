# Use an official Python runtime as a parent image
FROM python:3.8-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages specified in requirements.txt
RUN pip3 install --no-cache-dir -r app/requirements.txt


# Make port 5000 available to the world outside this container
EXPOSE 9123


ENTRYPOINT [ "python" ]

CMD [ "app/app.py" ]