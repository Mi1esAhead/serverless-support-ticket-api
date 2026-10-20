import os
import boto3
from botocore.exceptions import BotoCoreError, ClientError
from .models import Ticket


class StorageError(Exception):
    """Any AWS-side failure."""


class TicketNotFound(Exception):
    pass


class TicketStore:
    def __init__(self, bucket: str | None = None, client=None):
        self.bucket = bucket or os.environ["TICKET_BUCKET"]
        self.s3 = client or boto3.client("s3")

    def _key(self, ticket_id: str) -> str:
        return f"tickets/{ticket_id}.json"

    def put(self, ticket: Ticket) -> None:
        try:
            self.s3.put_object(
                Bucket=self.bucket,
                Key=self._key(ticket.id),
                Body=ticket.model_dump_json().encode(),
                ContentType="application/json",
            )
        except (ClientError, BotoCoreError) as e:
            raise StorageError(str(e)) from e

    def get(self, ticket_id: str) -> Ticket:
        try:
            obj = self.s3.get_object(Bucket=self.bucket, Key=self._key(ticket_id))
            return Ticket.model_validate_json(obj["Body"].read())
        except ClientError as e:
            if e.response["Error"]["Code"] in ("NoSuchKey", "404"):
                raise TicketNotFound(ticket_id) from e
            raise StorageError(str(e)) from e
        except BotoCoreError as e:
            raise StorageError(str(e)) from e