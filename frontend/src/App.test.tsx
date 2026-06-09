import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render } from '@testing-library/react';
import App from './App';

describe('App', () => {
  beforeEach(() => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        status: 200,
        json: () =>
          Promise.resolve({
            value: 1,
            min: 1,
            max: 100,
            timestamp: '2026-06-09T00:00:00+00:00',
          }),
      } as Response),
    );
  });

  afterEach(() => {
    cleanup();
    vi.unstubAllGlobals();
  });

  it('renders without crashing', () => {
    const { container } = render(<App />);
    expect(container.querySelector('main')).not.toBeNull();
  });

  it('renders the RngDisplay component', () => {
    const { container } = render(<App />);
    expect(container.querySelector('section')).not.toBeNull();
  });
});
