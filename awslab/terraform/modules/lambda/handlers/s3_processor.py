"""
s3_processor — S3 object creation processor.

Triggered by S3 event notifications on object creation.
In production: download the object, validate its schema, write a processed
version back to a different prefix or publish a status event to SNS.
Lab: logs the bucket/key and returns success.
"""

import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def handler(event, context):
    records = event.get("Records", [])
    logger.info("Received %d S3 event(s)", len(records))

    for record in records:
        event_name = record.get("eventName", "unknown")
        s3 = record.get("s3", {})
        bucket = s3.get("bucket", {}).get("name", "unknown")
        key = s3.get("object", {}).get("key", "unknown")
        size = s3.get("object", {}).get("size", 0)

        logger.info(
            "Event: %s | s3://%s/%s (%d bytes)",
            event_name,
            bucket,
            key,
            size,
        )

    return {
        "statusCode": 200,
        "processed": len(records),
    }
