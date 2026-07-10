import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen, waitFor } from '@testing-library/react';
import { BackendStatus } from './BackendStatus';

describe('BackendStatus', () => {
  afterEach(() => {
    cleanup();
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it('displays online status when the health check succeeds', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ status: 'ok' }),
      }),
    );

    render(<BackendStatus />);

    await waitFor(() => {
      expect(screen.getByTestId('backend-status').textContent).toBe('Backend status: online');
    });
  });

  it('displays an unavailable message when the health check fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network error')));

    render(<BackendStatus />);

    await waitFor(() => {
      expect(screen.getByTestId('backend-status').textContent).toBe('Backend status: unavailable');
    });
  });
});
