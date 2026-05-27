"""
orders_analytics — SQS analytics consumer.

Triggered by SQS event source mapping. Receives order.created notifications
forwarded from SNS via the analytics queue.

In production: parse message, aggregate order metrics, write summaries to RDS.
Lab: logs the event and returns success.
"""

import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def handler(event, context):
    records = event.get("Records", [])
    logger.info("Received %d record(s) from SQS", len(records))

    for record in records:
        body = json.loads(record["body"])

        # SNS wraps each published message in an envelope when
        # raw_message_delivery = false (the default).
        if "Message" in body:
            message = json.loads(body["Message"])
            source_topic = body.get("TopicArn", "unknown")
            logger.info("SNS message from %s: %s", source_topic, json.dumps(message))
        else:
            logger.info("Direct SQS message: %s", json.dumps(body))

    return {
        "statusCode": 200,
        "processed": len(records),
    }
