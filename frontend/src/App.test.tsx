import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import App from './App';

describe('App', () => {
  afterEach(() => {
    cleanup();
    vi.unstubAllGlobals();
  });

  it('displays the backend status when the health check succeeds', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => ({
        ok: true,
        status: 200,
        json: async () => ({ status: 'ok' }),
      })),
    );

    render(<App />);

    expect(await screen.findByText('Backend: ok')).toBeTruthy();
  });

  it('displays an unavailable message when the backend is unreachable', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => {
        throw new TypeError('Failed to fetch');
      }),
    );

    render(<App />);

    expect(await screen.findByText('Backend: unavailable')).toBeTruthy();
  });
});
