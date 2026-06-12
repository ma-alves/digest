import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager'
import axios from 'axios'
import type { Article } from 'digest-shared'
import { requireEnv } from 'digest-shared'

const secretsClient = new SecretsManagerClient({})

const NEWSAPI_KEY_ARN = requireEnv('NEWSAPI_KEY_ARN')
const SEARCH_QUERY = requireEnv('SEARCH_QUERY')
const LANGUAGE = requireEnv('LANGUAGE')
const ARTICLE_COUNT = requireEnv('ARTICLE_COUNT')

let cachedKey: string | undefined

async function getApiKey(): Promise<string> {
  if (cachedKey) return cachedKey

  const result = await secretsClient.send(new GetSecretValueCommand({ SecretId: NEWSAPI_KEY_ARN }))
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
  const query = SEARCH_QUERY
  const language = LANGUAGE
  const pageSize = ARTICLE_COUNT

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
