import { mockClient } from 'aws-sdk-client-mock'
import { DynamoDBDocumentClient, UpdateCommand } from '@aws-sdk/lib-dynamodb'
import { handler } from './index'

const ddbMock = mockClient(DynamoDBDocumentClient)

beforeEach(() => {
  ddbMock.reset()
  process.env.NEWSLETTERS_TABLE = 'digest-newsletters'
})

it('marks newsletter as SENT and returns success', async () => {
  ddbMock.on(UpdateCommand).resolves({})

  const result = await handler({
    newsletterId: 'test-id',
    status: 'SENT',
    sendResult: { sentCount: 10, failedCount: 0 },
  })

  expect(result.success).toBe(true)
})

it('marks newsletter as FAILED with error message', async () => {
  ddbMock.on(UpdateCommand).resolves({})

  const result = await handler({
    newsletterId: 'test-id',
    status: 'FAILED',
    error: { errorType: 'Error', errorMessage: 'Something went wrong' },
  })

  expect(result.success).toBe(true)
})

it('returns success with minimal input', async () => {
  ddbMock.on(UpdateCommand).resolves({})

  const result = await handler({
    newsletterId: 'test-id',
    status: 'GENERATED',
  })

  expect(result.success).toBe(true)
})

it('throws on DynamoDB error', async () => {
  ddbMock.on(UpdateCommand).rejects(new Error('DynamoDB error'))

  await expect(handler({
    newsletterId: 'test-id',
    status: 'SENT',
    sendResult: { sentCount: 5, failedCount: 0 },
  })).rejects.toThrow('DynamoDB error')
})
