import { useContext, useState, createContext, useEffect } from 'react';
import { useRouter } from 'expo-router';
import { useSocket } from './SocketContext';

export const BoardContext = createContext(null);

export const BoardProvider = ({ children }) => {
	const [board, setBoard] = useState(null);

	const socket = useSocket();
	const router = useRouter();

	useEffect(() => {
		if (!socket) return;
		socket.onmessage = (data) => {
			const message = JSON.parse(data._data);
			if (message.type == "board_created") { 
				delete message.type;
				setBoard(message);
				router.push('/games/swipegame')
			}
		};
	}, [socket, board]);

	return (
		<BoardContext.Provider value={board}>
			{children}
		</BoardContext.Provider>
	);
};

export const useBoard = () => useContext(BoardContext);
