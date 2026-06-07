import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda'
import { PutCommand } from '@aws-sdk/lib-dynamodb'
import { ConditionalCheckFailedException } from '@aws-sdk/client-dynamodb'
import { ulid } from 'ulid'
import { getDynamoDBClient, subscribeSchema, SubscriberStatus } from 'digest-shared'

const TABLE_NAME = process.env.SUBSCRIBERS_TABLE!
const ddb = getDynamoDBClient()

export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  try {
    if (!event.body) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'VALIDATION_ERROR', message: 'Request body is required.' }),
      }
    }

    const parsed = subscribeSchema.safeParse(JSON.parse(event.body))
    if (!parsed.success) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          error: 'VALIDATION_ERROR',
          message: parsed.error.issues[0]?.message ?? 'Invalid email format.',
        }),
      }
    }

    const email = parsed.data.email.toLowerCase()
    const now = new Date().toISOString()

    await ddb.send(new PutCommand({
      TableName: TABLE_NAME,
      Item: {
        email,
        id: ulid(),
        createdAt: now,
        status: SubscriberStatus.SUBSCRIBED,
      },
      ConditionExpression: 'attribute_not_exists(email)',
    }))

    return {
      statusCode: 201,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, id: ulid(), createdAt: now, status: SubscriberStatus.SUBSCRIBED }),
    }
  } catch (err) {
    if (err instanceof ConditionalCheckFailedException) {
      return {
        statusCode: 409,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'DUPLICATE_EMAIL', message: 'Email is already registered.' }),
      }
    }

    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'INTERNAL_ERROR', message: 'An unexpected error occurred.' }),
    }
  }
}
