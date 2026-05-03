import { createContext, useContext, useEffect, useState } from 'react';
import Constants from "expo-constants";
import { isDevice } from 'expo-device';

const SocketContext = createContext(null);

export const SocketProvider = ({ children }) => {
	const [socket, setSocket] = useState(null);

	const hostedUri = 'wss://backend-holy-pine-8273.fly.dev';
	const uri = isDevice ? hostedUri: "ws://" + Constants.expoConfig?.hostUri?.split(':').shift()?.concat(':8000') ??
		hostedUri;


	useEffect(() => {
		console.log(uri)
		const socketInstance = new WebSocket(uri + "/ws");
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
