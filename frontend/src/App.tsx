import { useEffect, useState } from 'react';
import { fetchHealth } from './api/health';

type HealthDisplayState = 'loading' | 'ok' | 'unavailable';

const STATUS_TEXT: Record<HealthDisplayState, string> = {
  loading: 'Checking backend status…',
  ok: 'Backend status: Available',
  unavailable: 'Backend status: Unavailable',
};

function App() {
  const [state, setState] = useState<HealthDisplayState>('loading');

  useEffect(() => {
    let ignore = false;

    fetchHealth()
      .then(() => {
        if (!ignore) setState('ok');
      })
      .catch(() => {
        if (!ignore) setState('unavailable');
      });

    return () => {
      ignore = true;
    };
  }, []);

  return (
    <main>
      <p data-testid="health-status">{STATUS_TEXT[state]}</p>
    </main>
  );
}

export default App;
