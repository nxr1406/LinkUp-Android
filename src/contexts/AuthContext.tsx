import React, { createContext, useContext, useEffect, useState } from 'react';
import { auth, db } from '../firebase';
import { onAuthStateChanged, User } from 'firebase/auth';
import { doc, getDoc, updateDoc, serverTimestamp, collection, query, where, getDocs, writeBatch, onSnapshot } from 'firebase/firestore';
import { handleFirestoreError, OperationType } from '../utils/firestoreErrorHandler';

interface AuthContextType {
  currentUser: User | null;
  userData: any | null;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType>({ currentUser: null, userData: null, loading: true });

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [userData, setUserData] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let userDataUnsubscribe: (() => void) | undefined;

    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setCurrentUser(user);
      if (user) {
        try {
          const docRef = doc(db, 'users', user.uid);
          
          userDataUnsubscribe = onSnapshot(docRef, (docSnap) => {
            if (docSnap.exists()) {
              setUserData(docSnap.data());
            }
          }, (error) => {
            console.error("Error fetching user data:", error);
            handleFirestoreError(error, OperationType.GET, `users/${user.uid}`);
          });

          await updateDoc(docRef, {
            isOnline: true,
            lastSeen: serverTimestamp()
          });
        } catch (error) {
          console.error("Error updating user status:", error);
        }
        
        setLoading(false);

        // Cleanup expired messages (run asynchronously)
        (async () => {
          try {
            const chatsQ = query(collection(db, 'chats'), where('participants', 'array-contains', user.uid));
            const chatsSnap = await getDocs(chatsQ);
            const now = new Date();
            
            for (const chatDoc of chatsSnap.docs) {
              const msgsQ = query(
                collection(db, `messages/${chatDoc.id}/msgs`),
                where('expiresAt', '<=', now)
              );
              const msgsSnap = await getDocs(msgsQ);
              if (!msgsSnap.empty) {
                const batch = writeBatch(db);
                msgsSnap.docs.forEach(msg => batch.delete(msg.ref));
                await batch.commit();
              }
            }
          } catch (e) {
            console.error('Cleanup failed', e);
          }
        })();
      } else {
        if (userDataUnsubscribe) {
          userDataUnsubscribe();
        }
        setUserData(null);
        setLoading(false);
      }
    });

    return () => {
      unsubscribe();
      if (userDataUnsubscribe) {
        userDataUnsubscribe();
      }
    };
  }, []);

  useEffect(() => {
    const handleVisibilityChange = async () => {
      if (currentUser && document.visibilityState === 'hidden') {
        await updateDoc(doc(db, 'users', currentUser.uid), {
          isOnline: false,
          lastSeen: serverTimestamp()
        });
      } else if (currentUser && document.visibilityState === 'visible') {
        await updateDoc(doc(db, 'users', currentUser.uid), {
          isOnline: true,
          lastSeen: serverTimestamp()
        });
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, [currentUser]);

  return (
    <AuthContext.Provider value={{ currentUser, userData, loading }}>
      {!loading && children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
