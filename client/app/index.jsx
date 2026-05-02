import { StyleSheet, View, TouchableOpacity } from 'react-native'
import React, { useState } from 'react'
import { PanResponder } from 'react-native'

const BOARD_SIZE = 4
const COLORS = [
  '#FF5733', '#33FF57', '#3357FF', '#F1C40F',
  '#9B59B6', '#1ABC9C', '#E67E22', '#E74C3C',
  '#2ECC71', '#3498DB', '#E84393', '#F39C12',
  '#16A085', '#8E44AD', '#C0392B', '#2980B9'
]

function createInitialBoard() {
  // Shuffle the colors and fill the board
  const shuffled = [...COLORS].sort(() => Math.random() - 0.5)
  return Array.from({ length: BOARD_SIZE }, (_, i) =>
    shuffled.slice(i * BOARD_SIZE, (i + 1) * BOARD_SIZE)
  )
}

export default function SwipePuzzle() {
  const [board, setBoard] = useState(createInitialBoard())

  const panResponder = PanResponder.create({
    onMoveShouldSetPanResponder: (_, gestureState) =>
      Math.abs(gestureState.dx) > 20 || Math.abs(gestureState.dy) > 20,
    onPanResponderRelease: (_, gestureState) => {
      // You can implement swipe logic here if you want
    },
  })

  return (
    <View style={styles.container} {...panResponder.panHandlers}>
      {board.map((row, rowIndex) => (
        <View key={rowIndex} style={styles.row}>
          {row.map((color, colIndex) => (
            <View
              key={colIndex}
              style={[styles.tile, { backgroundColor: color }]}
            />
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
    borderRadius: 8,
  },
})