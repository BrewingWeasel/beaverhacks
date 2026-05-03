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
			console.log("Message (in root)", message);
			if (message.type == "board_created") { 
				router.push('/games/swipegame')
				setBoard([message.full_board, message.local_board, message.division]);
			} else if (message.type == "ran_out_of_time") { 
				console.log("Game over! Final score:", message.score);
				router.push('/games/gameover/' + message.score.toString())
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
