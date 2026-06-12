import { GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3'
import { PutCommand } from '@aws-sdk/lib-dynamodb'
import { ulid } from 'ulid'
import { getDynamoDBClient, compileTemplate, NewsletterStatus, requireEnv } from 'digest-shared'
import type { Article } from 'digest-shared'

const s3 = new S3Client({})
const ddb = getDynamoDBClient()

const TEMPLATE_BUCKET = requireEnv('TEMPLATE_BUCKET')
const TEMPLATE_KEY = process.env.TEMPLATE_KEY ?? 'template.hbs'
const NEWSLETTERS_TABLE = requireEnv('NEWSLETTERS_TABLE')
const HTML_BUCKET = requireEnv('HTML_BUCKET')

let cachedTemplate: string | undefined

async function getTemplate(): Promise<string> {
  if (cachedTemplate) return cachedTemplate

  const result = await s3.send(new GetObjectCommand({
    Bucket: TEMPLATE_BUCKET,
    Key: TEMPLATE_KEY,
  }))
  cachedTemplate = await result.Body!.transformToString()
  return cachedTemplate
}

interface Input {
  articles: Article[]
  generatedAt: string
}

export async function handler(input: Input): Promise<{ id: string; htmlS3Key: string }> {
  const templateSource = await getTemplate()
  const template = compileTemplate(templateSource)

  const newsletterId = ulid()
  const { articles, generatedAt } = input
  const articleCount = articles.length

  const html = template({ articles, generatedAt, articleCount })

  const htmlS3Key = `newsletters/${newsletterId}.html`
  await s3.send(new PutObjectCommand({
    Bucket: HTML_BUCKET,
    Key: htmlS3Key,
    Body: html,
    ContentType: 'text/html',
  }))

  await ddb.send(new PutCommand({
    TableName: NEWSLETTERS_TABLE,
    Item: {
      id: newsletterId,
      title: `Digest - ${new Date(generatedAt).toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}`,
      articleCount,
      status: NewsletterStatus.GENERATED,
      generatedAt,
      htmlS3Key,
    },
  }))

  return { id: newsletterId, htmlS3Key }
}
