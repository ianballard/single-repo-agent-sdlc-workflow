import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import App from './App';

describe('App', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn());
  });

  afterEach(() => {
    cleanup();
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('renders without crashing', () => {
    vi.mocked(fetch).mockResolvedValue({
      ok: true,
      json: async () => ({ status: 'ok' }),
    } as Response);
    const { container } = render(<App />);
    expect(container.querySelector('main')).not.toBeNull();
  });

  it('displays the backend status when the health check succeeds', async () => {
    vi.mocked(fetch).mockResolvedValue({
      ok: true,
      json: async () => ({ status: 'ok' }),
    } as Response);

    render(<App />);

    const status = await screen.findByTestId('backend-status');
    expect(status.textContent).toMatch(/backend status: ok/i);
  });

  it('displays an unavailable message when the backend is unreachable', async () => {
    vi.mocked(fetch).mockRejectedValue(new Error('network down'));

    render(<App />);

    expect(await screen.findByText(/backend unavailable/i)).toBeTruthy();
  });
});
