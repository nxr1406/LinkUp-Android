import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { ToastContainer } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';
import { AuthProvider } from './context/AuthContext';
import { Layout } from './components/Layout';

// Pages
import Splash from './pages/Splash';
import Login from './pages/Login';
import Register from './pages/Register';
import ChatList from './pages/ChatList';
import NewChat from './pages/NewChat';
import Settings from './pages/Settings';
import ChatScreen from './pages/ChatScreen';

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Splash />} />
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          
          <Route path="/app" element={<Layout />}>
            <Route index element={<Navigate to="/app/chat" replace />} />
            <Route path="chat" element={<ChatList />} />
            <Route path="new" element={<NewChat />} />
            <Route path="settings" element={<Settings />} />
          </Route>
          
          <Route path="/chat/:chatId" element={<ChatScreen />} />
        </Routes>
        <ToastContainer 
          position="bottom-center"
          autoClose={3000}
          hideProgressBar
          newestOnTop
          closeOnClick
          rtl={false}
          pauseOnFocusLoss
          draggable
          pauseOnHover
          theme="colored"
          aria-label="Notifications"
          toastStyle={{ backgroundColor: '#6C63FF', color: 'white', borderRadius: '12px' }}
        />
      </BrowserRouter>
    </AuthProvider>
  );
}
