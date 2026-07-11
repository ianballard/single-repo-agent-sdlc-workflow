import { useEffect, useState } from 'react';

type HealthStatus = 'loading' | 'ok' | 'unavailable';

const STATUS_TEXT: Record<HealthStatus, string> = {
  loading: 'Checking backend status…',
  ok: 'Backend is available',
  unavailable: 'Backend is unavailable',
};

function App() {
  const [status, setStatus] = useState<HealthStatus>('loading');

  useEffect(() => {
    let cancelled = false;

    fetch('/api/health')
      .then((response) => {
        if (!response.ok) throw new Error(`Unexpected status ${response.status}`);
        return response.json();
      })
      .then((data: unknown) => {
        if (cancelled) return;
        const isOk =
          typeof data === 'object' &&
          data !== null &&
          (data as { status?: unknown }).status === 'ok';
        setStatus(isOk ? 'ok' : 'unavailable');
      })
      .catch(() => {
        if (!cancelled) setStatus('unavailable');
      });

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <main>
      <p data-testid="backend-status">{STATUS_TEXT[status]}</p>
    </main>
  );
}

export default App;
