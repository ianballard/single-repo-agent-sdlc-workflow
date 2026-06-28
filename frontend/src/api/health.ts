export type HealthStatus = { status: string };

/**
 * Fetch the backend health endpoint. Requests are same-origin and proxied to
 * the backend by the Vite dev server (see vite.config.ts). Throws on a non-OK
 * response or a network failure so callers handle all failures in one place.
 */
export async function fetchHealth(): Promise<HealthStatus> {
  const response = await fetch('/health');
  if (!response.ok) {
    throw new Error(`Health request failed with status ${response.status}`);
  }
  return (await response.json()) as HealthStatus;
}
