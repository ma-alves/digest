import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda'
import { scanAll, SubscriberStatus, requireEnv } from 'digest-shared'

const TABLE_NAME = requireEnv('SUBSCRIBERS_TABLE')

export async function handler(_event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const subscribers = await scanAll({
      TableName: TABLE_NAME,
      FilterExpression: '#status = :active',
      ExpressionAttributeNames: { '#status': 'status' },
      ExpressionAttributeValues: { ':active': SubscriberStatus.SUBSCRIBED },
    })

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ subscribers }),
    }
  } catch {
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'INTERNAL_ERROR', message: 'An unexpected error occurred.' }),
    }
  }
}
