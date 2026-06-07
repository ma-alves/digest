import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda'
import { UpdateCommand } from '@aws-sdk/lib-dynamodb'
import { getDynamoDBClient, emailQuerySchema, SubscriberStatus } from 'digest-shared'
import { readFileSync } from 'fs'
import { join } from 'path'

const TABLE_NAME = process.env.SUBSCRIBERS_TABLE!
const ddb = getDynamoDBClient()

function getHtmlPage(): string {
  return readFileSync(join(__dirname, 'unsubscribed.html'), 'utf-8')
}

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    const queryParams = event.queryStringParameters ?? {}
    const parsed = emailQuerySchema.safeParse(queryParams)
    if (!parsed.success) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'VALIDATION_ERROR', message: 'Valid email query parameter is required.' }),
      }
    }

    const email = parsed.data.email.toLowerCase()

    const result = await ddb.send(new UpdateCommand({
      TableName: TABLE_NAME,
      Key: { email },
      UpdateExpression: 'SET #status = :status',
      ExpressionAttributeNames: { '#status': 'status' },
      ExpressionAttributeValues: { ':status': SubscriberStatus.UNSUBSCRIBED },
      ReturnValues: 'ALL_NEW',
    }))

    if (!result.Attributes) {
      return {
        statusCode: 404,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'NOT_FOUND', message: 'Email not found.' }),
      }
    }

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'text/html' },
      body: getHtmlPage(),
    }
  } catch {
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'INTERNAL_ERROR', message: 'An unexpected error occurred.' }),
    }
  }
}
