import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda'
import { ScanCommand } from '@aws-sdk/lib-dynamodb'
import { getDynamoDBClient, SubscriberStatus } from 'digest-shared'

const TABLE_NAME = process.env.SUBSCRIBERS_TABLE!
const ddb = getDynamoDBClient()

export async function handler(_event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const result = await ddb.send(new ScanCommand({
      TableName: TABLE_NAME,
      FilterExpression: '#status = :active',
      ExpressionAttributeNames: { '#status': 'status' },
      ExpressionAttributeValues: { ':active': SubscriberStatus.SUBSCRIBED },
    }))

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ subscribers: result.Items ?? [] }),
    }
  } catch {
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'INTERNAL_ERROR', message: 'An unexpected error occurred.' }),
    }
  }
}
