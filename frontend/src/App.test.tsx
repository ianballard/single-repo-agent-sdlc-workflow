import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import App from './App';

describe('App', () => {
  afterEach(() => {
    cleanup();
    vi.unstubAllGlobals();
  });

  it('renders without crashing', () => {
    const { container } = render(<App />);
    expect(container.querySelector('main')).not.toBeNull();
  });

  it('displays backend status when the health check succeeds', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ status: 'ok' }),
      }),
    );

    render(<App />);

    const status = await screen.findByTestId('backend-status');
    expect(status.textContent).toMatch(/available/i);
  });

  it('displays an unavailable message when the health check fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network error')));

    render(<App />);

    const status = await screen.findByTestId('backend-status');
    expect(status.textContent).toMatch(/unavailable/i);
  });
});
