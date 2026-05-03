import { useState } from 'react'
import {
  Alert,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  StyleSheet,
  ActivityIndicator,
  Modal,
  FlatList,
} from 'react-native'
import { supabase } from '../lib/supabase'

const BUILDINGS = [
  { id: '1', label: 'Bloss' },
  { id: '2', label: 'Buxton' },
  { id: '3', label: 'Callahan' },
  { id: '4', label: 'Cauthorn' },
  { id: '5', label: 'Finley' },
  { id: '6', label: 'Halsell' },
  { id: '7', label: 'Hawley' },
  { id: '8', label: 'ILLC' },
  { id: '9', label: 'McNary' },
  { id: '10', label: 'Poling' },
  { id: '11', label: 'Sackett' },
  { id: '12', label: 'Tebeau' },
  { id: '13', label: 'Weatherford' },
  { id: '14', label: 'West' },
  { id: '15', label: 'Wilson' },
]

interface Building {
  id: string
  label: string
}

interface SignUpProps {
  onNavigateToSignIn: () => void
}

export default function SignUp({ onNavigateToSignIn }: SignUpProps) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [username, setUsername] = useState('')
  const [selectedBuilding, setSelectedBuilding] = useState<Building | null>(null)
  const [loading, setLoading] = useState(false)
  const [dropdownOpen, setDropdownOpen] = useState(false)

  async function signUpWithEmail() {
    if (!email || !password || !username || !selectedBuilding) {
      Alert.alert('Please fill in all fields.')
      return
    }
    setLoading(true)
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { username, building: selectedBuilding.label },
      },
    })
    if (error) Alert.alert(error.message)
    setLoading(false)
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Sign Up</Text>

      <TextInput
        style={styles.input}
        onChangeText={setUsername}
        value={username}
        placeholder="Username"
        placeholderTextColor="#aaa"
        autoCapitalize="none"
      />
      <TextInput
        style={styles.input}
        onChangeText={setEmail}
        value={email}
        placeholder="Email"
        placeholderTextColor="#aaa"
        autoCapitalize="none"
        keyboardType="email-address"
      />
      <TextInput
        style={styles.input}
        onChangeText={setPassword}
        value={password}
        placeholder="Password"
        placeholderTextColor="#aaa"
        secureTextEntry
        autoCapitalize="none"
      />

      <TouchableOpacity style={styles.dropdown} onPress={() => setDropdownOpen(true)}>
        <Text style={selectedBuilding ? styles.dropdownText : styles.dropdownPlaceholder}>
          {selectedBuilding ? selectedBuilding.label : 'Select building'}
        </Text>
        <Text style={styles.chevron}>▾</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={[styles.button, loading && styles.buttonDisabled]}
        onPress={signUpWithEmail}
        disabled={loading}
      >
        {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Create Account</Text>}
      </TouchableOpacity>

      <TouchableOpacity onPress={onNavigateToSignIn}>
        <Text style={styles.link}>
          Already have an account? <Text style={styles.linkBold}>Sign in</Text>
        </Text>
      </TouchableOpacity>

      <Modal visible={dropdownOpen} transparent animationType="fade" onRequestClose={() => setDropdownOpen(false)}>
        <TouchableOpacity style={styles.overlay} activeOpacity={1} onPress={() => setDropdownOpen(false)}>
          <View style={styles.sheet}>
            <Text style={styles.sheetTitle}>Select Building</Text>
            <FlatList
              data={BUILDINGS}
              keyExtractor={(item) => item.id}
              renderItem={({ item }) => (
                <TouchableOpacity
                  style={styles.option}
                  onPress={() => {
                    setSelectedBuilding(item)
                    setDropdownOpen(false)
                  }}
                >
                  <Text style={styles.optionText}>{item.label}</Text>
                  {selectedBuilding?.id === item.id && <Text style={styles.optionCheck}>✓</Text>}
                </TouchableOpacity>
              )}
              ItemSeparatorComponent={() => <View style={styles.separator} />}
            />
          </View>
        </TouchableOpacity>
      </Modal>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    gap: 12,
  },
  title: {
    fontSize: 26,
    fontWeight: '700',
    color: '#111',
    marginBottom: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 16,
    color: '#111',
  },
  dropdown: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  dropdownText: {
    fontSize: 16,
    color: '#111',
  },
  dropdownPlaceholder: {
    fontSize: 16,
    color: '#aaa',
  },
  chevron: {
    fontSize: 16,
    color: '#aaa',
  },
  button: {
    backgroundColor: '#111',
    borderRadius: 8,
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 4,
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  link: {
    textAlign: 'center',
    color: '#888',
    fontSize: 14,
    marginTop: 8,
  },
  linkBold: {
    color: '#111',
    fontWeight: '600',
  },
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.3)',
    justifyContent: 'flex-end',
  },
  sheet: {
    backgroundColor: '#fff',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    padding: 24,
    paddingBottom: 40,
  },
  sheetTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#111',
    marginBottom: 16,
  },
  option: {
    paddingVertical: 14,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  optionText: {
    fontSize: 16,
    color: '#111',
  },
  optionCheck: {
    fontSize: 16,
    color: '#111',
    fontWeight: '600',
  },
  separator: {
    height: 1,
    backgroundColor: '#f0f0f0',
  },
})
