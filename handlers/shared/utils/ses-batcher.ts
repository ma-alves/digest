import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses'

const ses = new SESClient({})

export interface BatchResult {
  sentCount: number
  failedCount: number
}

export async function sendBatch(
  emails: string[],
  from: string,
  subject: string,
  htmlBody: string,
  maxRetries = 3,
): Promise<BatchResult> {
  const BATCH_SIZE = 50
  let sentCount = 0
  let failedCount = 0

  for (let i = 0; i < emails.length; i += BATCH_SIZE) {
    const batch = emails.slice(i, i + BATCH_SIZE)
    let lastError: Error | undefined

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await ses.send(new SendEmailCommand({
          Source: from,
          Destination: {
            ToAddresses: batch,
          },
          Message: {
            Subject: { Data: subject },
            Body: { Html: { Data: htmlBody } },
          },
        }))
        sentCount += batch.length
        lastError = undefined
        break
      } catch (err) {
        lastError = err as Error
        if (attempt < maxRetries - 1) {
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000))
        }
      }
    }

    if (lastError) {
      failedCount += batch.length
    }
  }

  return { sentCount, failedCount }
}
