import { UpdateCommand } from '@aws-sdk/lib-dynamodb'
import { getDynamoDBClient } from 'digest-shared'

const NEWSLETTERS_TABLE = process.env.NEWSLETTERS_TABLE!
const ddb = getDynamoDBClient()

interface Input {
  newsletterId: string
  status: string
  sendResult?: { sentCount: number; failedCount: number }
  error?: unknown
}

export async function handler(input: Input): Promise<{ success: boolean }> {
  const { newsletterId, status, sendResult, error } = input
  const now = new Date().toISOString()

  const updateExpression: string[] = ['SET #status = :status']
  const expressionAttributeNames: Record<string, string> = { '#status': 'status' }
  const expressionAttributeValues: Record<string, unknown> = { ':status': status }

  if (status === 'SENT' && sendResult) {
    updateExpression.push('sentAt = :sentAt')
    expressionAttributeValues[':sentAt'] = now
  }

  if (status === 'FAILED' && error) {
    updateExpression.push('errorMessage = :error')
    expressionAttributeValues[':error'] = JSON.stringify(error)
  }

  await ddb.send(new UpdateCommand({
    TableName: NEWSLETTERS_TABLE,
    Key: { id: newsletterId },
    UpdateExpression: updateExpression.join(', '),
    ExpressionAttributeNames: expressionAttributeNames,
    ExpressionAttributeValues: expressionAttributeValues,
  }))

  return { success: true }
}
