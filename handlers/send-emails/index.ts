import { GetObjectCommand, S3Client } from '@aws-sdk/client-s3'
import { sendBatch, scanAll, SubscriberStatus, requireEnv } from 'digest-shared'

const s3 = new S3Client({})

const SUBSCRIBERS_TABLE = requireEnv('SUBSCRIBERS_TABLE')
const FROM_EMAIL = requireEnv('FROM_EMAIL')
const MAX_RETRIES = parseInt(process.env.MAX_RETRIES ?? '3', 10)
const HTML_BUCKET = requireEnv('HTML_BUCKET')

interface Input {
  newsletterId: string
  htmlS3Key: string
}

export async function handler(input: Input): Promise<{ sentCount: number; failedCount: number }> {
  const { htmlS3Key } = input

  const subscribers = await scanAll({
    TableName: SUBSCRIBERS_TABLE,
    FilterExpression: '#status = :active',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: { ':active': SubscriberStatus.SUBSCRIBED },
  })

  const emails = subscribers.map(item => item.email as string)

  if (emails.length === 0) {
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

  if (failedCount > 0) {
    throw new Error(`Failed to send ${failedCount} out of ${emails.length} emails`)
  }

  return { sentCount, failedCount }
}
