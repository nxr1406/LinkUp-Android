import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { createUserWithEmailAndPassword, fetchSignInMethodsForEmail } from 'firebase/auth';
import { doc, setDoc, getDocs, query, collection, where, serverTimestamp } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { compressImage } from '../lib/api';
import { handleFirestoreError, OperationType } from '../lib/firestore-errors';
import { motion } from 'framer-motion';
import { toast } from 'react-toastify';
import { Mail, Lock, User, AtSign, Camera, CheckCircle2, XCircle } from 'lucide-react';
import { cn } from '../lib/utils';

export default function Register() {
  const navigate = useNavigate();
  const [fullName, setFullName] = useState('');
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [avatar, setAvatar] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null);
  
  const [loading, setLoading] = useState(false);
  const [usernameAvailable, setUsernameAvailable] = useState<boolean | null>(null);
  const [checkingUsername, setCheckingUsername] = useState(false);
  
  const [emailAvailable, setEmailAvailable] = useState<boolean | null>(null);
  const [checkingEmail, setCheckingEmail] = useState(false);

  const isFullNameValid = fullName.trim().length >= 2;
  const isUsernameValid = /^[a-z0-9_]{3,15}$/.test(username);
  const isEmailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  const isPasswordValid = password.length >= 8;
  const isAvatarValid = avatar !== null;

  // Check Username Availability
  useEffect(() => {
    if (!isUsernameValid) {
      setUsernameAvailable(null);
      return;
    }

    const checkUsername = async () => {
      setCheckingUsername(true);
      try {
        const q = query(collection(db, 'users'), where('username', '==', username));
        const snapshot = await getDocs(q);
        setUsernameAvailable(snapshot.empty);
      } catch (error: any) {
        const isPermissionError = error.code === 'permission-denied' || 
                                 (error.message && error.message.toLowerCase().includes('permission'));
        
        if (isPermissionError) {
          console.error('Firestore permission denied. You must update your Firestore rules to allow reading the users collection for username validation.');
          setUsernameAvailable(false);
          toast.error('Cannot verify username. Please update Firestore rules to allow public read access to the users collection.');
        } else {
          console.error('Error checking username:', error);
          setUsernameAvailable(false);
          handleFirestoreError(error, OperationType.LIST, 'users');
        }
      } finally {
        setCheckingUsername(false);
      }
    };

    const timeoutId = setTimeout(checkUsername, 500);
    return () => clearTimeout(timeoutId);
  }, [username, isUsernameValid]);

  // Check Email Availability
  useEffect(() => {
    if (!isEmailValid) {
      setEmailAvailable(null);
      return;
    }

    const checkEmail = async () => {
      setCheckingEmail(true);
      try {
        const q = query(collection(db, 'users'), where('email', '==', email.toLowerCase()));
        const snapshot = await getDocs(q);
        setEmailAvailable(snapshot.empty);
      } catch (error: any) {
        const isPermissionError = error.code === 'permission-denied' || 
                                 (error.message && error.message.toLowerCase().includes('permission'));
        
        if (isPermissionError) {
          console.error('Firestore permission denied. You must update your Firestore rules to allow reading the users collection for email validation.');
          setEmailAvailable(false);
          toast.error('Cannot verify email. Please update Firestore rules to allow public read access to the users collection.');
        } else {
          console.error('Error checking email:', error);
          setEmailAvailable(false);
          handleFirestoreError(error, OperationType.LIST, 'users');
        }
      } finally {
        setCheckingEmail(false);
      }
    };

    const timeoutId = setTimeout(checkEmail, 500);
    return () => clearTimeout(timeoutId);
  }, [email, isEmailValid]);

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

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!isFullNameValid || !isUsernameValid || !usernameAvailable || !isEmailValid || !emailAvailable || !isPasswordValid || !isAvatarValid) {
      toast.error('Please fill in all fields correctly');
      return;
    }

    setLoading(true);
    try {
      // 1. Upload avatar
      const avatarUrl = await compressImage(avatar!);

      // 2. Create user auth
      const userCredential = await createUserWithEmailAndPassword(auth, email, password);
      const user = userCredential.user;

      // 3. Save to Firestore
      try {
        await setDoc(doc(db, 'users', user.uid), {
          fullName: fullName.trim(),
          username: username.toLowerCase(),
          email: email.toLowerCase(),
          avatarUrl,
          isOnline: true,
          lastSeen: serverTimestamp(),
          createdAt: serverTimestamp(),
        });
      } catch (error) {
        handleFirestoreError(error, OperationType.WRITE, `users/${user.uid}`);
      }

      toast.success('Account created successfully!');
      navigate('/app/chat');
    } catch (error: any) {
      toast.error(error.message || 'Failed to register');
    } finally {
      setLoading(false);
    }
  };

  return (
    <motion.div 
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -20 }}
      className="min-h-screen bg-gray-50 flex flex-col justify-center px-6 py-12"
    >
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <h2 className="text-center text-3xl font-extrabold text-gray-900 tracking-tight">
          Create an account
        </h2>
        <p className="mt-2 text-center text-sm text-gray-600">
          Join LinkUp today
        </p>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white py-8 px-6 shadow-[0_8px_30px_rgb(0,0,0,0.04)] sm:rounded-2xl sm:px-10">
          <form className="space-y-5" onSubmit={handleRegister}>
            
            {/* Avatar Upload */}
            <div className="flex justify-center">
              <div className="relative">
                <div className={cn(
                  "w-24 h-24 rounded-full overflow-hidden bg-gray-100 border-2 flex items-center justify-center transition-colors",
                  avatar ? "border-[#6C63FF]" : "border-dashed border-gray-300"
                )}>
                  {avatarPreview ? (
                    <img src={avatarPreview} alt="Preview" className="w-full h-full object-cover" />
                  ) : (
                    <User className="w-10 h-10 text-gray-400" />
                  )}
                </div>
                <label className="absolute bottom-0 right-0 bg-[#6C63FF] p-2 rounded-full text-white cursor-pointer shadow-lg hover:bg-[#5A52D5] transition-colors">
                  <Camera size={16} />
                  <input type="file" accept="image/*" className="hidden" onChange={handleAvatarChange} />
                </label>
              </div>
            </div>

            {/* Full Name */}
            <div>
              <label className="block text-sm font-medium text-gray-700">Full Name</label>
              <div className="mt-1 relative rounded-md shadow-sm">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <User className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  type="text"
                  required
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  className={cn(
                    "block w-full pl-10 pr-10 py-3 sm:text-sm rounded-xl border focus:ring-[#6C63FF] focus:border-[#6C63FF] transition-colors",
                    fullName.length > 0 
                      ? isFullNameValid ? "border-green-300" : "border-red-300"
                      : "border-gray-200"
                  )}
                  placeholder="Enter your full name"
                />
                {fullName.length > 0 && (
                  <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
                    {isFullNameValid ? <CheckCircle2 className="h-5 w-5 text-green-500" /> : <XCircle className="h-5 w-5 text-red-500" />}
                  </div>
                )}
              </div>
            </div>

            {/* Username */}
            <div>
              <label className="block text-sm font-medium text-gray-700">Username</label>
              <div className="mt-1 relative rounded-md shadow-sm">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <AtSign className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  type="text"
                  required
                  value={username}
                  onChange={(e) => setUsername(e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, ''))}
                  className={cn(
                    "block w-full pl-10 pr-10 py-3 sm:text-sm rounded-xl border focus:ring-[#6C63FF] focus:border-[#6C63FF] transition-colors",
                    username.length > 0 
                      ? usernameAvailable && isUsernameValid ? "border-green-300" : "border-red-300"
                      : "border-gray-200"
                  )}
                  placeholder="Enter your username"
                />
                {username.length > 0 && (
                  <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
                    {checkingUsername ? (
                      <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-b-2 border-gray-400"></div>
                    ) : usernameAvailable && isUsernameValid ? (
                      <CheckCircle2 className="h-5 w-5 text-green-500" />
                    ) : (
                      <XCircle className="h-5 w-5 text-red-500" />
                    )}
                  </div>
                )}
              </div>
              {username.length > 0 && !isUsernameValid && (
                <p className="mt-1 text-xs text-red-500">3-15 chars, lowercase, numbers, underscores only.</p>
              )}
              {username.length > 0 && isUsernameValid && usernameAvailable === false && (
                <p className="mt-1 text-xs text-red-500">Username is already taken.</p>
              )}
            </div>

            {/* Email */}
            <div>
              <label className="block text-sm font-medium text-gray-700">Email address</label>
              <div className="mt-1 relative rounded-md shadow-sm">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <Mail className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className={cn(
                    "block w-full pl-10 pr-10 py-3 sm:text-sm rounded-xl border focus:ring-[#6C63FF] focus:border-[#6C63FF] transition-colors",
                    email.length > 0 
                      ? emailAvailable && isEmailValid ? "border-green-300" : "border-red-300"
                      : "border-gray-200"
                  )}
                  placeholder="Enter your email address"
                />
                {email.length > 0 && (
                  <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
                    {checkingEmail ? (
                      <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-b-2 border-gray-400"></div>
                    ) : emailAvailable && isEmailValid ? (
                      <CheckCircle2 className="h-5 w-5 text-green-500" />
                    ) : (
                      <XCircle className="h-5 w-5 text-red-500" />
                    )}
                  </div>
                )}
              </div>
              {email.length > 0 && isEmailValid && emailAvailable === false && (
                <p className="mt-1 text-xs text-red-500">Email is already registered.</p>
              )}
            </div>

            {/* Password */}
            <div>
              <label className="block text-sm font-medium text-gray-700">Password</label>
              <div className="mt-1 relative rounded-md shadow-sm">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <Lock className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className={cn(
                    "block w-full pl-10 pr-10 py-3 sm:text-sm rounded-xl border focus:ring-[#6C63FF] focus:border-[#6C63FF] transition-colors",
                    password.length > 0 
                      ? isPasswordValid ? "border-green-300" : "border-red-300"
                      : "border-gray-200"
                  )}
                  placeholder="Enter your password"
                />
                {password.length > 0 && (
                  <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
                    {isPasswordValid ? <CheckCircle2 className="h-5 w-5 text-green-500" /> : <XCircle className="h-5 w-5 text-red-500" />}
                  </div>
                )}
              </div>
              {password.length > 0 && !isPasswordValid && (
                <p className="mt-1 text-xs text-red-500">Password must be at least 8 characters.</p>
              )}
            </div>

            <div>
              <button
                type="submit"
                disabled={loading || !isFullNameValid || !isUsernameValid || !usernameAvailable || !isEmailValid || !emailAvailable || !isPasswordValid || !isAvatarValid}
                className="w-full flex justify-center py-3 px-4 border border-transparent rounded-xl shadow-sm text-sm font-medium text-white bg-[#6C63FF] hover:bg-[#5A52D5] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#6C63FF] disabled:opacity-50 disabled:cursor-not-allowed transition-all"
              >
                {loading ? (
                  <div className="animate-spin rounded-full h-5 w-5 border-t-2 border-b-2 border-white"></div>
                ) : (
                  'Create Account'
                )}
              </button>
            </div>
          </form>

          <div className="mt-6 text-center">
            <p className="text-sm text-gray-600">
              Already have an account?{' '}
              <Link to="/login" className="font-medium text-[#6C63FF] hover:text-[#5A52D5]">
                Sign in
              </Link>
            </p>
          </div>
        </div>
      </div>
    </motion.div>
  );
}
