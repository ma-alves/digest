import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager'
import axios from 'axios'
import type { Article } from 'digest-shared'

const secretsClient = new SecretsManagerClient({})

let cachedKey: string | undefined

async function getApiKey(): Promise<string> {
  if (cachedKey) return cachedKey

  const arn = process.env.NEWSAPI_KEY_ARN!
  const result = await secretsClient.send(new GetSecretValueCommand({ SecretId: arn }))
  cachedKey = result.SecretString!
  return cachedKey
}

interface NewsAPIResponse {
  status: string
  totalResults: number
  articles: Article[]
}

export async function handler(): Promise<{ articles: Article[] }> {
  const key = await getApiKey()
  const query = process.env.SEARCH_QUERY ?? 'technology'
  const language = process.env.LANGUAGE ?? 'en'
  const pageSize = process.env.ARTICLE_COUNT ?? '10'

  const yesterday = new Date()
  yesterday.setDate(yesterday.getDate() - 1)
  const fromDate = yesterday.toISOString().split('T')[0]

  const response = await axios.get<NewsAPIResponse>('https://newsapi.org/v2/everything', {
    params: {
      q: query,
      language,
      from: fromDate,
      pageSize,
      sortBy: 'publishedAt',
    },
    headers: { 'X-Api-Key': key },
  })

  const articles = response.data.articles.map(a => ({
    title: a.title,
    description: a.description,
    url: a.url,
    urlToImage: a.urlToImage,
    publishedAt: a.publishedAt,
    source: { name: a.source.name },
  }))

  return { articles }
}
