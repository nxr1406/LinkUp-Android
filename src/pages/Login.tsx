import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { signInWithEmailAndPassword, sendPasswordResetEmail } from 'firebase/auth';
import { auth } from '../firebase';
import { motion } from 'framer-motion';
import { toast } from 'react-toastify';
import { Mail, Lock, CheckCircle2, XCircle } from 'lucide-react';
import { cn } from '../lib/utils';

export default function Login() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [resetLoading, setResetLoading] = useState(false);

  const isEmailValid = email.includes('@') && email.includes('.');
  const isPasswordValid = password.length >= 8;

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!isEmailValid || !isPasswordValid) {
      toast.error('Please fill in all fields correctly');
      return;
    }

    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email, password);
      navigate('/app/chat');
    } catch (error: any) {
      toast.error(error.message || 'Failed to login');
    } finally {
      setLoading(false);
    }
  };

  const handleResetPassword = async (e: React.MouseEvent) => {
    e.preventDefault();
    if (!isEmailValid) {
      toast.error('Please enter a valid email address first to reset your password');
      return;
    }
    
    setResetLoading(true);
    try {
      await sendPasswordResetEmail(auth, email);
      toast.success('Password reset email sent! Check your inbox.');
    } catch (error: any) {
      toast.error(error.message || 'Failed to send password reset email');
    } finally {
      setResetLoading(false);
    }
  };

  return (
    <motion.div 
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: 20 }}
      className="min-h-screen bg-gray-50 flex flex-col justify-center px-6 py-12"
    >
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <h2 className="text-center text-3xl font-extrabold text-gray-900 tracking-tight">
          Welcome back
        </h2>
        <p className="mt-2 text-center text-sm text-gray-600">
          Sign in to continue to LinkUp
        </p>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white py-8 px-6 shadow-[0_8px_30px_rgb(0,0,0,0.04)] sm:rounded-2xl sm:px-10">
          <form className="space-y-6" onSubmit={handleLogin}>
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
                      ? isEmailValid ? "border-green-300" : "border-red-300"
                      : "border-gray-200"
                  )}
                  placeholder="Enter your email address"
                />
                {email.length > 0 && (
                  <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
                    {isEmailValid ? (
                      <CheckCircle2 className="h-5 w-5 text-green-500" />
                    ) : (
                      <XCircle className="h-5 w-5 text-red-500" />
                    )}
                  </div>
                )}
              </div>
            </div>

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
                    {isPasswordValid ? (
                      <CheckCircle2 className="h-5 w-5 text-green-500" />
                    ) : (
                      <XCircle className="h-5 w-5 text-red-500" />
                    )}
                  </div>
                )}
              </div>
            </div>

            <div className="flex items-center justify-end">
              <div className="text-sm">
                <button 
                  type="button"
                  onClick={handleResetPassword}
                  disabled={resetLoading}
                  className="font-medium text-[#6C63FF] hover:text-[#5A52D5] disabled:opacity-50"
                >
                  {resetLoading ? 'Sending...' : 'Forgot your password?'}
                </button>
              </div>
            </div>

            <div>
              <button
                type="submit"
                disabled={loading || !isEmailValid || !isPasswordValid}
                className="w-full flex justify-center py-3 px-4 border border-transparent rounded-xl shadow-sm text-sm font-medium text-white bg-[#6C63FF] hover:bg-[#5A52D5] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#6C63FF] disabled:opacity-50 disabled:cursor-not-allowed transition-all"
              >
                {loading ? (
                  <div className="animate-spin rounded-full h-5 w-5 border-t-2 border-b-2 border-white"></div>
                ) : (
                  'Sign in'
                )}
              </button>
            </div>
          </form>

          <div className="mt-6 text-center">
            <p className="text-sm text-gray-600">
              Don't have an account?{' '}
              <Link to="/register" className="font-medium text-[#6C63FF] hover:text-[#5A52D5]">
                Sign up
              </Link>
            </p>
          </div>
        </div>
      </div>
    </motion.div>
  );
}
