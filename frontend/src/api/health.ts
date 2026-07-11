export interface HealthResponse {
  status: string;
}

/**
 * Fetch the backend health status via the same-origin `/api` proxy.
 *
 * Resolves with the parsed health payload on a 2xx response. Rejects if the
 * backend is unreachable (network error), responds with a non-OK status, or
 * returns a body without a `status` string — so callers can render an
 * unavailable state instead of surfacing a malformed payload.
 */
export async function fetchHealth(signal?: AbortSignal): Promise<HealthResponse> {
  const response = await fetch('/api/health', { signal });
  if (!response.ok) {
    throw new Error(`Health request failed with status ${response.status}`);
  }
  const body = (await response.json()) as Partial<HealthResponse>;
  if (typeof body.status !== 'string') {
    throw new Error('Health response missing status field');
  }
  return { status: body.status };
}
