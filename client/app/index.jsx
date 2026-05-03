import { Text, View, StyleSheet, TouchableOpacity, StatusBar, Platform, ActivityIndicator } from 'react-native';
import { useSocket } from '../context/SocketContext';
import { useRouter } from 'expo-router';
import { supabase } from '../lib/supabase'
import { useUserId } from './_layout';
import { useState } from 'react';

export default function HomeScreen() {
  const topPadding = Platform.OS === 'android' ? StatusBar.currentHeight || 0 : 20; // 20 is a simple iOS safe offset
  const socket = useSocket();
  const router = useRouter();
  const userId = useUserId();
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState('');

  function canSendMessage() {
	if (!socket || socket.readyState !== WebSocket.OPEN) {
		setStatus('Connecting to the server...');
		return false;
	}
	return true;
  }

  async function getBuilding() {
	const { data, error } = await supabase.from('profiles').select("building").eq('id', userId).single();
	if (error) {
		console.log(error);
		throw error;
	}

	return data.building;
  }

  async function createParty() {
    if (!userId || loading || !canSendMessage()) return;
	setLoading(true);
	setStatus('Creating party...');
	try {
		const building = await getBuilding();
		socket.send(JSON.stringify({"type": "create_party", "building": building, "description": "todo"}));
	} catch {
		setStatus('Could not create a party.');
		setLoading(false);
	}
  }

  async function findParty() {
    if (!userId || loading || !canSendMessage()) return;
	setLoading(true);
	setStatus('Looking for parties in your building...');
	try {
		const building = await getBuilding();
		const { data, error } = await supabase
			.from('parties')
			.select('id')
			.eq('building', building)
			.limit(1);

		if (error) throw error;
		if (!data || data.length === 0) {
			setStatus('No parties found in your building.');
			setLoading(false);
			return;
		}

		socket.send(JSON.stringify({"type": "join_party", "id": data[0].id}));
	} catch (error) {
		console.log(error);
		setStatus('Could not look for parties.');
		setLoading(false);
	}
  }

  return (
    <View style={[styles.container, { paddingTop: topPadding }]}>
      <View style={styles.header}>
        <Text style={styles.title}>Dam Clever</Text>
      </View>
      <View style={styles.content}>
        <Text style={styles.subtitle}>Welcome to Dam Clever!</Text>
        {status ? <Text style={styles.status}>{status}</Text> : null}
        <TouchableOpacity
          style={[styles.button, loading && styles.buttonDisabled]}
          onPress={createParty}
          disabled={loading}
        >
          {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Create Party</Text>}
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.button, loading && styles.buttonDisabled]}
          onPress={findParty}
          disabled={loading}
        >
          <Text style={styles.buttonText}>Look For Parties</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.button}
        >
          <Text onPress={() => router.navigate('/settings')} style={styles.buttonText}>Settings</Text>
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
  status: {
    color: '#333',
    marginBottom: 12,
    textAlign: 'center',
  },
  button: {
    backgroundColor: '#D73F09',
    paddingVertical: 12,
    paddingHorizontal: 30,
    borderRadius: 8,
    marginTop: 12,
    minWidth: 180,
    alignItems: 'center',
  },
  buttonDisabled: {
    opacity: 0.65,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});
