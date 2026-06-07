import { mockClient } from 'aws-sdk-client-mock'
import { DynamoDBDocumentClient, UpdateCommand } from '@aws-sdk/lib-dynamodb'
import { handler } from './index'

const ddbMock = mockClient(DynamoDBDocumentClient)

beforeEach(() => {
  ddbMock.reset()
  process.env.SUBSCRIBERS_TABLE = 'digest-subscribers'
})

it('returns 200 with HTML page when unsubscribed successfully', async () => {
  ddbMock.on(UpdateCommand).resolves({
    Attributes: { email: 'test@example.com', status: 'UNSUBSCRIBED' },
  })

  const result = await handler({
    queryStringParameters: { email: 'test@example.com' },
  } as any)

  expect(result.statusCode).toBe(200)
  expect(result.headers!['Content-Type']).toBe('text/html')
  expect(result.body).toContain('Unsubscribed')
})

it('returns 400 when email query param is missing', async () => {
  const result = await handler({ queryStringParameters: {} } as any)

  expect(result.statusCode).toBe(400)
  const body = JSON.parse(result.body)
  expect(body.error).toBe('VALIDATION_ERROR')
})

it('returns 404 when email not found', async () => {
  ddbMock.on(UpdateCommand).resolves({ Attributes: undefined })

  const result = await handler({
    queryStringParameters: { email: 'unknown@example.com' },
  } as any)

  expect(result.statusCode).toBe(404)
  const body = JSON.parse(result.body)
  expect(body.error).toBe('NOT_FOUND')
})

it('returns 500 on DynamoDB error', async () => {
  ddbMock.on(UpdateCommand).rejects(new Error('DynamoDB error'))

  const result = await handler({
    queryStringParameters: { email: 'test@example.com' },
  } as any)

  expect(result.statusCode).toBe(500)
  const body = JSON.parse(result.body)
  expect(body.error).toBe('INTERNAL_ERROR')
})
