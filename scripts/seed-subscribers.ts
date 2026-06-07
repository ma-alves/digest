import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb'
import { ulid } from 'ulid'

const client = new DynamoDBClient({})
const ddb = DynamoDBDocumentClient.from(client)
const TABLE_NAME = process.env.SUBSCRIBERS_TABLE ?? 'digest-subscribers'

const subscribers = [
  { email: 'alice@example.com' },
  { email: 'bob@example.com' },
  { email: 'carol@example.com' },
  { email: 'dave@example.com' },
  { email: 'eve@example.com' },
]

async function seed(): Promise<void> {
  console.log(`Seeding ${subscribers.length} subscribers into ${TABLE_NAME}...`)

  for (const sub of subscribers) {
    try {
      await ddb.send(new PutCommand({
        TableName: TABLE_NAME,
        Item: {
          email: sub.email,
          id: ulid(),
          createdAt: new Date().toISOString(),
          status: 'SUBSCRIBED',
        },
        ConditionExpression: 'attribute_not_exists(email)',
      }))
      console.log(`  + ${sub.email}`)
    } catch (err: unknown) {
      const known = err as { name?: string }
      if (known.name === 'ConditionalCheckFailedException') {
        console.log(`  ~ ${sub.email} (already exists)`)
      } else {
        console.error(`  ! ${sub.email}: ${known.name ?? err}`)
      }
    }
  }

  console.log('Done.')
}

await seed()
