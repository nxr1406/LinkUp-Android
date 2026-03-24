import React, { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { collection, query, where, getDocs, addDoc, serverTimestamp, or, and } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { motion } from 'framer-motion';
import { Search, UserPlus, X } from 'lucide-react';
import { toast } from 'react-toastify';

export default function NewChat() {
  const { currentUser } = useAuth();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const initialUserId = searchParams.get('userId');
  
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (initialUserId) {
      handleStartChat(initialUserId);
    }
  }, [initialUserId]);

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!searchQuery.trim() || !currentUser) return;

    setLoading(true);
    try {
      const usersRef = collection(db, 'users');
      // Firestore doesn't support full-text search natively well, 
      // so we'll do a simple exact match or prefix match if possible, 
      // or just fetch all and filter client-side for this prototype if it's small.
      // For better performance, we'll query by username exactly, and also fetch all to filter by fullName.
      // Since it's a prototype, let's fetch all users (limit 50) and filter client-side for simplicity.
      
      const q = query(usersRef);
      const snapshot = await getDocs(q);
      
      const results = snapshot.docs
        .map(doc => ({ id: doc.id, ...doc.data() as any }))
        .filter(user => user.id !== currentUser.uid)
        .filter(user => 
          user.username.toLowerCase().includes(searchQuery.toLowerCase()) || 
          user.fullName.toLowerCase().includes(searchQuery.toLowerCase())
        );

      setSearchResults(results);
    } catch (error) {
      console.error('Error searching users:', error);
      toast.error('Failed to search users');
    } finally {
      setLoading(false);
    }
  };

  const handleStartChat = async (otherUserId: string) => {
    if (!currentUser) return;
    
    try {
      // Check if chat already exists
      const chatsRef = collection(db, 'chats');
      
      // Query where participants array contains currentUser.uid
      const q = query(chatsRef, where('participants', 'array-contains', currentUser.uid));
      const snapshot = await getDocs(q);
      
      let existingChatId = null;
      
      for (const doc of snapshot.docs) {
        const participants = doc.data().participants;
        if (participants.includes(otherUserId)) {
          existingChatId = doc.id;
          break;
        }
      }

      if (existingChatId) {
        navigate(`/chat/${existingChatId}`);
      } else {
        // Create new chat
        const newChatRef = await addDoc(collection(db, 'chats'), {
          participants: [currentUser.uid, otherUserId],
          lastMessage: '',
          lastMessageTime: serverTimestamp(),
          createdAt: serverTimestamp(),
        });
        
        navigate(`/chat/${newChatRef.id}`);
      }
    } catch (error) {
      console.error('Error starting chat:', error);
      toast.error('Failed to start chat');
    }
  };

  return (
    <motion.div 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      className="min-h-screen bg-gray-50 pt-12 px-6"
    >
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-900">New Chat</h1>
      </div>

      <form onSubmit={handleSearch} className="mb-8 relative">
        <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
          <Search className="h-5 w-5 text-gray-400" />
        </div>
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Search by name or username..."
          className="block w-full pl-12 pr-12 py-4 bg-white border-none rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.04)] focus:ring-2 focus:ring-[#6C63FF] transition-shadow text-gray-900 placeholder-gray-400"
        />
        {searchQuery && (
          <button
            type="button"
            onClick={() => { setSearchQuery(''); setSearchResults([]); }}
            className="absolute inset-y-0 right-0 pr-4 flex items-center text-gray-400 hover:text-gray-600"
          >
            <X className="h-5 w-5" />
          </button>
        )}
      </form>

      <div>
        {loading ? (
          <div className="flex justify-center py-10">
            <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-[#6C63FF]"></div>
          </div>
        ) : searchResults.length > 0 ? (
          <div className="space-y-4">
            <h2 className="text-sm font-semibold text-gray-500 mb-4 uppercase tracking-wider">Results</h2>
            {searchResults.map(user => (
              <motion.div 
                key={user.id}
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={() => handleStartChat(user.id)}
                className="flex items-center p-4 bg-white rounded-2xl shadow-[0_2px_10px_rgba(0,0,0,0.02)] cursor-pointer transition-shadow hover:shadow-[0_4px_15px_rgba(0,0,0,0.05)]"
              >
                <div className="w-14 h-14 rounded-full overflow-hidden bg-gray-100 flex-shrink-0">
                  <img src={user.avatarUrl} alt={user.fullName} className="w-full h-full object-cover" />
                </div>
                
                <div className="ml-4 flex-1">
                  <h3 className="text-base font-semibold text-gray-900">{user.fullName}</h3>
                  <p className="text-sm text-gray-500">@{user.username}</p>
                </div>
                
                <div className="w-10 h-10 rounded-full bg-gray-50 flex items-center justify-center text-[#6C63FF]">
                  <UserPlus size={20} />
                </div>
              </motion.div>
            ))}
          </div>
        ) : searchQuery ? (
          <div className="flex flex-col items-center justify-center py-16 text-center">
            <div className="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mb-4">
              <Search size={32} className="text-gray-400" />
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-1">No users found</h3>
            <p className="text-sm text-gray-500 max-w-[200px]">
              We couldn't find anyone matching "{searchQuery}".
            </p>
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-16 text-center opacity-50">
            <Search size={48} className="text-gray-300 mb-4" />
            <p className="text-sm text-gray-400">Search for friends to start chatting</p>
          </div>
        )}
      </div>
    </motion.div>
  );
}
