import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { collection, query, orderBy, onSnapshot, addDoc, serverTimestamp, doc, getDoc, updateDoc, deleteDoc } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { motion, AnimatePresence } from 'framer-motion';
import { format, isToday, isYesterday } from 'date-fns';
import { ArrowLeft, Send, MoreVertical, Edit2, Trash2, XCircle, Smile, CheckCircle2, CheckCircle, Check } from 'lucide-react';
import { handleFirestoreError, OperationType } from '../lib/firestore-errors';
import { toast } from 'react-toastify';
import { cn } from '../lib/utils';

interface Message {
  id: string;
  senderId: string;
  content: string;
  type: string;
  createdAt: any;
  expiresAt: any;
  isDeleted: boolean;
  editedAt: any;
  reactions: Record<string, string>;
  deletedFor: string[];
  status?: 'sending' | 'sent' | 'delivered' | 'seen' | 'failed';
}

const EMOJIS = ['❤️', '😂', '😮', '😢', '👍', '🔥'];

export default function ChatScreen() {
  const { chatId } = useParams<{ chatId: string }>();
  const { currentUser, userData } = useAuth();
  const navigate = useNavigate();
  
  const [messages, setMessages] = useState<Message[]>([]);
  const [pendingMessages, setPendingMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [otherUser, setOtherUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  
  const [selectedMessage, setSelectedMessage] = useState<Message | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [editContent, setEditContent] = useState('');
  
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!chatId || !currentUser) return;

    // Fetch chat details to get other user
    const fetchChatDetails = async () => {
      try {
        const chatDoc = await getDoc(doc(db, 'chats', chatId));
        if (chatDoc.exists()) {
          const data = chatDoc.data();
          const otherUserId = data.participants.find((id: string) => id !== currentUser.uid);
          
          if (otherUserId) {
            const userUnsubscribe = onSnapshot(doc(db, 'users', otherUserId), (userDoc) => {
              if (userDoc.exists()) {
                setOtherUser({ id: userDoc.id, ...userDoc.data() });
              }
            }, (error) => {
              handleFirestoreError(error, OperationType.GET, `users/${otherUserId}`);
            });
            return userUnsubscribe;
          }
        }
      } catch (error) {
        console.error('Error fetching chat details:', error);
      }
    };

    let userUnsubscribe: any;
    fetchChatDetails().then(unsub => { userUnsubscribe = unsub; });

    // Fetch messages
    const msgsRef = collection(db, `messages/${chatId}/msgs`);
    const q = query(msgsRef, orderBy('createdAt', 'asc'));

    const unsubscribeMessages = onSnapshot(q, (snapshot) => {
      const msgs = snapshot.docs.map(doc => {
        const data = doc.data() as Message;
        
        // Mark as seen if it's from the other user and not already seen
        if (data.senderId !== currentUser.uid && data.status !== 'seen') {
          updateDoc(doc.ref, { status: 'seen' }).catch(console.error);
        }
        
        return { id: doc.id, ...data };
      });
      // Filter out messages deleted for this user
      const visibleMsgs = msgs.filter(msg => !msg.deletedFor?.includes(currentUser.uid));
      setMessages(visibleMsgs);
      setLoading(false);
      scrollToBottom();
    }, (error) => {
      handleFirestoreError(error, OperationType.LIST, `messages/${chatId}/msgs`);
      setLoading(false);
    });

    return () => {
      if (userUnsubscribe) userUnsubscribe();
      unsubscribeMessages();
    };
  }, [chatId, currentUser]);

  const scrollToBottom = () => {
    setTimeout(() => {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, 100);
  };

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || !currentUser || !chatId) return;

    const content = newMessage.trim();
    setNewMessage('');

    const now = new Date();
    const expiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000); // 24 hours from now
    
    // Create a temporary ID for the pending message
    const tempId = `temp-${Date.now()}`;
    const pendingMsg: Message = {
      id: tempId,
      senderId: currentUser.uid,
      content,
      type: 'text',
      createdAt: null, // Will be replaced by serverTimestamp
      expiresAt,
      isDeleted: false,
      editedAt: null,
      reactions: {},
      deletedFor: [],
      status: 'sending',
    };
    
    setPendingMessages(prev => [...prev, pendingMsg]);
    scrollToBottom();

    try {
      await addDoc(collection(db, `messages/${chatId}/msgs`), {
        senderId: currentUser.uid,
        content,
        type: 'text',
        createdAt: serverTimestamp(),
        expiresAt,
        isDeleted: false,
        editedAt: null,
        reactions: {},
        deletedFor: [],
        status: 'sent',
      });

      await updateDoc(doc(db, 'chats', chatId), {
        lastMessage: content,
        lastMessageTime: serverTimestamp(),
      });
      
      // Remove from pending
      setPendingMessages(prev => prev.filter(msg => msg.id !== tempId));
      scrollToBottom();
    } catch (error) {
      console.error('Error sending message:', error);
      toast.error('Failed to send message');
      
      // Update pending message to failed
      setPendingMessages(prev => prev.map(msg => 
        msg.id === tempId ? { ...msg, status: 'failed' } : msg
      ));
    }
  };

  const handleEditMessage = async () => {
    if (!selectedMessage || !editContent.trim() || !chatId) return;

    try {
      await updateDoc(doc(db, `messages/${chatId}/msgs`, selectedMessage.id), {
        content: editContent.trim(),
        editedAt: serverTimestamp(),
      });
      
      setIsEditing(false);
      setSelectedMessage(null);
      toast.success('Message edited');
    } catch (error) {
      toast.error('Failed to edit message');
    }
  };

  const handleDeleteForMe = async (msgId: string) => {
    if (!currentUser || !chatId) return;
    try {
      const msgRef = doc(db, `messages/${chatId}/msgs`, msgId);
      const msgDoc = await getDoc(msgRef);
      if (msgDoc.exists()) {
        const deletedFor = msgDoc.data().deletedFor || [];
        await updateDoc(msgRef, {
          deletedFor: [...deletedFor, currentUser.uid]
        });
      }
      setSelectedMessage(null);
    } catch (error) {
      toast.error('Failed to delete message');
    }
  };

  const handleUnsend = async (msgId: string) => {
    if (!chatId) return;
    try {
      await deleteDoc(doc(db, `messages/${chatId}/msgs`, msgId));
      setSelectedMessage(null);
      toast.success('Message unsent');
    } catch (error) {
      toast.error('Failed to unsend message');
    }
  };

  const handleReact = async (msgId: string, emoji: string) => {
    if (!currentUser || !chatId) return;
    try {
      const msgRef = doc(db, `messages/${chatId}/msgs`, msgId);
      const msgDoc = await getDoc(msgRef);
      if (msgDoc.exists()) {
        const reactions = msgDoc.data().reactions || {};
        
        // Toggle reaction
        if (reactions[currentUser.uid] === emoji) {
          delete reactions[currentUser.uid];
        } else {
          reactions[currentUser.uid] = emoji;
        }
        
        await updateDoc(msgRef, { reactions });
      }
      setSelectedMessage(null);
    } catch (error) {
      toast.error('Failed to add reaction');
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#6C63FF]"></div>
      </div>
    );
  }

  const getOnlineStatusText = (user: any) => {
    if (!user) return 'Offline';
    
    const now = new Date();
    const lastSeenDate = user.lastSeen ? user.lastSeen.toDate() : null;
    
    if (user.isOnline && lastSeenDate) {
      const diffMinutes = (now.getTime() - lastSeenDate.getTime()) / 60000;
      if (diffMinutes < 5) {
        return 'Online';
      }
    }
    
    if (!lastSeenDate) return 'Offline';
    
    if (isToday(lastSeenDate)) {
      return `last seen today at ${format(lastSeenDate, 'h:mm a')}`;
    } else if (isYesterday(lastSeenDate)) {
      return `last seen yesterday at ${format(lastSeenDate, 'h:mm a')}`;
    } else {
      return `last seen ${format(lastSeenDate, 'dd/MM/yyyy')} at ${format(lastSeenDate, 'h:mm a')}`;
    }
  };

  const onlineStatusText = getOnlineStatusText(otherUser);
  const isOnline = onlineStatusText === 'Online';

  return (
    <div className="flex flex-col h-screen bg-gray-50 relative">
      {/* Header */}
      <div className="bg-[#6C63FF] text-white pt-safe pb-4 px-4 shadow-md z-20 sticky top-0 flex items-center rounded-b-3xl">
        <button 
          onClick={() => navigate('/app/chat')}
          className="p-2 mr-2 rounded-full hover:bg-white/20 transition-colors"
        >
          <ArrowLeft size={24} />
        </button>
        
        {otherUser && (
          <div className="flex items-center flex-1">
            <div className="relative w-10 h-10 rounded-full overflow-hidden bg-white/20 flex-shrink-0 border-2 border-white/50">
              <img src={otherUser.avatarUrl} alt={otherUser.fullName} className="w-full h-full object-cover" />
            </div>
            <div className="ml-3 flex-1 min-w-0">
              <h2 className="text-base font-bold truncate">{otherUser.fullName}</h2>
              <div className="flex items-center text-xs text-white/80">
                <div className={cn("w-2 h-2 rounded-full mr-1.5", isOnline ? "bg-green-400" : "bg-gray-300")}></div>
                {onlineStatusText}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Messages Area */}
      <div className="flex-1 overflow-y-auto p-4 space-y-6 pb-24">
        {messages.length === 0 && pendingMessages.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full opacity-50">
            <div className="w-20 h-20 bg-gray-200 rounded-full flex items-center justify-center mb-4">
              <Smile size={32} className="text-gray-400" />
            </div>
            <p className="text-gray-500 text-sm">Say hello to start the conversation!</p>
            <p className="text-gray-400 text-xs mt-2 text-center max-w-[200px]">Messages automatically disappear after 24 hours.</p>
          </div>
        ) : (
          [...messages, ...pendingMessages].map((msg, index, allMsgs) => {
            const isMine = msg.senderId === currentUser?.uid;
            const showDate = index === 0 || 
              (msg.createdAt && allMsgs[index - 1].createdAt && 
               format(msg.createdAt.toDate(), 'PP') !== format(allMsgs[index - 1].createdAt.toDate(), 'PP'));

            return (
              <div key={msg.id}>
                {showDate && msg.createdAt && (
                  <div className="flex justify-center my-6">
                    <span className="bg-gray-200 text-gray-500 text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-full">
                      {format(msg.createdAt.toDate(), 'MMMM d, yyyy')}
                    </span>
                  </div>
                )}
                
                <div className={cn("flex w-full mb-2", isMine ? "justify-end" : "justify-start")}>
                  {!isMine && (
                    <div className="flex-shrink-0 mr-2 mt-auto mb-5">
                      <img src={otherUser?.avatarUrl} alt="Profile" className="h-6 w-6 rounded-full object-cover" />
                    </div>
                  )}
                  
                  <div className={cn("flex flex-col", isMine ? "items-end" : "items-start", "max-w-[75%]")}>
                    <motion.div 
                      initial={{ opacity: 0, y: 10, scale: 0.95 }}
                      animate={{ opacity: 1, y: 0, scale: 1 }}
                      className={cn(
                        "relative rounded-2xl px-4 py-3 shadow-sm cursor-pointer",
                        isMine 
                          ? "bg-[#6C63FF] text-white rounded-tr-sm shadow-[0_4px_15px_rgba(108,99,255,0.2)]" 
                          : "bg-white text-gray-800 rounded-tl-sm shadow-[0_2px_10px_rgba(0,0,0,0.04)]"
                      )}
                      onContextMenu={(e) => {
                        e.preventDefault();
                        setSelectedMessage(msg);
                      }}
                      onClick={() => setSelectedMessage(msg)}
                    >
                      <p className="text-[15px] leading-relaxed break-words">{msg.content}</p>
                      
                      {/* Reactions Display */}
                      {Object.keys(msg.reactions || {}).length > 0 && (
                        <div className={cn(
                          "absolute -bottom-3 flex space-x-1 bg-white rounded-full px-2 py-0.5 shadow-md border border-gray-100",
                          isMine ? "right-2" : "left-2"
                        )}>
                          {Object.values(msg.reactions).map((emoji, i) => (
                            <span key={i} className="text-xs">{emoji}</span>
                          ))}
                        </div>
                      )}
                    </motion.div>
                    
                    <div className={cn(
                      "flex items-center mt-1.5 space-x-1 text-[10px] text-gray-400 font-medium",
                      isMine ? "flex-row-reverse space-x-reverse" : "flex-row"
                    )}>
                      <span>{msg.createdAt ? format(msg.createdAt.toDate(), 'h:mm a') : 'Sending...'}</span>
                      {msg.editedAt && <span className="italic">• Edited</span>}
                      {isMine && (
                        <span className="ml-1 flex items-center">
                          {msg.status === 'failed' ? (
                            <XCircle size={12} className="text-red-500" />
                          ) : msg.status === 'seen' ? (
                            <img src={otherUser?.avatarUrl} alt="Seen" className="h-3 w-3 rounded-full object-cover" />
                          ) : msg.status === 'delivered' ? (
                            <CheckCircle2 size={12} className="text-[#6C63FF]" />
                          ) : msg.status === 'sent' || (!msg.status && msg.createdAt) ? (
                            <CheckCircle size={12} className="text-gray-400" />
                          ) : (
                            <div className="w-3 h-3 rounded-full border border-gray-400 border-t-transparent animate-spin"></div>
                          )}
                        </span>
                      )}
                    </div>
                  </div>

                  {isMine && (
                    <div className="flex-shrink-0 ml-2 mt-auto mb-5">
                      <img src={userData?.avatarUrl} alt="Profile" className="h-6 w-6 rounded-full object-cover" />
                    </div>
                  )}
                </div>
              </div>
            );
          })
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Input Area */}
      <div className="bg-white border-t border-gray-100 p-4 pb-safe absolute bottom-0 left-0 right-0 z-10 shadow-[0_-10px_30px_rgba(0,0,0,0.03)]">
        <form onSubmit={handleSendMessage} className="flex items-center space-x-3">
          <div className="flex-1 relative">
            <input
              type="text"
              value={newMessage}
              onChange={(e) => setNewMessage(e.target.value)}
              placeholder="Type a message..."
              className="w-full bg-gray-100 text-gray-800 rounded-full pl-5 pr-12 py-3.5 focus:outline-none focus:ring-2 focus:ring-[#6C63FF]/50 transition-shadow text-[15px]"
            />
          </div>
          <button
            type="submit"
            disabled={!newMessage.trim()}
            className="w-12 h-12 bg-[#6C63FF] rounded-full flex items-center justify-center text-white shadow-lg hover:bg-[#5A52D5] transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex-shrink-0"
          >
            <Send size={20} className="ml-1" />
          </button>
        </form>
      </div>

      {/* Message Options Modal */}
      <AnimatePresence>
        {selectedMessage && !isEditing && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 backdrop-blur-sm sm:items-center p-4"
            onClick={() => setSelectedMessage(null)}
          >
            <motion.div 
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              transition={{ type: "spring", damping: 25, stiffness: 300 }}
              className="bg-white w-full max-w-sm rounded-3xl overflow-hidden shadow-2xl"
              onClick={e => e.stopPropagation()}
            >
              <div className="p-4 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
                <h3 className="font-semibold text-gray-700">Message Options</h3>
                <button onClick={() => setSelectedMessage(null)} className="p-1 text-gray-400 hover:text-gray-600 rounded-full hover:bg-gray-200 transition-colors">
                  <XCircle size={20} />
                </button>
              </div>
              
              {/* Reactions */}
              <div className="p-4 flex justify-between border-b border-gray-100">
                {EMOJIS.map(emoji => (
                  <button 
                    key={emoji}
                    onClick={() => handleReact(selectedMessage.id, emoji)}
                    className="text-2xl hover:scale-125 transition-transform p-2 rounded-full hover:bg-gray-100"
                  >
                    {emoji}
                  </button>
                ))}
              </div>

              <div className="p-2">
                {selectedMessage.senderId === currentUser?.uid && (
                  <>
                    <button 
                      onClick={() => { setIsEditing(true); setEditContent(selectedMessage.content); }}
                      className="w-full flex items-center space-x-3 p-4 hover:bg-gray-50 rounded-2xl transition-colors text-gray-700"
                    >
                      <div className="w-10 h-10 rounded-full bg-blue-50 flex items-center justify-center text-blue-500">
                        <Edit2 size={18} />
                      </div>
                      <span className="font-medium">Edit Message</span>
                    </button>
                    <button 
                      onClick={() => handleUnsend(selectedMessage.id)}
                      className="w-full flex items-center space-x-3 p-4 hover:bg-gray-50 rounded-2xl transition-colors text-red-600"
                    >
                      <div className="w-10 h-10 rounded-full bg-red-50 flex items-center justify-center text-red-500">
                        <Trash2 size={18} />
                      </div>
                      <span className="font-medium">Unsend for Everyone</span>
                    </button>
                  </>
                )}
                <button 
                  onClick={() => handleDeleteForMe(selectedMessage.id)}
                  className="w-full flex items-center space-x-3 p-4 hover:bg-gray-50 rounded-2xl transition-colors text-gray-700"
                >
                  <div className="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center text-gray-500">
                    <Trash2 size={18} />
                  </div>
                  <span className="font-medium">Delete for Me</span>
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Edit Message Modal */}
      <AnimatePresence>
        {isEditing && selectedMessage && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4"
          >
            <motion.div 
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              className="bg-white w-full max-w-sm rounded-3xl p-6 shadow-2xl"
            >
              <h3 className="text-lg font-bold text-gray-900 mb-4">Edit Message</h3>
              <textarea
                value={editContent}
                onChange={(e) => setEditContent(e.target.value)}
                className="w-full p-4 bg-gray-50 border border-gray-200 rounded-2xl focus:ring-2 focus:ring-[#6C63FF] focus:border-transparent resize-none h-32 text-gray-800"
                placeholder="Edit your message..."
              />
              <div className="flex space-x-3 mt-6">
                <button
                  onClick={() => { setIsEditing(false); setSelectedMessage(null); }}
                  className="flex-1 py-3 px-4 rounded-xl bg-gray-100 text-gray-700 font-medium hover:bg-gray-200 transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={handleEditMessage}
                  disabled={!editContent.trim() || editContent === selectedMessage.content}
                  className="flex-1 py-3 px-4 rounded-xl bg-[#6C63FF] text-white font-medium hover:bg-[#5A52D5] transition-colors disabled:opacity-50"
                >
                  Save Changes
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
