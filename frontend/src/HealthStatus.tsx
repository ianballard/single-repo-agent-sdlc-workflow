import { useEffect, useState } from 'react';

type Status = 'loading' | 'ok' | 'error';

interface HealthState {
  status: Status;
  statusText?: string;
  httpStatus?: number;
}

function HealthStatus() {
  const [health, setHealth] = useState<HealthState>({ status: 'loading' });

  useEffect(() => {
    fetch('/api/health')
      .then((res) => {
        if (!res.ok) {
          setHealth({ status: 'error', httpStatus: res.status });
          return;
        }
        return res.json().then((data: { status: string }) => {
          setHealth({ status: 'ok', statusText: data.status });
        });
      })
      .catch(() => {
        setHealth({ status: 'error' });
      });
  }, []);

  if (health.status === 'loading') {
    return <p aria-busy="true">Loading...</p>;
  }

  if (health.status === 'error') {
    const detail = health.httpStatus != null ? ` (HTTP ${health.httpStatus})` : '';
    return <p>Backend unavailable{detail}</p>;
  }

  return <p>Backend status: {health.statusText}</p>;
}

export default HealthStatus;
