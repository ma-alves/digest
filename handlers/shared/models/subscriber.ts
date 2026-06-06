export interface Subscriber {
  email: string
  id: string
  createdAt: string
  status: SubscriberStatus
}

export enum SubscriberStatus {
  SUBSCRIBED = 'SUBSCRIBED',
  UNSUBSCRIBED = 'UNSUBSCRIBED'
}