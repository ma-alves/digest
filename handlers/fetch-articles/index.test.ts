import { mockClient } from 'aws-sdk-client-mock'
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager'
import axios from 'axios'
import { handler } from './index'

const secretsMock = mockClient(SecretsManagerClient)

jest.mock('axios')
const mockedAxios = jest.mocked(axios)

beforeEach(() => {
  secretsMock.reset()
  mockedAxios.mockReset()

  process.env.NEWSAPI_KEY_ARN = 'arn:aws:secretsmanager:us-east-1:123456789012:secret:newsapi-key'
  process.env.SEARCH_QUERY = 'technology'
  process.env.LANGUAGE = 'en'
  process.env.ARTICLE_COUNT = '10'
})

it('returns articles from NewsAPI', async () => {
  secretsMock.on(GetSecretValueCommand).resolves({ SecretString: 'fake-api-key' })

  mockedAxios.get.mockResolvedValue({
    data: {
      status: 'ok',
      totalResults: 2,
      articles: [
        {
          title: 'Article 1',
          description: 'Desc 1',
          url: 'https://example.com/1',
          urlToImage: 'https://example.com/img1.jpg',
          publishedAt: '2025-01-01T00:00:00Z',
          source: { name: 'Source 1' },
        },
        {
          title: 'Article 2',
          description: null,
          url: 'https://example.com/2',
          urlToImage: null,
          publishedAt: '2025-01-02T00:00:00Z',
          source: { name: 'Source 2' },
        },
      ],
    },
  })

  const result = await handler()

  expect(result.articles).toHaveLength(2)
  expect(result.articles[0].title).toBe('Article 1')
  expect(result.articles[0].source.name).toBe('Source 1')
  expect(result.articles[1].description).toBeNull()
})

it('returns empty articles when API returns none', async () => {
  secretsMock.on(GetSecretValueCommand).resolves({ SecretString: 'key' })
  mockedAxios.get.mockResolvedValue({ data: { status: 'ok', totalResults: 0, articles: [] } })

  const result = await handler()

  expect(result.articles).toEqual([])
})

it('throws when NewsAPI request fails', async () => {
  secretsMock.on(GetSecretValueCommand).resolves({ SecretString: 'key' })
  mockedAxios.get.mockRejectedValue(new Error('Network error'))

  await expect(handler()).rejects.toThrow('Network error')
})
