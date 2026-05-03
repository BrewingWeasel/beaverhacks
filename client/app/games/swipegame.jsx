import { StyleSheet, View, PanResponder } from 'react-native'
import React, { useEffect, useState } from 'react'
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
  const panResponder = PanResponder.create({
    onMoveShouldSetPanResponder: (_, g) =>
      Math.abs(g.dx) > 10 || Math.abs(g.dy) > 10,
    onPanResponderRelease: (_, g) => {
      const absDx = Math.abs(g.dx)
      const absDy = Math.abs(g.dy)
      if (absDx > absDy) {
        onSwipe(g.dx > 0 ? 'right' : 'left')
      } else {
        onSwipe(g.dy > 0 ? 'down' : 'up')
      }
    },
  })

  return (
    <View
      style={[styles.tile, { backgroundColor: color }]}
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
  const [desired_board, local_board, division] = useBoard()
  console.log("desired:", desired_board)
  console.log("division:", division)
  const [board, setBoard] = useState(local_board)
  const socket = useSocket()
  console.log(board)

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
		  {desired_board.map((row, rowIndex) => (
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
