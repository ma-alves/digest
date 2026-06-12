import { mockClient } from 'aws-sdk-client-mock'
import { DynamoDBDocumentClient, ScanCommand } from '@aws-sdk/lib-dynamodb'
import { handler } from '../../handlers/list-subscribers'

const ddbMock = mockClient(DynamoDBDocumentClient)

beforeEach(() => {
  ddbMock.reset()
  process.env.SUBSCRIBERS_TABLE = 'digest-subscribers'
})

it('returns 200 with subscribers list', async () => {
  ddbMock.on(ScanCommand).resolves({
    Items: [
      { email: 'alice@example.com', status: 'SUBSCRIBED' },
      { email: 'bob@example.com', status: 'SUBSCRIBED' },
    ],
  })

  const result = await handler({} as any)

  expect(result.statusCode).toBe(200)
  const body = JSON.parse(result.body)
  expect(body.subscribers).toHaveLength(2)
})

it('returns 200 with empty list when no subscribers', async () => {
  ddbMock.on(ScanCommand).resolves({ Items: [] })

  const result = await handler({} as any)

  expect(result.statusCode).toBe(200)
  const body = JSON.parse(result.body)
  expect(body.subscribers).toEqual([])
})

it('returns 500 on DynamoDB error', async () => {
  ddbMock.on(ScanCommand).rejects(new Error('DynamoDB error'))

  const result = await handler({} as any)

  expect(result.statusCode).toBe(500)
  const body = JSON.parse(result.body)
  expect(body.error).toBe('INTERNAL_ERROR')
})
