import React, { useState } from 'react'
import {
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
} from 'react-native'
import SignIn from './SignIn'
import SignUp from './SignUp'

export default function Auth() {
  const [screen, setScreen] = useState<'signIn' | 'signUp'>('signIn')

  return (
    <KeyboardAvoidingView
      style={styles.root}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <ScrollView
        contentContainerStyle={styles.container}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        {screen === 'signIn' ? (
          <SignIn onNavigateToSignUp={() => setScreen('signUp')} />
        ) : (
          <SignUp onNavigateToSignIn={() => setScreen('signIn')} />
        )}
      </ScrollView>
    </KeyboardAvoidingView>
  )
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#fff',
  },
  container: {
    flexGrow: 1,
    paddingHorizontal: 24,
    justifyContent: 'center',
    paddingVertical: 48,
  },
})
