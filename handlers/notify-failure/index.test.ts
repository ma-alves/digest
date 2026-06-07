import { mockClient } from 'aws-sdk-client-mock'
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns'
import { handler } from './index'

const snsMock = mockClient(SNSClient)

beforeEach(() => {
  snsMock.reset()
  process.env.SNS_TOPIC_ARN = 'arn:aws:sns:us-east-1:123456789012:digest-newsletter-failures'
})

it('publishes to SNS and returns notified true', async () => {
  snsMock.on(PublishCommand).resolves({ MessageId: 'msg-id' })

  const result = await handler({ error: 'Test error' })

  expect(result.notified).toBe(true)
})

it('publishes to SNS with default error message', async () => {
  snsMock.on(PublishCommand).resolves({ MessageId: 'msg-id' })

  const result = await handler({})

  expect(result.notified).toBe(true)
})

it('throws on SNS error', async () => {
  snsMock.on(PublishCommand).rejects(new Error('SNS error'))

  await expect(handler({ error: 'test' })).rejects.toThrow('SNS error')
})
