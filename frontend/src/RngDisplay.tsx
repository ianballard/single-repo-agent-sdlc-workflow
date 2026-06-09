import { useCallback, useEffect, useState } from 'react';

interface RngResult {
  value: number;
  min: number;
  max: number;
  timestamp: string;
}

type RngState =
  | { status: 'loading' }
  | { status: 'success'; result: RngResult }
  | { status: 'error'; message: string };

function RngDisplay() {
  const [state, setState] = useState<RngState>({ status: 'loading' });

  const roll = useCallback(async () => {
    setState({ status: 'loading' });
    try {
      const response = await fetch('/api/rng');
      if (!response.ok) {
        setState({
          status: 'error',
          message: `Error: request failed with status ${response.status}`,
        });
        return;
      }
      const result: RngResult = await response.json();
      setState({ status: 'success', result });
    } catch {
      setState({ status: 'error', message: 'Error: request failed' });
    }
  }, []);

  useEffect(() => {
    void roll();
  }, [roll]);

  return (
    <section>
      <h2>Random Number</h2>
      {state.status === 'loading' && <p role="status">Loading…</p>}
      {state.status === 'success' && <p>{state.result.value}</p>}
      {state.status === 'error' && <p role="alert">{state.message}</p>}
      <button type="button" onClick={() => void roll()} disabled={state.status === 'loading'}>
        Re-roll
      </button>
    </section>
  );
}

export default RngDisplay;
