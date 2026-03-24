import { NavLink } from 'react-router-dom';
import { MessageCircle, PlusCircle, Settings } from 'lucide-react';
import { cn } from '../lib/utils';

export function BottomNav() {
  return (
    <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-100 pb-safe pt-2 px-6 flex justify-between items-center shadow-[0_-4px_20px_rgba(0,0,0,0.05)] z-50">
      <NavLink
        to="/app/chat"
        className={({ isActive }) =>
          cn(
            "flex flex-col items-center p-2 transition-colors",
            isActive ? "text-[#6C63FF]" : "text-gray-400 hover:text-gray-600"
          )
        }
      >
        <MessageCircle size={24} />
        <span className="text-[10px] mt-1 font-medium">Chat</span>
      </NavLink>

      <NavLink
        to="/app/new"
        className={({ isActive }) =>
          cn(
            "flex flex-col items-center justify-center w-14 h-14 rounded-full -mt-6 shadow-lg transition-transform hover:scale-105",
            isActive ? "bg-[#5A52D5]" : "bg-[#6C63FF]"
          )
        }
      >
        <PlusCircle size={28} className="text-white" />
      </NavLink>

      <NavLink
        to="/app/settings"
        className={({ isActive }) =>
          cn(
            "flex flex-col items-center p-2 transition-colors",
            isActive ? "text-[#6C63FF]" : "text-gray-400 hover:text-gray-600"
          )
        }
      >
        <Settings size={24} />
        <span className="text-[10px] mt-1 font-medium">Settings</span>
      </NavLink>
    </div>
  );
}
