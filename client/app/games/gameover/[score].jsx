import { Text, View, StyleSheet, TouchableOpacity } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';

export default function HomeScreen() {
	const router = useRouter();
	const local = useLocalSearchParams();

	const start = () => {
		router.push('/lobby');
	}
	const score = local.score;

	return (
		<View style={[styles.container]}>
			<View style={styles.header}>
				<Text style={styles.title}>Score: {score}</Text>
			</View>
			<View style={styles.content}>
				<TouchableOpacity
					style={styles.button}
					onPress={start}
				>
					<Text style={styles.buttonText}>Return To Party Menu</Text>
				</TouchableOpacity>
			</View>
		</View>
	);
}

const styles = StyleSheet.create({
	container: {
		flex: 1,
		backgroundColor: '#f8f9fa',
	},
	header: {
		padding: 20,
		backgroundColor: '#D73F09',
		alignItems: 'center',
	},
	title: {
		color: '#D73F09',
		fontSize: 24,
		fontWeight: 'bold',
	},
	content: {
		flex: 1,
		justifyContent: 'center',
		alignItems: 'center',
		padding: 20,
	},
	subtitle: {
		fontSize: 18,
		color: '#333',
		marginBottom: 20,
	},
	button: {
		backgroundColor: '#D73F09',
		paddingVertical: 12,
		paddingHorizontal: 30,
		borderRadius: 8,
	},
	buttonText: {
		color: '#fff',
		fontSize: 16,
		fontWeight: '600',
	},
});
