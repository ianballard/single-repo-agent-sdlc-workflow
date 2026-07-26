import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import App from './App';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('App', () => {
  it('renders without crashing', () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: true, json: async () => ({ status: 'ok' }) }),
    );

    const { container } = render(<App />);
    expect(container.querySelector('main')).not.toBeNull();
  });

  it('displays the backend status when the health check succeeds', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: true, json: async () => ({ status: 'ok' }) }),
    );

    render(<App />);

    expect(await screen.findByText('Backend status: Available')).not.toBeNull();
  });

  it('displays an unavailable message when the health check fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('fetch failed')));

    render(<App />);

    expect(await screen.findByText('Backend status: Unavailable')).not.toBeNull();
  });
});
