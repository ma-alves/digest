import { mockClient } from 'aws-sdk-client-mock'
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb'
import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3'
import { handler } from './index'

function mockS3Body(body: string) {
  return { transformToString: () => Promise.resolve(body) } as any
}

const ddbMock = mockClient(DynamoDBDocumentClient)
const s3Mock = mockClient(S3Client)

beforeEach(() => {
  ddbMock.reset()
  s3Mock.reset()

  process.env.TEMPLATE_BUCKET = 'digest-templates'
  process.env.TEMPLATE_KEY = 'template.hbs'
  process.env.NEWSLETTERS_TABLE = 'digest-newsletters'
  process.env.HTML_BUCKET = 'digest-rendered-html'
})

it('throws when template fetch fails', async () => {
  s3Mock.on(GetObjectCommand).rejects(new Error('S3 error'))

  await expect(handler({
    articles: [],
    generatedAt: '2025-01-01T00:00:00Z',
  })).rejects.toThrow('S3 error')
})

it('handles empty articles list', async () => {
  s3Mock.on(GetObjectCommand).resolves({
    Body: mockS3Body('{{articleCount}} articles'),
  })
  s3Mock.on(PutObjectCommand).resolves({})
  ddbMock.on(PutCommand).resolves({})

  const result = await handler({
    articles: [],
    generatedAt: '2025-01-01T00:00:00Z',
  })

  expect(result.id).toBeDefined()
})

it('generates newsletter and returns id and htmlS3Key', async () => {
  s3Mock.on(GetObjectCommand).resolves({
    Body: mockS3Body('<h1>Hello {{articleCount}}</h1>'),
  })

  s3Mock.on(PutObjectCommand).resolves({})
  ddbMock.on(PutCommand).resolves({})

  const result = await handler({
    articles: [
      { title: 'Test', description: 'Desc', url: 'https://x.com', urlToImage: null, publishedAt: '2025-01-01T00:00:00Z', source: { name: 'Src' } },
    ],
    generatedAt: '2025-01-01T00:00:00Z',
  })

  expect(result.id).toBeDefined()
  expect(result.htmlS3Key).toContain('newsletters/')
})

it('throws when S3 upload fails', async () => {
  s3Mock.on(PutObjectCommand).rejects(new Error('Put failed'))

  await expect(handler({
    articles: [{ title: 'Test', description: 'Desc', url: 'https://x.com', urlToImage: null, publishedAt: '2025-01-01T00:00:00Z', source: { name: 'Src' } }],
    generatedAt: '2025-01-01T00:00:00Z',
  })).rejects.toThrow('Put failed')
})

it('throws when DynamoDB save fails after S3 upload', async () => {
  s3Mock.on(PutObjectCommand).resolves({})
  ddbMock.on(PutCommand).rejects(new Error('DynamoDB error'))

  await expect(handler({
    articles: [{ title: 'Test', description: 'Desc', url: 'https://x.com', urlToImage: null, publishedAt: '2025-01-01T00:00:00Z', source: { name: 'Src' } }],
    generatedAt: '2025-01-01T00:00:00Z',
  })).rejects.toThrow('DynamoDB error')
})
