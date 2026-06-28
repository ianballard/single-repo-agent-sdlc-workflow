import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fetchHealth } from './health';

describe('fetchHealth', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn());
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('returns the parsed status on a successful response', async () => {
    vi.mocked(fetch).mockResolvedValue({
      ok: true,
      json: async () => ({ status: 'ok' }),
    } as Response);

    await expect(fetchHealth()).resolves.toEqual({ status: 'ok' });
    expect(fetch).toHaveBeenCalledWith('/health');
  });

  it('throws on a non-OK response', async () => {
    vi.mocked(fetch).mockResolvedValue({
      ok: false,
      status: 503,
      json: async () => ({}),
    } as Response);

    await expect(fetchHealth()).rejects.toThrow(/503/);
  });

  it('propagates a network failure', async () => {
    vi.mocked(fetch).mockRejectedValue(new Error('network down'));

    await expect(fetchHealth()).rejects.toThrow(/network down/);
  });
});
