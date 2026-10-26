let accessToken: string | null = null
let refreshHandler: (() => Promise<boolean>) | null = null
let unauthorizedHandler: (() => void) | null = null

export function getAccessToken(): string | null {
  return accessToken
}

export function setAccessToken(token: string | null): void {
  accessToken = token
}

export function setRefreshHandler(handler: (() => Promise<boolean>) | null): void {
  refreshHandler = handler
}

export function setUnauthorizedHandler(handler: (() => void) | null): void {
  unauthorizedHandler = handler
}

export async function requestRefresh(): Promise<boolean> {
  if (!refreshHandler) {
    return false
  }
  return refreshHandler()
}

export function notifyUnauthorized(): void {
  unauthorizedHandler?.()
}
