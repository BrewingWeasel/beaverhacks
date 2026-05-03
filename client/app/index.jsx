import { Text, View, StyleSheet, TouchableOpacity, StatusBar, Platform, ActivityIndicator, SafeAreaView, Alert } from 'react-native';
import { useSocket } from '../context/SocketContext';
import { useRouter } from 'expo-router';
import { supabase } from '../lib/supabase'
import { useUserId } from './_layout';
import { useState } from 'react';

export default function HomeScreen() {
  const socket = useSocket();
  const router = useRouter();
  const userId = useUserId();
  const [loading, setLoading] = useState(false);

  async function getBuilding() {
    const { data, error } = await supabase.from('profiles').select("building").eq('id', userId).single();
    if (error) {
      console.log(error);
      throw error;
    }
    return data.building;
  }

  async function createParty() {
    if (!userId || !socket) return;
    setLoading(true);
	  Alert.prompt(
	  	'Location',
	  	'Enter the location (e.g. "3rd floor lounge", "Room 204")',
	  	async (location) => {
	  	  if (!location?.trim()) return;
	  	  setLoading(true);
	  	  try {
	  		const building = await getBuilding();
	  		socket.send(JSON.stringify({ "type": "create_party", "building": building, "description": location.trim() }));
	  	  } catch {
	  		setLoading(false);
	  	  }
	  	},
	  	'plain-text',
	  	'',
	  	'default'
      );
  }

  async function findParty() {
    if (!userId || loading || !socket) return;
    setLoading(true);
    try {
      const building = await getBuilding();
      const { data, error } = await supabase
        .from('parties')
        .select('id')
        .eq('building', building)
        .limit(1);

      if (error) throw error;
      if (!data || data.length === 0) {
        setLoading(false);
        return;
      }

      socket.send(JSON.stringify({ "type": "join_party", "id": data[0].id }));
    } catch (error) {
      console.log(error);
      setLoading(false);
    }
  }

  return (
    <View style={styles.root}>
      <StatusBar barStyle="light-content" backgroundColor="#D73F09" />
      <SafeAreaView style={styles.safeHeader}>
        <View style={styles.header}>
          <Text style={styles.title}>DamClever</Text>
        </View>
      </SafeAreaView>

      <View style={styles.content}>
        <Text style={styles.greeting}>What would you like to do?</Text>

        <View style={styles.buttonGroup}>
          <TouchableOpacity
            style={[styles.button, styles.buttonPrimary, loading && styles.buttonDisabled]}
            onPress={createParty}
            disabled={loading}
            activeOpacity={0.8}
          >
            {loading
              ? <ActivityIndicator color="#fff" />
              : (
                <>
                  <Text style={styles.buttonEmoji}>🎉</Text>
                  <Text style={styles.buttonText}>Create a Party</Text>
                </>
              )
            }
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.buttonSecondary, loading && styles.buttonDisabled]}
            onPress={findParty}
            disabled={loading}
            activeOpacity={0.8}
          >
            <Text style={styles.buttonEmoji}>🔍</Text>
            <Text style={[styles.buttonText, styles.buttonTextSecondary]}>Look for Parties</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.buttonGhost]}
            onPress={() => router.navigate('/settings')}
            activeOpacity={0.7}
          >
            <Text style={styles.buttonEmoji}>⚙️</Text>
            <Text style={[styles.buttonText, styles.buttonTextGhost]}>Settings</Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#fff',
  },
  safeHeader: {
    backgroundColor: '#D73F09',
  },
  header: {
    backgroundColor: '#D73F09',
    paddingTop: Platform.OS === 'android' ? (StatusBar.currentHeight || 0) + 16 : 16,
    paddingBottom: 28,
    paddingHorizontal: 24,
    alignItems: 'center',
  },
  title: {
    color: '#fff',
    fontSize: 32,
    fontWeight: '800',
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
    letterSpacing: 0.5,
  },
  tagline: {
    color: 'rgba(255,255,255,0.75)',
    fontSize: 14,
    fontWeight: '500',
    marginTop: 4,
    letterSpacing: 0.3,
    fontFamily: Platform.OS === 'ios' ? 'Helvetica Neue' : 'sans-serif',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 28,
    paddingBottom: 40,
    backgroundColor: '#fff',
  },
  greeting: {
    fontSize: 20,
    fontWeight: '700',
    color: '#1a1a1a',
    marginBottom: 36,
    fontFamily: Platform.OS === 'ios' ? 'Helvetica Neue' : 'sans-serif-medium',
    letterSpacing: 0.2,
  },
  buttonGroup: {
    width: '100%',
    gap: 14,
  },
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 18,
    paddingHorizontal: 36,
    borderRadius: 14,
    width: '100%',
    gap: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 6,
    elevation: 3,
  },
  buttonPrimary: {
    backgroundColor: '#D73F09',
  },
  buttonSecondary: {
    backgroundColor: '#fff',
    borderWidth: 2,
    borderColor: '#D73F09',
    shadowOpacity: 0.05,
  },
  buttonGhost: {
    backgroundColor: '#f4f4f4',
    shadowOpacity: 0,
    elevation: 0,
  },
  buttonDisabled: {
    opacity: 0.55,
  },
  buttonEmoji: {
    fontSize: 18,
  },
  buttonText: {
    color: '#fff',
    fontSize: 17,
    fontWeight: '700',
    fontFamily: Platform.OS === 'ios' ? 'Helvetica Neue' : 'sans-serif-medium',
    letterSpacing: 0.3,
  },
  buttonTextSecondary: {
    color: '#D73F09',
  },
  buttonTextGhost: {
    color: '#555',
  },
});
