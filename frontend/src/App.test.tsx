import { describe, expect, it, vi, afterEach } from 'vitest';
import { render, screen, waitFor, cleanup } from '@testing-library/react';
import App from './App';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

describe('App', () => {
  it('renders without crashing', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(() =>
        Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ status: 'ok' }),
        } as Response),
      ),
    );
    const { container } = render(<App />);
    expect(container.querySelector('main')).not.toBeNull();
  });

  it('shows backend status when fetch succeeds', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(() =>
        Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ status: 'ok' }),
        } as Response),
      ),
    );
    render(<App />);
    await waitFor(() => {
      expect(screen.getByText('Backend status: ok')).toBeTruthy();
    });
  });

  it('shows unavailable message when fetch returns 503', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(() =>
        Promise.resolve({
          ok: false,
          status: 503,
        } as Response),
      ),
    );
    render(<App />);
    await waitFor(() => {
      expect(screen.getByText('Backend unavailable (HTTP 503)')).toBeTruthy();
    });
  });
});
