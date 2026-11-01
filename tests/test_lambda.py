import importlib
from decimal import Decimal

import boto3

import lambda_function


class FakeTable:
    def __init__(self):
        self.calls = []

    def update_item(self, **kwargs):
        self.calls.append(kwargs)
        return {'Attributes': {'count': Decimal(42)}}


def test_increments_atomically_and_returns_count(monkeypatch):
    table = FakeTable()
    monkeypatch.setattr(lambda_function, 'table', table)

    assert lambda_function.lambda_handler({}, None) == {'count': 42}

    assert len(table.calls) == 1
    call = table.calls[0]
    assert call['UpdateExpression'] == 'ADD #count :inc'
    assert call['ExpressionAttributeValues'] == {':inc': 1}
    assert call['ReturnValues'] == 'UPDATED_NEW'


def test_import_has_no_side_effects(monkeypatch):
    # Importing the module must not count a visit (the old version called the handler at import time)
    table = FakeTable()

    class FakeDynamoDB:
        def Table(self, name):
            return table

    monkeypatch.setattr(boto3, 'resource', lambda *args, **kwargs: FakeDynamoDB())
    importlib.reload(lambda_function)

    assert table.calls == []
