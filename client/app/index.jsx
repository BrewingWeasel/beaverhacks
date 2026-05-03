import { Text, View, StyleSheet, TouchableOpacity, StatusBar, Platform } from 'react-native';
import { useRouter } from 'expo-router';

export default function HomeScreen() {
  const router = useRouter();
  const topPadding = Platform.OS === 'android' ? StatusBar.currentHeight || 0 : 20; // 20 is a simple iOS safe offset

  return (
    <View style={[styles.container, { paddingTop: topPadding }]}>
      <View style={styles.header}>
        <Text style={styles.title}>Dam Clever</Text>
      </View>
      <View style={styles.content}>
        <Text style={styles.subtitle}>Welcome to Dam Clever!</Text>
        <TouchableOpacity
          style={styles.button}
          onPress={() => router.push('/startgame')}
        >
          <Text style={styles.buttonText}>Start Game</Text>
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
    color: '#fff',
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
