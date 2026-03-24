import React, { Component, ErrorInfo, ReactNode } from 'react';

interface Props {
  children?: ReactNode;
}

interface State {
  hasError: boolean;
  errorMessage: string;
}

export class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
    errorMessage: ''
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, errorMessage: error.message };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Uncaught error:', error, errorInfo);
  }

  public render() {
    if (this.state.hasError) {
      let parsedError;
      try {
        parsedError = JSON.parse(this.state.errorMessage);
      } catch (e) {
        // Not a JSON error
      }

      const isPermissionError = parsedError?.error?.toLowerCase().includes('permission') || 
                               this.state.errorMessage.toLowerCase().includes('permission');

      return (
        <div className="min-h-screen bg-gray-50 flex flex-col items-center justify-center p-6 text-center">
          <div className="bg-white p-8 rounded-3xl shadow-[0_8px_30px_rgb(0,0,0,0.04)] max-w-lg w-full">
            <div className="w-16 h-16 bg-red-100 text-red-500 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            </div>
            <h1 className="text-2xl font-bold text-gray-900 mb-2">Something went wrong</h1>
            
            {isPermissionError ? (
              <div className="text-left bg-red-50 p-4 rounded-xl mt-4">
                <p className="text-red-800 font-medium mb-2">Firestore Permission Denied</p>
                <p className="text-sm text-red-600 mb-3">
                  Your Firebase Security Rules are blocking this request. You need to update your rules in the Firebase Console.
                </p>
                <div className="bg-white p-3 rounded border border-red-100 overflow-x-auto">
                  <pre className="text-xs text-red-500 font-mono">
                    {parsedError ? JSON.stringify(parsedError, null, 2) : this.state.errorMessage}
                  </pre>
                </div>
              </div>
            ) : (
              <p className="text-gray-600 mb-4">{this.state.errorMessage || 'An unexpected error occurred.'}</p>
            )}
            
            <button
              onClick={() => window.location.reload()}
              className="mt-6 bg-[#6C63FF] text-white px-6 py-3 rounded-xl font-medium hover:bg-[#5A52D5] transition-colors w-full"
            >
              Reload Page
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
