import { Outlet, Navigate } from 'react-router-dom';
import { BottomNav } from './BottomNav';
import { useAuth } from '../context/AuthContext';
import { useAutoDelete } from '../hooks/useAutoDelete';
import { useNotifications } from '../hooks/useNotifications';

export function Layout() {
  const { currentUser, loading } = useAuth();
  useAutoDelete();
  useNotifications();

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#6C63FF]"></div>
      </div>
    );
  }

  if (!currentUser) {
    return <Navigate to="/login" replace />;
  }

  return (
    <div className="min-h-screen bg-gray-50 pb-[80px]">
      <Outlet />
      <BottomNav />
    </div>
  );
}
