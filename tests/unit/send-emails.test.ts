import { mockClient } from 'aws-sdk-client-mock'
import { DynamoDBDocumentClient, ScanCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb'
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3'
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses'
import { handler } from '../../handlers/send-emails'

function mockS3Body(body: string) {
  return { transformToString: () => Promise.resolve(body) } as any
}

const ddbMock = mockClient(DynamoDBDocumentClient)
const s3Mock = mockClient(S3Client)
const sesMock = mockClient(SESClient)

beforeEach(() => {
  ddbMock.reset()
  s3Mock.reset()
  sesMock.reset()

  process.env.SUBSCRIBERS_TABLE = 'digest-subscribers'
  process.env.NEWSLETTERS_TABLE = 'digest-newsletters'
  process.env.FROM_EMAIL = 'newsletter@example.com'
  process.env.MAX_RETRIES = '3'
  process.env.HTML_BUCKET = 'digest-rendered-html'
})

it('returns early with 0 counts when no subscribers', async () => {
  ddbMock.on(ScanCommand).resolves({ Items: [] })

  const result = await handler({ newsletterId: 'test-id', htmlS3Key: 'newsletters/test.html' })

  expect(result.sentCount).toBe(0)
  expect(result.failedCount).toBe(0)
})

it('sends emails and returns counts', async () => {
  ddbMock.on(ScanCommand).resolves({
    Items: [
      { email: 'alice@example.com' },
      { email: 'bob@example.com' },
    ],
  })

  s3Mock.on(GetObjectCommand).resolves({
    Body: mockS3Body('<h1>Newsletter</h1>'),
  })

  sesMock.on(SendEmailCommand).resolves({ MessageId: 'msg-id' })
  ddbMock.on(UpdateCommand).resolves({})

  const result = await handler({ newsletterId: 'test-id', htmlS3Key: 'newsletters/test.html' })

  expect(result.sentCount).toBe(2)
  expect(result.failedCount).toBe(0)
})

it('throws when S3 fetch fails', async () => {
  ddbMock.on(ScanCommand).resolves({ Items: [{ email: 'alice@example.com' }] })
  s3Mock.on(GetObjectCommand).rejects(new Error('S3 error'))

  await expect(handler({ newsletterId: 'test-id', htmlS3Key: 'newsletters/test.html' }))
    .rejects.toThrow('S3 error')
})

it('handles partial SES failures', async () => {
  ddbMock.on(ScanCommand).resolves({
    Items: [
      { email: 'alice@example.com' },
      { email: 'bob@example.com' },
    ],
  })
  s3Mock.on(GetObjectCommand).resolves({
    Body: mockS3Body('<h1>Newsletter</h1>'),
  })
  sesMock.on(SendEmailCommand).rejects(new Error('SES error'))

  const result = await handler({ newsletterId: 'test-id', htmlS3Key: 'newsletters/test.html' })

  expect(result.sentCount).toBe(0)
  expect(result.failedCount).toBe(2)
})
