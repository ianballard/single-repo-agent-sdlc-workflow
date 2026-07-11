import { useEffect, useState } from 'react';
import { fetchHealth } from './api/health';

type BackendState = { kind: 'loading' } | { kind: 'ok'; status: string } | { kind: 'unavailable' };

function App() {
  const [state, setState] = useState<BackendState>({ kind: 'loading' });

  useEffect(() => {
    const controller = new AbortController();

    fetchHealth(controller.signal)
      .then((health) => setState({ kind: 'ok', status: health.status }))
      .catch(() => {
        // Ignore aborts triggered by unmount; surface everything else as
        // an unavailable backend rather than crashing the tree.
        if (controller.signal.aborted) {
          return;
        }
        setState({ kind: 'unavailable' });
      });

    return () => controller.abort();
  }, []);

  let message: string;
  switch (state.kind) {
    case 'loading':
      message = 'Checking backend status…';
      break;
    case 'ok':
      message = `Backend: ${state.status}`;
      break;
    case 'unavailable':
      message = 'Backend: unavailable';
      break;
  }

  return (
    <main>
      <p data-testid="backend-status">{message}</p>
    </main>
  );
}

export default App;
