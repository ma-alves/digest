import { mockClient } from 'aws-sdk-client-mock'
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb'
import { ConditionalCheckFailedException } from '@aws-sdk/client-dynamodb'
import { handler } from './index'

const ddbMock = mockClient(DynamoDBDocumentClient)

beforeEach(() => {
  ddbMock.reset()
  process.env.SUBSCRIBERS_TABLE = 'digest-subscribers'
})

it('creates a subscriber and returns 201', async () => {
  ddbMock.on(PutCommand).resolves({})

  const result = await handler({ body: JSON.stringify({ email: 'test@example.com' }) } as any)

  expect(result.statusCode).toBe(201)
  const body = JSON.parse(result.body)
  expect(body.email).toBe('test@example.com')
  expect(body.status).toBe('SUBSCRIBED')
})

it('returns 400 when body is missing', async () => {
  const result = await handler({} as any)

  expect(result.statusCode).toBe(400)
  const body = JSON.parse(result.body)
  expect(body.error).toBe('VALIDATION_ERROR')
})

it('returns 400 when email is invalid', async () => {
  const result = await handler({ body: JSON.stringify({ email: 'not-an-email' }) } as any)

  expect(result.statusCode).toBe(400)
  const body = JSON.parse(result.body)
  expect(body.error).toBe('VALIDATION_ERROR')
})

it('returns 409 when email already exists', async () => {
  ddbMock.on(PutCommand).rejects(
    new ConditionalCheckFailedException({
      message: 'The conditional request failed',
      $metadata: { httpStatusCode: 400 },
    }),
  )

  const result = await handler({ body: JSON.stringify({ email: 'existing@example.com' }) } as any)

  expect(result.statusCode).toBe(409)
  const body = JSON.parse(result.body)
  expect(body.error).toBe('DUPLICATE_EMAIL')
})
