import { Text, View, StyleSheet, TouchableOpacity, StatusBar, Platform } from 'react-native';
import { useRouter } from 'expo-router';
import { useSocket } from '../context/SocketContext';
import { useParty } from '../context/BoardContext';

export default function LobbyScreen() {
  const topPadding = Platform.OS === 'android' ? StatusBar.currentHeight || 0 : 20;
  const socket = useSocket();
  const party = useParty();
  const router = useRouter();

  const startGame = () => {
    if (!socket || !party?.isLeader) return;
    socket.send(JSON.stringify({ type: 'start_game' }));
  };

  const goHome = () => {
    router.replace('/');
  };

  return (
    <View style={[styles.container, { paddingTop: topPadding }]}>
      <View style={styles.header}>
        <Text style={styles.title}>Party Lobby</Text>
      </View>
      <View style={styles.content}>
        <Text style={styles.subtitle}>
          {party?.description ?? 'Party location not available.'}
        </Text>
        <Text style={styles.subtitle}>
          {party?.isLeader ? 'You are the party leader.' : 'Waiting for the party leader to start.'}
        </Text>
        {party?.id ? <Text style={styles.partyId}>Party {party.id}</Text> : null}
        {party?.isLeader ? (
          <TouchableOpacity style={styles.button} onPress={startGame}>
            <Text style={styles.buttonText}>Start Game</Text>
          </TouchableOpacity>
        ) : null}
        {!party ? (
          <TouchableOpacity style={styles.secondaryButton} onPress={goHome}>
            <Text style={styles.secondaryButtonText}>Find A Party</Text>
          </TouchableOpacity>
        ) : null}
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
    marginBottom: 12,
    textAlign: 'center',
  },
  partyId: {
    color: '#555',
    marginBottom: 20,
    textAlign: 'center',
  },
  button: {
    backgroundColor: '#D73F09',
    paddingVertical: 12,
    paddingHorizontal: 30,
    borderRadius: 8,
    minWidth: 180,
    alignItems: 'center',
  },
  secondaryButton: {
    borderColor: '#D73F09',
    borderWidth: 1,
    paddingVertical: 12,
    paddingHorizontal: 30,
    borderRadius: 8,
    minWidth: 180,
    alignItems: 'center',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  secondaryButtonText: {
    color: '#D73F09',
    fontSize: 16,
    fontWeight: '600',
  },
});
