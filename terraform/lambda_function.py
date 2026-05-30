import boto3
import urllib.parse
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3', endpoint_url=os.environ.get('AWS_ENDPOINT_URL'))

def lambda_handler(event, context):
    target_bucket = os.environ['TARGET_BUCKET']
    
    for record in event['Records']:
        source_bucket = record['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(record['s3']['object']['key'], encoding='utf-8')
        
        copy_source = {'Bucket': source_bucket, 'Key': key}
        
        logger.info(f"Початок копіювання файлу '{key}' з бакета '{source_bucket}' у бакет '{target_bucket}'")
        
        try:
            s3.copy_object(CopySource=copy_source, Bucket=target_bucket, Key=key)
            logger.info(f"Успіх! Файл '{key}' скопійовано.")
        except Exception as e:
            logger.error(f"Помилка при копіюванні: {e}")
            raise e