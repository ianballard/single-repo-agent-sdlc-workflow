import { useEffect, useState } from 'react';
import { fetchHealth } from './api/health';

type BackendState =
  | { kind: 'loading' }
  | { kind: 'ok'; status: string }
  | { kind: 'error' };

function App() {
  const [state, setState] = useState<BackendState>({ kind: 'loading' });

  useEffect(() => {
    let active = true;
    fetchHealth()
      .then((health) => {
        if (active) setState({ kind: 'ok', status: health.status });
      })
      .catch(() => {
        if (active) setState({ kind: 'error' });
      });
    return () => {
      active = false;
    };
  }, []);

  return (
    <main>
      {state.kind === 'loading' && <p>Checking backend status…</p>}
      {state.kind === 'ok' && (
        <p data-testid="backend-status">Backend status: {state.status}</p>
      )}
      {state.kind === 'error' && (
        <p data-testid="backend-status">Backend unavailable</p>
      )}
    </main>
  );
}

export default App;
