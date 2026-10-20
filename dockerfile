# AWS Lambda base image: includes the Lambda Runtime Interface Client.
FROM public.ecr.aws/lambda/python:3.12

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ${LAMBDA_TASK_ROOT}/app

# module.function of the Mangum handler in app/main.py
CMD ["app.main.handler"]