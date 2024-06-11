import boto3
import json

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('VisitorCount')
    
    # Get the current count
    response = table.get_item(Key={'id': 'counter'})
    current_count = response['Item']['count']

    # Convert Decimal to int
    current_count = int(current_count)

    print(current_count)
    
    # Increment the count
    new_count = current_count + 1
    table.update_item(
        Key={'id': 'counter'},
        UpdateExpression='SET #count = :val1',
        ExpressionAttributeNames={'#count': 'count'},
        ExpressionAttributeValues={':val1': new_count}
    )
    updated_counter = response['Item']['count']
    print(updated_counter)
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({'count': new_count})
    }


lambda_handler(None, None)