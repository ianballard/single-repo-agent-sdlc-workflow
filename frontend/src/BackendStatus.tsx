import { useEffect, useState } from 'react';

type Status = 'loading' | 'online' | 'unavailable';

async function checkHealth(): Promise<Status> {
  const response = await fetch('/api/health');
  if (!response.ok) {
    return 'unavailable';
  }
  const body: unknown = await response.json();
  const status = (body as { status?: unknown })?.status;
  return status === 'ok' ? 'online' : 'unavailable';
}

const MESSAGES: Record<Status, string> = {
  loading: 'Checking backend status…',
  online: 'Backend status: online',
  unavailable: 'Backend status: unavailable',
};

export function BackendStatus() {
  const [status, setStatus] = useState<Status>('loading');

  useEffect(() => {
    let cancelled = false;

    checkHealth()
      .then((result) => {
        if (!cancelled) setStatus(result);
      })
      .catch(() => {
        if (!cancelled) setStatus('unavailable');
      });

    return () => {
      cancelled = true;
    };
  }, []);

  return <p data-testid="backend-status">{MESSAGES[status]}</p>;
}
