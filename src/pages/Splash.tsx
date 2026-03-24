import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { ArrowRight } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function Splash() {
  const navigate = useNavigate();
  const { currentUser, loading } = useAuth();

  useEffect(() => {
    if (!loading) {
      const timer = setTimeout(() => {
        if (currentUser) {
          navigate('/app/chat');
        } else {
          navigate('/login');
        }
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [currentUser, loading, navigate]);

  return (
    <div className="min-h-screen bg-[#6C63FF] flex flex-col items-center justify-center p-6 relative overflow-hidden">
      <motion.div
        initial={{ scale: 0.8, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ duration: 0.8, ease: "easeOut" }}
        className="flex flex-col items-center z-10"
      >
        <div className="w-48 h-48 mb-8">
          <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg" className="w-full h-full text-white fill-current">
            <path d="M45.7,-76.4C58.9,-69.3,69.1,-55.3,77.5,-40.8C85.9,-26.3,92.5,-11.3,90.4,2.6C88.3,16.5,77.5,29.3,66.9,41.2C56.3,53.1,45.9,64.1,32.8,71.4C19.7,78.7,3.9,82.3,-10.7,79.5C-25.3,76.7,-38.7,67.5,-50.2,56.5C-61.7,45.5,-71.3,32.7,-76.7,18.1C-82.1,3.5,-83.3,-12.9,-78.2,-27.1C-73.1,-41.3,-61.7,-53.3,-48.5,-60.6C-35.3,-67.9,-20.3,-70.5,-4.4,-63.4C11.5,-56.3,27.4,-39.5,45.7,-76.4Z" transform="translate(100 100) scale(1.1)" />
            <circle cx="100" cy="100" r="40" fill="#5A52D5" />
            <path d="M85 100 A15 15 0 0 1 115 100" stroke="white" strokeWidth="6" fill="none" strokeLinecap="round" />
            <circle cx="90" cy="90" r="6" fill="white" />
            <circle cx="110" cy="90" r="6" fill="white" />
          </svg>
        </div>
        <motion.h1 
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.3, duration: 0.5 }}
          className="text-5xl font-bold text-white mb-2 tracking-tight"
        >
          LinkUp
        </motion.h1>
        <motion.p 
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.5, duration: 0.5 }}
          className="text-white/80 text-lg font-medium"
        >
          Connect with everyone
        </motion.p>
      </motion.div>

      <motion.button
        initial={{ y: 50, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.8, duration: 0.5 }}
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        onClick={() => navigate(currentUser ? '/app/chat' : '/login')}
        className="absolute bottom-12 bg-white text-[#6C63FF] w-16 h-16 rounded-full flex items-center justify-center shadow-xl"
      >
        <ArrowRight size={28} strokeWidth={2.5} />
      </motion.button>
    </div>
  );
}
