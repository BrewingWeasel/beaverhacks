import { createContext, useContext, useEffect, useState } from 'react';
import Constants from "expo-constants";

const SocketContext = createContext(null);

export const SocketProvider = ({ children }) => {
	const [socket, setSocket] = useState(null);

	const uri =
		Constants.expoConfig?.hostUri?.split(':').shift()?.concat(':8000') ??
		'todo_server.fly.dev';


	useEffect(() => {
		console.log(uri)
		const socketInstance = new WebSocket("ws://" + uri + "/ws");
		console.log("starting to connect")

		socketInstance.onopen = () => {
			console.log("connected")
			socketInstance.send("ping");
		}

		socketInstance.onerror = (error) => {
			console.log(error)
		}
		setSocket(socketInstance);
	}, []);

	return (
		<SocketContext.Provider value={socket}>
			{children}
		</SocketContext.Provider>
	);
};

export const useSocket = () => useContext(SocketContext);
