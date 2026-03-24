import { useEffect, useRef } from 'react';
import { collection, query, where, onSnapshot } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { toast } from 'react-toastify';
import { useLocation } from 'react-router-dom';
import { handleFirestoreError, OperationType } from '../lib/firestore-errors';

export function useNotifications() {
  const { currentUser } = useAuth();
  const location = useLocation();
  const processedMessageIds = useRef<Set<string>>(new Set());
  const processedReactionIds = useRef<Set<string>>(new Set());
  const activeChatListeners = useRef<Map<string, () => void>>(new Map());

  useEffect(() => {
    if (!currentUser) return;

    const chatsRef = collection(db, 'chats');
    const q = query(chatsRef, where('participants', 'array-contains', currentUser.uid));
    
    const unsubscribeChats = onSnapshot(q, (snapshot) => {
      snapshot.docs.forEach(chatDoc => {
        const chatId = chatDoc.id;
        
        if (!activeChatListeners.current.has(chatId)) {
          const msgsRef = collection(db, `messages/${chatId}/msgs`);
          const unsubscribeMsgs = onSnapshot(msgsRef, (msgSnapshot) => {
            msgSnapshot.docChanges().forEach(change => {
              const msgData = change.doc.data();
              const msgId = change.doc.id;
              
              const isInThisChat = location.pathname === `/chat/${chatId}`;

              // Update status to delivered if we received it and it's not our message
              if (msgData.senderId !== currentUser.uid) {
                const currentStatus = msgData.status || 'sent';
                if (currentStatus === 'sent' && !isInThisChat) {
                  import('firebase/firestore').then(({ updateDoc, doc }) => {
                    updateDoc(doc(db, `messages/${chatId}/msgs`, msgId), {
                      status: 'delivered'
                    }).catch(console.error);
                  });
                }
              }

              if (change.type === 'added') {
                if (msgData.senderId !== currentUser.uid && !processedMessageIds.current.has(msgId)) {
                  processedMessageIds.current.add(msgId);
                  
                  const isRecent = msgData.createdAt && (new Date().getTime() - msgData.createdAt.toDate().getTime() < 10000);
                  
                  if (isRecent && !isInThisChat) {
                    toast.info(`New message received`);
                  }
                }
              }

              if (change.type === 'modified') {
                if (msgData.senderId === currentUser.uid) {
                  const reactions = msgData.reactions || {};
                  const reactionCount = Object.keys(reactions).length;
                  
                  const reactionStateId = `${msgId}-${JSON.stringify(reactions)}`;
                  
                  if (reactionCount > 0 && !processedReactionIds.current.has(reactionStateId)) {
                    processedReactionIds.current.add(reactionStateId);
                    
                    const otherReactions = Object.keys(reactions).filter(uid => uid !== currentUser.uid);
                    if (otherReactions.length > 0 && !isInThisChat) {
                      toast.success(`Someone reacted to your message`);
                    }
                  }
                }
              }
            });
          }, (error) => {
            console.error(`Error listening to messages for chat ${chatId}:`, error);
            handleFirestoreError(error, OperationType.LIST, `messages/${chatId}/msgs`);
          });
          
          activeChatListeners.current.set(chatId, unsubscribeMsgs);
        }
      });
    }, (error) => {
      console.error('Error listening to chats for notifications:', error);
      handleFirestoreError(error, OperationType.LIST, 'chats');
    });

    return () => {
      unsubscribeChats();
      activeChatListeners.current.forEach(unsub => unsub());
      activeChatListeners.current.clear();
    };
  }, [currentUser, location.pathname]);
}
