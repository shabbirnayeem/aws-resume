# aws-resume

This project is my Cloud Resume Challenge, hosted on AWS. The static website, developed using HTML, CSS, JavaScript, and Python Flask, is deployed on AWS ECS with Docker images created using Dockerfile. It features a visitor counter implemented with AWS Lambda functions. The backend is powered by Python, and data is stored in an AWS DynamoDB database. Infrastructure as code is managed using Terraform.
## Pre-requisites

Before getting started with this project, make sure you have the following:

- AWS account
- Basic knowledge of HTML, CSS, and JavaScript
- Familiarity with AWS services such as ECS, Lambda, and DynamoDB

## Structure

The project has the following structure:

- `index.html`: The main HTML file for the static website.
- `style.css`: The CSS file for styling the website.functionality.
- `lambda_function.py`: The Python code for the visitor counter Lambda function.
- `README.md`: This file, providing project documentation and instructions.
- `terraform`: Contain's the AWS infrastcure.
- `Dockerfile`: Configuration for docker image.

## Credit
I am not a designer, so I used this template to create my site.
https://styleshout.com/free-templates/ceevee/

