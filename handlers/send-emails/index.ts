import { ScanCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb'
import { GetObjectCommand, S3Client } from '@aws-sdk/client-s3'
import { getDynamoDBClient, sendBatch, SubscriberStatus } from 'digest-shared'

const s3 = new S3Client({})
const ddb = getDynamoDBClient()

const SUBSCRIBERS_TABLE = process.env.SUBSCRIBERS_TABLE!
const NEWSLETTERS_TABLE = process.env.NEWSLETTERS_TABLE!
const FROM_EMAIL = process.env.FROM_EMAIL!
const MAX_RETRIES = parseInt(process.env.MAX_RETRIES ?? '3', 10)
const HTML_BUCKET = process.env.HTML_BUCKET!

interface Input {
  newsletterId: string
  htmlS3Key: string
}

export async function handler(input: Input): Promise<{ sentCount: number; failedCount: number }> {
  const { newsletterId, htmlS3Key } = input

  const subscribersResult = await ddb.send(new ScanCommand({
    TableName: SUBSCRIBERS_TABLE,
    FilterExpression: '#status = :active',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: { ':active': SubscriberStatus.SUBSCRIBED },
  }))

  const emails = (subscribersResult.Items ?? []).map(item => item.email)

  if (emails.length === 0) {
    await ddb.send(new UpdateCommand({
      TableName: NEWSLETTERS_TABLE,
      Key: { id: newsletterId },
      UpdateExpression: 'SET #status = :status, sentAt = :now',
      ExpressionAttributeNames: { '#status': 'status' },
      ExpressionAttributeValues: {
        ':status': 'SENT',
        ':now': new Date().toISOString(),
      },
    }))
    return { sentCount: 0, failedCount: 0 }
  }

  const htmlResult = await s3.send(new GetObjectCommand({
    Bucket: HTML_BUCKET,
    Key: htmlS3Key,
  }))
  const htmlBody = await htmlResult.Body!.transformToString()

  const { sentCount, failedCount } = await sendBatch(
    emails,
    FROM_EMAIL,
    'Your Digest Newsletter',
    htmlBody,
    MAX_RETRIES,
  )

  const now = new Date().toISOString()
  await ddb.send(new UpdateCommand({
    TableName: NEWSLETTERS_TABLE,
    Key: { id: newsletterId },
    UpdateExpression: 'SET #status = :status, sentAt = :now',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: {
      ':status': 'SENT',
      ':now': now,
    },
  }))

  return { sentCount, failedCount }
}
