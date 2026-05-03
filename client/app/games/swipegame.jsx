import { StyleSheet, View, PanResponder, Text, TouchableOpacity, Animated } from 'react-native'
import React, { useEffect, useState, useRef } from 'react'
import { useBoard } from '../../context/BoardContext'
import { useSocket } from '../../context/SocketContext'

const COLORS = [
  '#FF5733', '#33FF57', '#3357FF', '#F1C40F',
  '#9B59B6', '#1ABC9C', '#E67E22', '#E74C3C',
  '#2ECC71', '#3498DB', '#E84393', '#F39C12',
  '#16A085', '#8E44AD', '#C0392B', '#2980B9'
]

function Tile({ tileId, onSwipe }) {
  const color = COLORS[tileId]
  const pos = useRef(new Animated.ValueXY({ x: 0, y: 0 })).current
  const MOVE = 60 + 4 * 2

  const panResponder = PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onMoveShouldSetPanResponder: (_, g) =>
      Math.abs(g.dx) > 6 || Math.abs(g.dy) > 6,
    onPanResponderRelease: (_, g) => {
      const absDx = Math.abs(g.dx)
      const absDy = Math.abs(g.dy)
      let dir = null
      const to = { x: 0, y: 0 }

      if (absDx > absDy) {
        dir = g.dx > 0 ? 'right' : 'left'
        to.x = dir === 'right' ? MOVE : -MOVE
      } else {
        dir = g.dy > 0 ? 'down' : 'up'
        to.y = dir === 'down' ? MOVE : -MOVE
      }

      Animated.timing(pos, { toValue: to, duration: 150, useNativeDriver: false }).start(() => {
        onSwipe && onSwipe(dir)
        pos.setValue({ x: 0, y: 0 })
      })
    },
    onPanResponderTerminate: () => {
      pos.setValue({ x: 0, y: 0 })
    },
  })

  return (
    <Animated.View
      style={[styles.tile, { backgroundColor: color, transform: pos.getTranslateTransform() }]}
      {...panResponder.panHandlers}
    />
  )
}

function DemoTile({ tileId, isPartOf }) {
  const color = COLORS[tileId]

  const wrapperStyle = isPartOf ? { backgroundColor: 'yellow' } : {}
	
  return (
	  <View style={wrapperStyle}>
		<View
		  style={[styles.desiredOutputTile, { backgroundColor: color }]}
		/>
	  </View>
  )
}

export default function SwipePuzzle() {
  const boardInfo = useBoard();
  const division = boardInfo.division;
  const score = boardInfo.score;
  const [board, setBoard] = useState(boardInfo.local_board);
  const socket = useSocket();

  const [timer, setTimer] = useState(boardInfo.time_left);

  useEffect(() => {
	  console.log(score);

	  console.log("desired:", boardInfo.full_board);
	  console.log("division:", boardInfo.division);

	  console.log(board);
	  setInterval(() => {
		  setTimer((time) => { return Math.max(0, time - 1000); });
	  }, 1000)
  }, [])

  useEffect(() => {
	if (!socket) return;
  const existingOnMessage = socket.onmessage
	socket.onmessage = (data) => {
		console.log("Received message:", data._data);
		const message = JSON.parse(data._data);
		if (message.type == "tile_updated") { 
		  setBoard((prev) => {
			  const newBoard = [...prev];
			  newBoard[message.coordinate.y][message.coordinate.x] = message.new_tile;
			  return newBoard;
		  })
		} else {
			existingOnMessage(data);
		}
	};
  }, [socket])

  function handleSwipe(row, col, direction) {
	  if (!socket) return;
	  socket.send(JSON.stringify({"type": "swap_tile", "from": {"x": col, "y": row}, "direction": direction}))
	// Old swipe handling - could still be useful?
	  
    // // Figure out where the neighbor is
    // const neighborRow = row + (direction === 'down' ? 1 : direction === 'up' ? -1 : 0)
    // const neighborCol = col + (direction === 'right' ? 1 : direction === 'left' ? -1 : 0)
    //
    // // If neighbor is out of bounds, do nothing
    // if (
    //   neighborRow < 0 || neighborRow >= BOARD_SIZE ||
    //   neighborCol < 0 || neighborCol >= BOARD_SIZE
    // ) return
    //
    // setBoard(prev => {
    //   const newBoard = prev.map(r => [...r])
    //   const temp = newBoard[row][col]
    //   newBoard[row][col] = newBoard[neighborRow][neighborCol]
    //   newBoard[neighborRow][neighborCol] = temp
    //   return newBoard
    // })
  }

  return (
	  <View style={styles.container}>
		<View style={styles.container}>
		  {boardInfo.full_board.map((row, rowIndex) => (
			<View key={rowIndex} style={styles.row}>
			  {row.map((tileId, colIndex) => (
				<DemoTile
				  key={colIndex}
				  isPartOf={colIndex <= division.end_x && colIndex >= division.start_x && rowIndex <= division.end_y && rowIndex >= division.start_y}
				  tileId={tileId}
				/>
			  ))}
			</View>
		  ))}
		</View>
		<View>
	  		<Text>Time {Math.round(timer / 1000)}</Text>
	  		<Text>Score {score}</Text>
	    </View>
		<View style={styles.container}>
		  {board.map((row, rowIndex) => (
			<View key={rowIndex} style={styles.row}>
			  {row.map((tileId, colIndex) => (
				<Tile
				  key={colIndex}
				  tileId={tileId}
				  onSwipe={(dir) => handleSwipe(rowIndex, colIndex, dir)}
				/>
			  ))}
			</View>
		  ))}
		</View>
	  </View>
  )
}

const styles = StyleSheet.create({
  page: {},
  container: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  row: { flexDirection: 'row' },
  tile: {
    width: 60, height: 60, margin: 4,
    borderRadius: 8,
  },
  desiredOutputTile: {
    width: 20, height: 20, margin: 2,
    borderRadius: 8,
  },
})
