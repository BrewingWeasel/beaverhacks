import { Slot } from 'expo-router';
import { SocketProvider } from '../context/SocketContext';
import { BoardProvider } from '../context/BoardContext';

export default function RootLayout() {
	return (
		<SocketProvider>
			<BoardProvider>
				<Slot />
			</BoardProvider>
		</SocketProvider>
	);
}
