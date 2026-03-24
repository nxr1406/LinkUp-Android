import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { signOut, deleteUser } from 'firebase/auth';
import { doc, deleteDoc, collection, getDocs, query, where, updateDoc, serverTimestamp } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { useAuth } from '../context/AuthContext';
import { compressImage } from '../lib/api';
import { motion } from 'framer-motion';
import { toast } from 'react-toastify';
import { LogOut, Trash2, Download, Edit3, User, Camera, X } from 'lucide-react';
import { cn } from '../lib/utils';

export default function Settings() {
  const { currentUser, userData } = useAuth();
  const navigate = useNavigate();
  
  const [isEditing, setIsEditing] = useState(false);
  const [fullName, setFullName] = useState(userData?.fullName || '');
  const [username, setUsername] = useState(userData?.username || '');
  const [avatar, setAvatar] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState<string | null>(userData?.avatarUrl || null);
  const [loading, setLoading] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

  const handleLogout = async () => {
    try {
      if (currentUser) {
        await updateDoc(doc(db, 'users', currentUser.uid), {
          isOnline: false,
          lastSeen: serverTimestamp(),
        }).catch(() => {}); // Ignore errors if any
        
        // Wait a small amount of time to ensure the write is sent to the server
        // before the auth token is cleared by signOut
        await new Promise(resolve => setTimeout(resolve, 500));
      }
      await signOut(auth);
      navigate('/login');
    } catch (error) {
      toast.error('Failed to logout');
    }
  };

  const handleAvatarChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      setAvatar(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setAvatarPreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleSaveProfile = async () => {
    if (!currentUser) return;
    setLoading(true);
    try {
      let newAvatarUrl = userData?.avatarUrl;
      if (avatar) {
        newAvatarUrl = await compressImage(avatar);
      }

      await updateDoc(doc(db, 'users', currentUser.uid), {
        fullName,
        username,
        avatarUrl: newAvatarUrl,
      });

      toast.success('Profile updated successfully');
      setIsEditing(false);
    } catch (error) {
      toast.error('Failed to update profile');
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteAccount = async () => {
    if (!currentUser) return;
    setLoading(true);
    try {
      // Delete user document
      await deleteDoc(doc(db, 'users', currentUser.uid));
      
      // Delete auth user
      await deleteUser(currentUser);
      
      toast.success('Account deleted permanently');
      navigate('/login');
    } catch (error: any) {
      if (error.code === 'auth/requires-recent-login') {
        toast.error('Please log out and log back in to delete your account.');
      } else {
        toast.error('Failed to delete account');
      }
    } finally {
      setLoading(false);
      setShowDeleteConfirm(false);
    }
  };

  const handleExportData = async () => {
    if (!currentUser || !userData) return;
    setLoading(true);
    try {
      const exportData: any = {
        profile: userData,
        chats: [],
      };

      // Fetch chats
      const chatsRef = collection(db, 'chats');
      const q = query(chatsRef, where('participants', 'array-contains', currentUser.uid));
      const snapshot = await getDocs(q);

      for (const chatDoc of snapshot.docs) {
        const chatData = chatDoc.data();
        const msgsRef = collection(db, `messages/${chatDoc.id}/msgs`);
        const msgsSnapshot = await getDocs(msgsRef);
        
        const messages = msgsSnapshot.docs.map(msgDoc => msgDoc.data());
        
        exportData.chats.push({
          chatId: chatDoc.id,
          participants: chatData.participants,
          messages,
        });
      }

      const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(exportData, null, 2));
      const downloadAnchorNode = document.createElement('a');
      downloadAnchorNode.setAttribute("href", dataStr);
      downloadAnchorNode.setAttribute("download", `linkup_export_${userData.username}.json`);
      document.body.appendChild(downloadAnchorNode);
      downloadAnchorNode.click();
      downloadAnchorNode.remove();

      toast.success('Data exported successfully');
    } catch (error) {
      console.error('Export error:', error);
      toast.error('Failed to export data');
    } finally {
      setLoading(false);
    }
  };

  if (!userData) return null;

  return (
    <motion.div 
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -20 }}
      className="min-h-screen bg-gray-50 pt-12 px-6 pb-24"
    >
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Settings</h1>
      </div>

      {/* Profile Section */}
      <div className="bg-white rounded-3xl p-6 shadow-[0_8px_30px_rgb(0,0,0,0.04)] mb-6 relative overflow-hidden">
        <div className="absolute top-0 left-0 w-full h-24 bg-gradient-to-r from-[#6C63FF] to-[#b4b0ff] opacity-20"></div>
        
        <div className="relative flex flex-col items-center mt-4">
          <div className="relative">
            <div className="w-24 h-24 rounded-full overflow-hidden border-4 border-white shadow-lg bg-gray-100">
              <img src={avatarPreview || userData.avatarUrl} alt={userData.fullName} className="w-full h-full object-cover" />
            </div>
            {isEditing && (
              <label className="absolute bottom-0 right-0 bg-[#6C63FF] p-2 rounded-full text-white cursor-pointer shadow-lg hover:bg-[#5A52D5] transition-colors">
                <Camera size={16} />
                <input type="file" accept="image/*" className="hidden" onChange={handleAvatarChange} />
              </label>
            )}
          </div>

          {isEditing ? (
            <div className="w-full mt-6 space-y-4">
              <div>
                <label className="block text-xs font-medium text-gray-500 uppercase tracking-wider mb-1">Full Name</label>
                <input
                  type="text"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#6C63FF] focus:border-transparent transition-shadow"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-500 uppercase tracking-wider mb-1">Username</label>
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, ''))}
                  className="w-full px-4 py-2 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#6C63FF] focus:border-transparent transition-shadow"
                />
              </div>
              <div className="flex space-x-3 pt-2">
                <button
                  onClick={() => setIsEditing(false)}
                  className="flex-1 py-2 px-4 rounded-xl border border-gray-200 text-gray-600 font-medium hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSaveProfile}
                  disabled={loading}
                  className="flex-1 py-2 px-4 rounded-xl bg-[#6C63FF] text-white font-medium hover:bg-[#5A52D5] transition-colors disabled:opacity-50 flex justify-center items-center"
                >
                  {loading ? <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div> : 'Save'}
                </button>
              </div>
            </div>
          ) : (
            <div className="text-center mt-4 w-full">
              <h2 className="text-xl font-bold text-gray-900">{userData.fullName}</h2>
              <p className="text-sm text-gray-500 mb-1">@{userData.username}</p>
              <p className="text-xs text-gray-400 mb-6">{userData.email}</p>
              
              <button
                onClick={() => setIsEditing(true)}
                className="w-full py-3 px-4 rounded-xl bg-gray-50 text-[#6C63FF] font-medium flex items-center justify-center space-x-2 hover:bg-gray-100 transition-colors"
              >
                <Edit3 size={18} />
                <span>Edit Profile</span>
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Options Section */}
      <div className="space-y-3">
        <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider pl-2 mb-2">Account Options</h3>
        
        <button
          onClick={handleExportData}
          disabled={loading}
          className="w-full flex items-center justify-between p-4 bg-white rounded-2xl shadow-[0_2px_10px_rgba(0,0,0,0.02)] hover:shadow-[0_4px_15px_rgba(0,0,0,0.05)] transition-shadow text-left"
        >
          <div className="flex items-center space-x-3 text-gray-700">
            <div className="w-10 h-10 rounded-full bg-blue-50 flex items-center justify-center text-blue-500">
              <Download size={20} />
            </div>
            <span className="font-medium">Export Data</span>
          </div>
        </button>

        <button
          onClick={handleLogout}
          className="w-full flex items-center justify-between p-4 bg-white rounded-2xl shadow-[0_2px_10px_rgba(0,0,0,0.02)] hover:shadow-[0_4px_15px_rgba(0,0,0,0.05)] transition-shadow text-left"
        >
          <div className="flex items-center space-x-3 text-gray-700">
            <div className="w-10 h-10 rounded-full bg-orange-50 flex items-center justify-center text-orange-500">
              <LogOut size={20} />
            </div>
            <span className="font-medium">Sign Out</span>
          </div>
        </button>

        <button
          onClick={() => setShowDeleteConfirm(true)}
          className="w-full flex items-center justify-between p-4 bg-white rounded-2xl shadow-[0_2px_10px_rgba(0,0,0,0.02)] hover:shadow-[0_4px_15px_rgba(0,0,0,0.05)] transition-shadow text-left"
        >
          <div className="flex items-center space-x-3 text-red-600">
            <div className="w-10 h-10 rounded-full bg-red-50 flex items-center justify-center text-red-500">
              <Trash2 size={20} />
            </div>
            <span className="font-medium">Delete Account</span>
          </div>
        </button>
      </div>

      {/* Delete Confirmation Modal */}
      {showDeleteConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
          <motion.div 
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="bg-white rounded-3xl p-6 w-full max-w-sm shadow-2xl"
          >
            <div className="w-16 h-16 rounded-full bg-red-100 flex items-center justify-center text-red-500 mx-auto mb-4">
              <Trash2 size={32} />
            </div>
            <h3 className="text-xl font-bold text-center text-gray-900 mb-2">Delete Account?</h3>
            <p className="text-center text-gray-500 text-sm mb-6">
              This action cannot be undone. All your data, messages, and profile will be permanently deleted.
            </p>
            <div className="space-y-3">
              <button
                onClick={handleDeleteAccount}
                disabled={loading}
                className="w-full py-3 px-4 rounded-xl bg-red-500 text-white font-medium hover:bg-red-600 transition-colors disabled:opacity-50 flex justify-center items-center"
              >
                {loading ? <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div> : 'Yes, Delete My Account'}
              </button>
              <button
                onClick={() => setShowDeleteConfirm(false)}
                disabled={loading}
                className="w-full py-3 px-4 rounded-xl bg-gray-100 text-gray-700 font-medium hover:bg-gray-200 transition-colors"
              >
                Cancel
              </button>
            </div>
          </motion.div>
        </div>
      )}
    </motion.div>
  );
}
