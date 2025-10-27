import React, { PropsWithChildren } from 'react';

interface State {
  hasError: boolean;
  error?: Error | null;
}

export class ErrorBoundary extends React.Component<PropsWithChildren<{}>, State> {
  constructor(props: {}) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: any) {
    // eslint-disable-next-line no-console
    console.error('Uncaught error in component tree:', error, info);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen flex items-center justify-center bg-gray-50">
          <div className="max-w-xl p-6 bg-white rounded-lg shadow">
            <h2 className="text-xl font-semibold mb-2">Ocorreu um erro</h2>
            <p className="text-sm text-gray-600 mb-4">Veja o console do navegador para mais detalhes.</p>
            <pre className="text-xs text-red-600 whitespace-pre-wrap">{this.state.error?.message}</pre>
          </div>
        </div>
      );
    }

    return this.props.children as React.ReactElement;
  }
}

export default ErrorBoundary;
