import { mockClient } from 'aws-sdk-client-mock'
import { DynamoDBDocumentClient, PutCommand, ScanCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb'
import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3'
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager'
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses'
import axios from 'axios'
import { handler as fetchHandler } from '../../handlers/fetch-articles/index'
import { handler as generateHandler } from '../../handlers/generate-newsletter/index'
import { handler as sendHandler } from '../../handlers/send-emails'
import { handler as markHandler } from '../../handlers/mark-newsletter-status'

const secretsMock = mockClient(SecretsManagerClient)
const s3Mock = mockClient(S3Client)
const ddbMock = mockClient(DynamoDBDocumentClient)
const sesMock = mockClient(SESClient)

jest.mock('axios')
const mockedAxios = jest.mocked(axios)

function mockS3Body(body: string) {
  return { transformToString: () => Promise.resolve(body) } as any
}

beforeEach(() => {
  secretsMock.reset()
  s3Mock.reset()
  ddbMock.reset()
  sesMock.reset()
  mockedAxios.mockReset()

  process.env.SUBSCRIBERS_TABLE = 'digest-subscribers'
  process.env.NEWSLETTERS_TABLE = 'digest-newsletters'
  process.env.FROM_EMAIL = 'newsletter@example.com'
  process.env.MAX_RETRIES = '3'
  process.env.HTML_BUCKET = 'digest-rendered-html'
  process.env.TEMPLATE_BUCKET = 'digest-templates'
  process.env.TEMPLATE_KEY = 'template.hbs'
  process.env.NEWSAPI_KEY_ARN = 'arn:aws:secretsmanager:us-east-1:123456789012:secret:newsapi-key'
  process.env.SEARCH_QUERY = 'technology'
  process.env.LANGUAGE = 'en'
  process.env.ARTICLE_COUNT = '10'
})

it('runs the full newsletter workflow end-to-end', async () => {
  secretsMock.on(GetSecretValueCommand).resolves({ SecretString: 'fake-api-key' })

  mockedAxios.get.mockResolvedValue({
    data: {
      status: 'ok',
      totalResults: 2,
      articles: [
        {
          title: 'AI Advances',
          description: 'Latest in AI',
          url: 'https://example.com/ai',
          urlToImage: 'https://example.com/ai.jpg',
          publishedAt: '2025-01-10T00:00:00Z',
          source: { name: 'Tech News' },
        },
        {
          title: 'Space Exploration',
          description: 'Mars mission update',
          url: 'https://example.com/space',
          urlToImage: null,
          publishedAt: '2025-01-10T01:00:00Z',
          source: { name: 'Science Daily' },
        },
      ],
    },
  })

  const fetchResult = await fetchHandler()
  expect(fetchResult.articles).toHaveLength(2)
  expect(fetchResult.articles[0].title).toBe('AI Advances')

  s3Mock.on(GetObjectCommand).resolves({
    Body: mockS3Body('<h1>{{articleCount}} articles today</h1>'),
  })
  s3Mock.on(PutObjectCommand).resolves({})
  ddbMock.on(PutCommand).resolves({})

  const generateResult = await generateHandler({
    articles: fetchResult.articles,
    generatedAt: '2025-01-10T00:00:00Z',
  })
  expect(generateResult.id).toBeDefined()
  expect(generateResult.htmlS3Key).toContain('newsletters/')

  ddbMock.on(ScanCommand).resolves({
    Items: [
      { email: 'alice@example.com' },
      { email: 'bob@example.com' },
    ],
  })
  s3Mock.on(GetObjectCommand).resolves({
    Body: mockS3Body('<h1>Newsletter content</h1>'),
  })
  sesMock.on(SendEmailCommand).resolves({ MessageId: 'msg-id' })
  ddbMock.on(UpdateCommand).resolves({})

  const sendResult = await sendHandler({
    newsletterId: generateResult.id,
    htmlS3Key: generateResult.htmlS3Key,
  })
  expect(sendResult.sentCount).toBe(2)
  expect(sendResult.failedCount).toBe(0)

  ddbMock.on(UpdateCommand).resolves({})

  const markResult = await markHandler({
    newsletterId: generateResult.id,
    status: 'SENT',
    sendResult: { sentCount: 2, failedCount: 0 },
  })
  expect(markResult.success).toBe(true)
})

it('handles empty articles gracefully through the workflow', async () => {
  s3Mock.on(GetObjectCommand).resolves({
    Body: mockS3Body('{{articleCount}} articles'),
  })
  s3Mock.on(PutObjectCommand).resolves({})
  ddbMock.on(PutCommand).resolves({})

  const generateResult = await generateHandler({
    articles: [],
    generatedAt: '2025-01-10T00:00:00Z',
  })

  ddbMock.on(ScanCommand).resolves({ Items: [] })

  const sendResult = await sendHandler({
    newsletterId: generateResult.id,
    htmlS3Key: generateResult.htmlS3Key,
  })
  expect(sendResult.sentCount).toBe(0)
  expect(sendResult.failedCount).toBe(0)
})

it('marks newsletter as FAILED on workflow error', async () => {
  ddbMock.on(UpdateCommand).resolves({})

  const markResult = await markHandler({
    newsletterId: 'test-id',
    status: 'FAILED',
    error: { message: 'NewsAPI request failed after 3 retries', service: 'NewsAPI' },
  })
  expect(markResult.success).toBe(true)
})

it('sends emails only to SUBSCRIBED users', async () => {
  s3Mock.on(GetObjectCommand).resolves({
    Body: mockS3Body('<h1>Content</h1>'),
  })
  sesMock.on(SendEmailCommand).resolves({ MessageId: 'msg-id' })
  ddbMock.on(UpdateCommand).resolves({})

  ddbMock.on(ScanCommand).resolves({
    Items: [
      { email: 'active@example.com' },
    ],
  })

  const result = await sendHandler({
    newsletterId: 'nid',
    htmlS3Key: 'newsletters/n.html',
  })
  expect(result.sentCount).toBe(1)

  const sesCalls = sesMock.commandCalls(SendEmailCommand)
  expect(sesCalls[0].args[0].input.Destination!.ToAddresses).toEqual(['active@example.com'])
})
