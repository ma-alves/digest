import { SNSClient, PublishCommand } from '@aws-sdk/client-sns'
import { requireEnv } from 'digest-shared'

const sns = new SNSClient({})
const TOPIC_ARN = requireEnv('SNS_TOPIC_ARN')

interface Input {
  error?: unknown
}

export async function handler(input: Input): Promise<{ notified: boolean }> {
  const { error } = input

  await sns.send(new PublishCommand({
    TopicArn: TOPIC_ARN,
    Subject: 'Digest Newsletter — Workflow Failed',
    Message: JSON.stringify({
      message: 'The Digest newsletter workflow has failed.',
      errorDetails: error ?? 'Unknown error',
      timestamp: new Date().toISOString(),
    }, null, 2),
  }))

  return { notified: true }
}
