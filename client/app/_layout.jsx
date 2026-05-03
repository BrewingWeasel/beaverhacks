import { Slot } from 'expo-router';
import { SocketProvider } from '../context/SocketContext';
import { BoardProvider } from '../context/BoardContext';
import { useState, useEffect, createContext, useContext } from 'react'
import { supabase } from '../lib/supabase'
import Auth from '../components/Auth'
 
export const UserIdContext = createContext(null);
 
export default function RootLayout() {
  const [userId, setUserId] = useState(null)
 
  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUserId(session?.user?.id ?? null)
    })
 
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUserId(session?.user?.id ?? null)
    })
 
    return () => subscription.unsubscribe()
  }, [])
 
  return (
    <UserIdContext.Provider value={userId}>
      <SocketProvider>
        <BoardProvider>
          {userId ? <Slot /> : <Auth />}
        </BoardProvider>
      </SocketProvider>
    </UserIdContext.Provider>
  );
}
 
export const useUserId = () => useContext(UserIdContext);

