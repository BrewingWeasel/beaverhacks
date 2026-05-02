import { StyleSheet, Text, View, TouchableOpacity } from 'react-native'
import React, { useState } from 'react'
import { PanResponder } from 'react-native'

const BOARD_SIZE = 4

function createInitialBoard() {
  // Example: 4x4 board with numbers 1-15 and one empty space (0)
  const arr = Array.from({ length: BOARD_SIZE * BOARD_SIZE }, (_, i) => i)
  return Array.from({ length: BOARD_SIZE }, (_, i) =>
    arr.slice(i * BOARD_SIZE, (i + 1) * BOARD_SIZE)
  )
}

export default function SwipePuzzle() {
  const [board, setBoard] = useState(createInitialBoard())

  // PanResponder for swipe detection
  const panResponder = PanResponder.create({
    onMoveShouldSetPanResponder: (_, gestureState) =>
      Math.abs(gestureState.dx) > 20 || Math.abs(gestureState.dy) > 20,
    onPanResponderRelease: (_, gestureState) => {
      if (Math.abs(gestureState.dx) > Math.abs(gestureState.dy)) {
        if (gestureState.dx > 0) move('right')
        else move('left')
      } else {
        if (gestureState.dy > 0) move('down')
        else move('up')
      }
    },
  })

  function move(direction) {
    // Implement logic to move tiles based on swipe direction
    // Update board state with setBoard(...)
  }

  return (
    <View style={styles.container} {...panResponder.panHandlers}>
      {board.map((row, rowIndex) => (
        <View key={rowIndex} style={styles.row}>
          {row.map((tile, colIndex) => (
            <View key={colIndex} style={styles.tile}>
              <Text style={styles.tileText}>{tile !== 0 ? tile : ''}</Text>
            </View>
          ))}
        </View>
      ))}
    </View>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  row: { flexDirection: 'row' },
  tile: {
    width: 60, height: 60, margin: 4,
    backgroundColor: '#eee', justifyContent: 'center', alignItems: 'center',
    borderRadius: 8,
  },
  tileText: { fontSize: 24, fontWeight: 'bold' },
})