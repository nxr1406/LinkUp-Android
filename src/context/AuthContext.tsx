import React, { createContext, useContext, useEffect, useState } from 'react';
import { onAuthStateChanged, User } from 'firebase/auth';
import { doc, onSnapshot, updateDoc, serverTimestamp } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { handleFirestoreError, OperationType } from '../lib/firestore-errors';

interface UserData {
  fullName: string;
  username: string;
  email: string;
  avatarUrl: string;
  isOnline: boolean;
  lastSeen: any;
  createdAt: any;
}

interface AuthContextType {
  currentUser: User | null;
  userData: UserData | null;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType>({
  currentUser: null,
  userData: null,
  loading: true,
});

export function useAuth() {
  return useContext(AuthContext);
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [userData, setUserData] = useState<UserData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setCurrentUser(user);
      if (!user) {
        setUserData(null);
        setLoading(false);
      }
    });

    return unsubscribe;
  }, []);

  useEffect(() => {
    if (!currentUser) return;

    const userRef = doc(db, 'users', currentUser.uid);
    
    // Set online status initially
    const updatePresence = () => {
      updateDoc(userRef, {
        isOnline: true,
        lastSeen: serverTimestamp(),
      }).catch(console.error);
    };
    
    updatePresence();
    
    // Update presence every 2 minutes to keep lastSeen fresh
    const presenceInterval = setInterval(updatePresence, 2 * 60 * 1000);

    const unsubscribe = onSnapshot(userRef, (doc) => {
      if (doc.exists()) {
        setUserData(doc.data() as UserData);
      }
      setLoading(false);
    }, (error) => {
      console.error('Error listening to user data:', error);
      setLoading(false);
      handleFirestoreError(error, OperationType.GET, `users/${currentUser.uid}`);
    });

    const handleVisibilityChange = () => {
      if (document.visibilityState === 'hidden') {
        updateDoc(userRef, {
          isOnline: false,
          lastSeen: serverTimestamp(),
        }).catch(console.error);
      } else {
        updateDoc(userRef, {
          isOnline: true,
          lastSeen: serverTimestamp(),
        }).catch(console.error);
      }
    };

    const handleBeforeUnload = () => {
      updateDoc(userRef, {
        isOnline: false,
        lastSeen: serverTimestamp(),
      }).catch(console.error);
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    window.addEventListener('beforeunload', handleBeforeUnload);

    return () => {
      clearInterval(presenceInterval);
      unsubscribe();
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      window.removeEventListener('beforeunload', handleBeforeUnload);
      
      // Set offline on unmount only if still authenticated
      if (auth.currentUser) {
        updateDoc(userRef, {
          isOnline: false,
          lastSeen: serverTimestamp(),
        }).catch(() => {});
      }
    };
  }, [currentUser]);

  return (
    <AuthContext.Provider value={{ currentUser, userData, loading }}>
      {!loading && children}
    </AuthContext.Provider>
  );
}
