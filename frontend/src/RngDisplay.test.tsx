import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen, waitFor } from '@testing-library/react';
import RngDisplay from './RngDisplay';

function okResponse(value: number) {
  return {
    ok: true,
    status: 200,
    json: () =>
      Promise.resolve({
        value,
        min: 1,
        max: 100,
        timestamp: '2026-06-09T00:00:00+00:00',
      }),
  } as Response;
}

describe('RngDisplay', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn());
  });

  afterEach(() => {
    cleanup();
    vi.unstubAllGlobals();
  });

  it('fetches /api/rng and renders the returned value', async () => {
    vi.mocked(fetch).mockResolvedValue(okResponse(42));

    render(<RngDisplay />);

    expect(await screen.findByText('42')).toBeDefined();
    expect(fetch).toHaveBeenCalledWith('/api/rng');
  });

  it('shows a loading indicator and disables the button while the fetch is in-flight', () => {
    vi.mocked(fetch).mockReturnValue(new Promise(() => {}));

    render(<RngDisplay />);

    expect(screen.getByRole('status').textContent).toContain('Loading');
    expect((screen.getByRole('button', { name: 'Re-roll' }) as HTMLButtonElement).disabled).toBe(
      true,
    );
  });

  it('re-rolls when the button is clicked and renders the new value', async () => {
    vi.mocked(fetch)
      .mockResolvedValueOnce(okResponse(7))
      .mockResolvedValueOnce(okResponse(99));

    render(<RngDisplay />);
    await screen.findByText('7');

    screen.getByRole('button', { name: 'Re-roll' }).click();

    expect(await screen.findByText('99')).toBeDefined();
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it('renders an error message containing the HTTP status code on a non-2xx response', async () => {
    vi.mocked(fetch).mockResolvedValue({ ok: false, status: 500 } as Response);

    render(<RngDisplay />);

    const alert = await screen.findByRole('alert');
    expect(alert.textContent).toContain('500');
  });

  it('re-enables the button once the fetch settles', async () => {
    vi.mocked(fetch).mockResolvedValue(okResponse(13));

    render(<RngDisplay />);
    await screen.findByText('13');

    await waitFor(() => {
      expect(
        (screen.getByRole('button', { name: 'Re-roll' }) as HTMLButtonElement).disabled,
      ).toBe(false);
    });
  });
});
