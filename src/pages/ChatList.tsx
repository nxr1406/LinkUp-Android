import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { collection, query, where, onSnapshot, orderBy, getDocs, limit } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { motion } from 'framer-motion';
import { formatDistanceToNow } from 'date-fns';
import { Search, MessageSquare } from 'lucide-react';
import { handleFirestoreError, OperationType } from '../lib/firestore-errors';

interface ChatPreview {
  id: string;
  otherUser: any;
  lastMessage: string;
  lastMessageTime: any;
  unreadCount?: number;
}

export default function ChatList() {
  const { currentUser } = useAuth();
  const navigate = useNavigate();
  const [chats, setChats] = useState<ChatPreview[]>([]);
  const [onlineUsers, setOnlineUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!currentUser) return;

    // Fetch online users
    const usersRef = collection(db, 'users');
    const onlineQuery = query(usersRef, where('isOnline', '==', true), limit(15));
    
    const unsubscribeOnline = onSnapshot(onlineQuery, (snapshot) => {
      const now = new Date();
      const users = snapshot.docs
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .filter(user => user.id !== currentUser.uid)
        .filter(user => {
          // If they don't have a lastSeen timestamp, assume they are offline
          if (!user.lastSeen) return false;
          
          // Calculate minutes since last seen
          const lastSeenDate = user.lastSeen.toDate();
          const diffMinutes = (now.getTime() - lastSeenDate.getTime()) / 60000;
          
          // Consider offline if last seen > 5 minutes ago, even if isOnline is true
          return diffMinutes < 5;
        });
      setOnlineUsers(users);
    }, (error) => {
      handleFirestoreError(error, OperationType.LIST, 'users');
    });

    // Fetch chats
    const chatsRef = collection(db, 'chats');
    const chatsQuery = query(chatsRef, where('participants', 'array-contains', currentUser.uid), orderBy('lastMessageTime', 'desc'));

    const unsubscribeChats = onSnapshot(chatsQuery, async (snapshot) => {
      const chatPromises = snapshot.docs.map(async (chatDoc) => {
        const data = chatDoc.data();
        const otherUserId = data.participants.find((id: string) => id !== currentUser.uid);
        
        // We need to fetch the other user's details
        // In a real app, we might denormalize this or use a cache
        // For now, we'll fetch it once per chat update if needed, or use a separate listener
        // Let's just fetch it once
        const otherUserQuery = query(collection(db, 'users'), where('__name__', '==', otherUserId));
        const otherUserSnap = await getDocs(otherUserQuery);
        const otherUser = otherUserSnap.docs[0]?.data();

        return {
          id: chatDoc.id,
          otherUser: { id: otherUserId, ...otherUser },
          lastMessage: data.lastMessage,
          lastMessageTime: data.lastMessageTime,
        };
      });

      const resolvedChats = await Promise.all(chatPromises);
      setChats(resolvedChats);
      setLoading(false);
    }, (error) => {
      handleFirestoreError(error, OperationType.LIST, 'chats');
      setLoading(false);
    });

    return () => {
      unsubscribeOnline();
      unsubscribeChats();
    };
  }, [currentUser]);

  const isUserOnline = (user: any) => {
    if (!user || !user.isOnline) return false;
    if (!user.lastSeen) return false;
    const now = new Date();
    const lastSeenDate = user.lastSeen.toDate();
    const diffMinutes = (now.getTime() - lastSeenDate.getTime()) / 60000;
    return diffMinutes < 5;
  };

  return (
    <motion.div 
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="min-h-screen bg-gray-50 pt-12 px-6"
    >
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Chat</h1>
        <button 
          onClick={() => navigate('/app/new')}
          className="w-10 h-10 bg-white rounded-full flex items-center justify-center shadow-sm text-gray-600 hover:text-[#6C63FF] transition-colors"
        >
          <Search size={20} />
        </button>
      </div>

      {/* Activities Row */}
      <div className="mb-8">
        <h2 className="text-sm font-semibold text-gray-500 mb-4 uppercase tracking-wider">Activities</h2>
        {onlineUsers.length > 0 ? (
          <div className="flex space-x-4 overflow-x-auto pb-2 scrollbar-hide">
            {onlineUsers.map(user => (
              <div key={user.id} className="flex flex-col items-center flex-shrink-0 cursor-pointer" onClick={() => navigate(`/app/new?userId=${user.id}`)}>
                <div className="relative w-16 h-16 rounded-full p-[2px] bg-gradient-to-tr from-[#6C63FF] to-[#b4b0ff]">
                  <div className="w-full h-full rounded-full border-2 border-white overflow-hidden bg-white">
                    <img src={user.avatarUrl} alt={user.fullName} className="w-full h-full object-cover" />
                  </div>
                  <div className="absolute bottom-0 right-0 w-4 h-4 bg-green-500 border-2 border-white rounded-full"></div>
                </div>
                <span className="text-xs font-medium text-gray-700 mt-2 truncate w-16 text-center">
                  {user.fullName.split(' ')[0]}
                </span>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-sm text-gray-400 italic">No users online right now.</p>
        )}
      </div>

      {/* Chat List */}
      <div>
        <h2 className="text-sm font-semibold text-gray-500 mb-4 uppercase tracking-wider">Messages</h2>
        
        {loading ? (
          <div className="flex justify-center py-10">
            <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-[#6C63FF]"></div>
          </div>
        ) : chats.length > 0 ? (
          <div className="space-y-4">
            {chats.map(chat => (
              <motion.div 
                key={chat.id}
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={() => navigate(`/chat/${chat.id}`)}
                className="flex items-center p-4 bg-white rounded-2xl shadow-[0_2px_10px_rgba(0,0,0,0.02)] cursor-pointer transition-shadow hover:shadow-[0_4px_15px_rgba(0,0,0,0.05)]"
              >
                <div className="relative w-14 h-14 rounded-full overflow-hidden bg-gray-100 flex-shrink-0">
                  <img src={chat.otherUser?.avatarUrl} alt={chat.otherUser?.fullName} className="w-full h-full object-cover" />
                  {isUserOnline(chat.otherUser) && (
                    <div className="absolute bottom-0 right-0 w-3.5 h-3.5 bg-green-500 border-2 border-white rounded-full"></div>
                  )}
                </div>
                
                <div className="ml-4 flex-1 min-w-0">
                  <div className="flex justify-between items-baseline mb-1">
                    <h3 className="text-base font-semibold text-gray-900 truncate pr-2">
                      {chat.otherUser?.fullName || 'Unknown User'}
                    </h3>
                    <span className="text-xs text-gray-400 whitespace-nowrap">
                      {chat.lastMessageTime ? formatDistanceToNow(chat.lastMessageTime.toDate(), { addSuffix: true }) : ''}
                    </span>
                  </div>
                  <p className="text-sm text-gray-500 truncate">
                    {chat.lastMessage || 'No messages yet'}
                  </p>
                </div>
              </motion.div>
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-16 text-center">
            <div className="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mb-4">
              <MessageSquare size={32} className="text-gray-400" />
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-1">No conversations yet</h3>
            <p className="text-sm text-gray-500 max-w-[200px]">
              Tap the plus button below to start chatting with someone.
            </p>
          </div>
        )}
      </div>
    </motion.div>
  );
}
