export interface Newsletter {
  id: string
  title: string
  articleCount: number
  status: NewsletterStatus
  generatedAt: string
  sentAt?: string
  htmlS3Key: string
  errorMessage?: string
}

export enum NewsletterStatus {
  GENERATED = 'GENERATED',
  SENT = 'SENT',
  FAILED = 'FAILED',
}
