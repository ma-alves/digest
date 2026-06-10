import { mockClient } from 'aws-sdk-client-mock'
import { DynamoDBDocumentClient, PutCommand, ScanCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb'
import { ConditionalCheckFailedException } from '@aws-sdk/client-dynamodb'
import { handler as subscribeHandler } from '../../handlers/subscribe-handler'
import { handler as listHandler } from '../../handlers/list-subscribers'
import { handler as unsubscribeHandler } from '../../handlers/unsubscribe-handler'

const ddbMock = mockClient(DynamoDBDocumentClient)

beforeEach(() => {
  ddbMock.reset()
  process.env.SUBSCRIBERS_TABLE = 'digest-subscribers'
})

it('full subscriber lifecycle: subscribe → list → unsubscribe', async () => {
  ddbMock.on(PutCommand).resolves({})

  const subscribeResult = await subscribeHandler({
    body: JSON.stringify({ email: 'alice@example.com' }),
  } as any)

  expect(subscribeResult.statusCode).toBe(201)
  const subscriber = JSON.parse(subscribeResult.body)
  expect(subscriber.email).toBe('alice@example.com')
  expect(subscriber.status).toBe('SUBSCRIBED')

  ddbMock.on(ScanCommand).resolves({
    Items: [
      { email: 'alice@example.com', status: 'SUBSCRIBED' },
    ],
  })

  const listResult = await listHandler({} as any)
  expect(listResult.statusCode).toBe(200)
  const listBody = JSON.parse(listResult.body)
  expect(listBody.subscribers).toHaveLength(1)
  expect(listBody.subscribers[0].email).toBe('alice@example.com')

  ddbMock.on(UpdateCommand).resolves({
    Attributes: { email: 'alice@example.com', status: 'UNSUBSCRIBED' },
  })

  const unsubscribeResult = await unsubscribeHandler({
    queryStringParameters: { email: 'alice@example.com' },
  } as any)
  expect(unsubscribeResult.statusCode).toBe(200)
  expect(unsubscribeResult.headers!['Content-Type']).toBe('text/html')

  ddbMock.on(ScanCommand).resolves({ Items: [] })

  const listAfterResult = await listHandler({} as any)
  expect(listAfterResult.statusCode).toBe(200)
  expect(JSON.parse(listAfterResult.body).subscribers).toEqual([])
})

it('prevents duplicate subscription', async () => {
  ddbMock.on(PutCommand)
    .resolvesOnce({})
    .rejectsOnce(new ConditionalCheckFailedException({
      message: 'The conditional request failed',
      $metadata: { httpStatusCode: 400 },
    }))

  const first = await subscribeHandler({
    body: JSON.stringify({ email: 'bob@example.com' }),
  } as any)
  expect(first.statusCode).toBe(201)

  const second = await subscribeHandler({
    body: JSON.stringify({ email: 'bob@example.com' }),
  } as any)
  expect(second.statusCode).toBe(409)
  expect(JSON.parse(second.body).error).toBe('DUPLICATE_EMAIL')
})

it('unsubscribe returns 404 for unknown email', async () => {
  ddbMock.on(UpdateCommand).resolves({ Attributes: undefined })

  const result = await unsubscribeHandler({
    queryStringParameters: { email: 'ghost@example.com' },
  } as any)

  expect(result.statusCode).toBe(404)
  expect(JSON.parse(result.body).error).toBe('NOT_FOUND')
})
