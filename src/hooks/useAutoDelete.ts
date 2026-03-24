import { useEffect } from 'react';
import { collection, query, where, getDocs, deleteDoc, doc } from 'firebase/firestore';
import { db } from '../firebase';
import { useAuth } from '../context/AuthContext';

export function useAutoDelete() {
  const { currentUser } = useAuth();

  useEffect(() => {
    if (!currentUser) return;

    const cleanupMessages = async () => {
      try {
        // Find all chats user is part of
        const chatsRef = collection(db, 'chats');
        const q = query(chatsRef, where('participants', 'array-contains', currentUser.uid));
        const snapshot = await getDocs(q);

        const now = new Date();

        for (const chatDoc of snapshot.docs) {
          const msgsRef = collection(db, `messages/${chatDoc.id}/msgs`);
          const msgsQuery = query(msgsRef, where('expiresAt', '<=', now));
          const msgsSnapshot = await getDocs(msgsQuery);

          const deletePromises = msgsSnapshot.docs.map((msgDoc) =>
            deleteDoc(doc(db, `messages/${chatDoc.id}/msgs`, msgDoc.id))
          );

          await Promise.all(deletePromises);
        }
      } catch (error) {
        console.error('Error auto-deleting messages:', error);
      }
    };

    cleanupMessages();
  }, [currentUser]);
}
