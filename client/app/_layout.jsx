import { Slot } from 'expo-router';
import { SocketProvider } from '../context/SocketContext';
import { BoardProvider } from '../context/BoardContext';
import { useState, useEffect, useContext } from 'react'
import { supabase } from '../lib/supabase'
import Auth from '../components/Auth'

export const UserIdContext = createContext(null);

export default function RootLayout() {
	const [userId, setUserId] = useState(null)

	useEffect(() => {
		supabase.auth.getClaims().then(({ data: { claims } }) => {
			if (claims) {
				setUserId(claims.sub)
			}
		})
		supabase.auth.onAuthStateChange(async (_event, _session) => {
			const {
				data: { claims },
			} = await supabase.auth.getClaims()
			if (claims) {
				setUserId(claims.sub)
			} else {
				setUserId(null)
			}
		})
	}, [])

	const primary_view = userId ? <Slot /> : <Auth />

	return (
		<UserIdContext.Provider value={userId}>
			<SocketProvider>
				<BoardProvider>
					{primary_view}
				</BoardProvider>
			</SocketProvider>
		</UserIdContext.Provider>
	);
}

export const useUserId = () => useContext(UserIdContext);
