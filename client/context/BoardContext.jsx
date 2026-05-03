import { useContext, useState, createContext, useEffect } from 'react';
import { useRouter } from 'expo-router';
import { useSocket } from './SocketContext';

export const BoardContext = createContext(null);
export const PartyContext = createContext(null);

export const BoardProvider = ({ children }) => {
	const [board, setBoard] = useState(null);
	const [party, setParty] = useState(null);

	const socket = useSocket();
	const router = useRouter();

	useEffect(() => {
		if (!socket) return;
		socket.onmessage = (data) => {
			const message = JSON.parse(data.data ?? data._data);
			console.log("Message (in root)", message);
			if (message.type == "party_created") {
				setParty({ id: message.id, playerId: message.player_id, isLeader: true });
				router.push('/lobby');
			} else if (message.type == "party_joined") {
				setParty({ id: message.id, playerId: message.player_id, isLeader: false });
				router.push('/lobby');
			} else if (message.type == "party_closed") {
				setParty(null);
				setBoard(null);
				router.replace('/');
			} else if (message.type == "board_created") { 
				delete message.type;
				setBoard(message);
				router.push('/games/swipegame')
			} else if (message.type == "ran_out_of_time") { 
				console.log("Game over! Final score:", message.score);
				router.push('/games/gameover/' + message.score.toString())
			}
		};
	}, [socket]);

	return (
		<PartyContext.Provider value={party}>
			<BoardContext.Provider value={board}>
				{children}
			</BoardContext.Provider>
		</PartyContext.Provider>
	);
};

export const useBoard = () => useContext(BoardContext);
export const useParty = () => useContext(PartyContext);
