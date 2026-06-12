import { ScanCommand } from '@aws-sdk/lib-dynamodb'
import type { ScanCommandInput } from '@aws-sdk/lib-dynamodb'
import { getDynamoDBClient } from '../clients/dynamodb'

const ddb = getDynamoDBClient()

export async function scanAll(input: ScanCommandInput): Promise<Record<string, unknown>[]> {
  const items: Record<string, unknown>[] = []
  let lastKey: Record<string, unknown> | undefined

  do {
    const result = await ddb.send(new ScanCommand({
      ...input,
      ExclusiveStartKey: lastKey as any,
    }))
    items.push(...(result.Items ?? []))
    lastKey = result.LastEvaluatedKey as Record<string, unknown> | undefined
  } while (lastKey)

  return items
}
