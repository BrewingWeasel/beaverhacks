import { Slot } from 'expo-router';
import { SocketProvider } from '../context/SocketContext';

export default function RootLayout() {
	return (
		<SocketProvider>
			<Slot />
		</SocketProvider>
	);
}
