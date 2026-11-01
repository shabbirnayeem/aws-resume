import os

import boto3

# Created once per container and reused across invocations
table = boto3.resource('dynamodb').Table(os.environ.get('TABLE_NAME', 'VisitorCount'))


def lambda_handler(event, context):
    # ADD is atomic, so concurrent visits can't overwrite each other's increment
    response = table.update_item(
        Key={'id': 'counter'},
        UpdateExpression='ADD #count :inc',
        ExpressionAttributeNames={'#count': 'count'},
        ExpressionAttributeValues={':inc': 1},
        ReturnValues='UPDATED_NEW',
    )
    # API Gateway uses a non-proxy integration, so this dict is returned as the response body
    return {'count': int(response['Attributes']['count'])}
