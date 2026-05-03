import { StyleSheet, View, PanResponder, Text, Animated } from 'react-native'
import { LinearGradient } from 'expo-linear-gradient'
import React, { useEffect, useState, useRef, useImperativeHandle, forwardRef } from 'react'
import { useBoard } from '../../context/BoardContext'
import { useSocket } from '../../context/SocketContext'

import TileRed from '../../assets/images/tile-red.svg'
import TileBlue from '../../assets/images/tile-blue.svg'
import TileGreen from '../../assets/images/tile-green.svg'
import TileOrange from '../../assets/images/tile-orange.svg'
import TilePink from '../../assets/images/tile-pink.svg'
import TileTeal from '../../assets/images/tile-teal.svg'

const TILE_SVGS = [TileRed, TileBlue, TileGreen, TileOrange, TilePink, TileTeal]

const TILE_SIZE = 75
const TILE_MARGIN = 5
const MOVE = TILE_SIZE + TILE_MARGIN * 2
const OVERSHOOT = 3
const SLIDE_DURATION = 95
const OVERSHOOT_RETURN_DURATION = 25
const TOTAL_MOVE_DURATION = SLIDE_DURATION + OVERSHOOT_RETURN_DURATION

const Tile = forwardRef(function Tile({ tileId, onSwipeStart, onSwipe }, ref) {
  const TileSvg = TILE_SVGS[tileId % TILE_SVGS.length]

  const pos = useRef(new Animated.ValueXY({ x: 0, y: 0 })).current
  const zIndex = useRef(new Animated.Value(1)).current
  const scale = useRef(new Animated.Value(1)).current

  useImperativeHandle(ref, () => ({
    animateShrinkGrow(dir) {
      const slideTarget = { x: 0, y: 0 }
      if (dir === 'right') slideTarget.x = -MOVE
      else if (dir === 'left') slideTarget.x = MOVE
      else if (dir === 'down') slideTarget.y = -MOVE
      else if (dir === 'up') slideTarget.y = MOVE

      Animated.timing(pos, {
        toValue: slideTarget,
        duration: TOTAL_MOVE_DURATION,
        useNativeDriver: false,
        easing: (t) => t,
      }).start(() => {
        requestAnimationFrame(() =>
          requestAnimationFrame(() => pos.setValue({ x: 0, y: 0 }))
        )
      })

      Animated.sequence([
        Animated.timing(scale, {
          toValue: 0.93,
          duration: 60,
          useNativeDriver: true,
        }),
        Animated.spring(scale, {
          toValue: 1,
          friction: 14,
          tension: 500,
          useNativeDriver: true,
        }),
      ]).start()
    },
  }))

  const panResponder = PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onMoveShouldSetPanResponder: (_, g) =>
      Math.abs(g.dx) > 6 || Math.abs(g.dy) > 6,

    onPanResponderGrant: () => {
      zIndex.setValue(10)
    },

    onPanResponderRelease: (_, g) => {
      const absDx = Math.abs(g.dx)
      const absDy = Math.abs(g.dy)
      let dir = null
      const target = { x: 0, y: 0 }
      const overshootTarget = { x: 0, y: 0 }

      if (absDx > absDy) {
        dir = g.dx > 0 ? 'right' : 'left'
        const sign = dir === 'right' ? 1 : -1
        target.x = sign * MOVE
        overshootTarget.x = sign * (MOVE + OVERSHOOT)
      } else {
        dir = g.dy > 0 ? 'down' : 'up'
        const sign = dir === 'down' ? 1 : -1
        target.y = sign * MOVE
        overshootTarget.y = sign * (MOVE + OVERSHOOT)
      }

      onSwipeStart && onSwipeStart(dir)

      Animated.sequence([
        Animated.timing(pos, {
          toValue: overshootTarget,
          duration: SLIDE_DURATION,
          useNativeDriver: false,
          easing: (t) => t,
        }),
        Animated.timing(pos, {
          toValue: target,
          duration: OVERSHOOT_RETURN_DURATION,
          useNativeDriver: false,
          easing: (t) => t,
        }),
      ]).start(() => {
        Animated.sequence([
          Animated.timing(scale, {
            toValue: 0.91,
            duration: 40,
            useNativeDriver: true,
          }),
          Animated.spring(scale, {
            toValue: 1,
            friction: 12,
            tension: 600,
            useNativeDriver: true,
          }),
        ]).start()

        onSwipe && onSwipe(dir)
        zIndex.setValue(1)
        requestAnimationFrame(() =>
          requestAnimationFrame(() => pos.setValue({ x: 0, y: 0 }))
        )
      })
    },

    onPanResponderTerminate: () => {
      Animated.timing(pos, {
        toValue: { x: 0, y: 0 },
        duration: 100,
        useNativeDriver: false,
      }).start()
      zIndex.setValue(1)
    },
  })

  return (
    <Animated.View
      style={{
        transform: pos.getTranslateTransform(),
        zIndex,
        elevation: zIndex,
      }}
      {...panResponder.panHandlers}
    >
      <Animated.View style={{ transform: [{ scale }] }}>
        {typeof TileSvg === 'function'
          ? <TileSvg width={TILE_SIZE} height={TILE_SIZE} />
          : <View style={[styles.tile, { backgroundColor: '#ccc' }]} />
        }
      </Animated.View>
    </Animated.View>
  )
})

function DemoTile({ tileId, isPartOf }) {
  const TileSvg = TILE_SVGS[tileId % TILE_SVGS.length]
  const wrapperStyle = isPartOf ? { backgroundColor: 'yellow', borderRadius: 4 } : {}
  const isSvgComponent = typeof TileSvg === 'function'
  return (
    <View style={wrapperStyle}>
      {isSvgComponent
        ? <TileSvg width={20} height={20} />
        : <View style={[styles.desiredOutputTile, { backgroundColor: '#ccc' }]} />
      }
    </View>
  )
}

export default function SwipePuzzle() {
  const boardInfo = useBoard()
  const division = boardInfo.division
  const score = boardInfo.score
  const [board, setBoard] = useState(boardInfo.local_board)
  const socket = useSocket()

  const [timer, setTimer] = useState(boardInfo.time_left)
  const [solved, setSolved] = useState(false)
  const solvedOpacity = useRef(new Animated.Value(0)).current
  const dangerOpacity = useRef(new Animated.Value(0)).current
  const dangerAnim = useRef(null)

  const tileRefs = useRef(
    boardInfo.local_board.map(row => row.map(() => React.createRef()))
  )

  useEffect(() => {
    console.log(score)
    console.log("desired:", boardInfo.full_board)
    console.log("division:", boardInfo.division)
    console.log(board)
    const interval = setInterval(() => {
      setTimer((time) => Math.max(0, time - 1000))
    }, 1000)
    return () => clearInterval(interval)
  }, [])

  useEffect(() => {
    if (timer <= 10000 && timer > 0) {
      dangerAnim.current?.stop()
      dangerOpacity.setValue(1)
      if (timer <= 5000) {
        dangerAnim.current = Animated.sequence([
          Animated.timing(dangerOpacity, { toValue: 0.35, duration: 420, useNativeDriver: true }),
          Animated.timing(dangerOpacity, { toValue: 1, duration: 80, useNativeDriver: true }),
          Animated.timing(dangerOpacity, { toValue: 0.35, duration: 420, useNativeDriver: true }),
        ])
      } else {
        dangerAnim.current = Animated.timing(dangerOpacity, { toValue: 0.3, duration: 950, useNativeDriver: true })
      }
      dangerAnim.current.start()
    } else {
      dangerAnim.current?.stop()
      dangerAnim.current = null
      dangerOpacity.setValue(0)
    }
  }, [timer])

  useEffect(() => {
    if (!socket) return
    const existingOnMessage = socket.onmessage
    socket.onmessage = (data) => {
      const rawMessage = data.data ?? data._data
      console.log("Received message:", rawMessage)
      const message = JSON.parse(rawMessage)
      if (message.type === "tile_updated") {
        setBoard((prev) => {
          const newBoard = [...prev]
          newBoard[message.coordinate.y][message.coordinate.x] = message.new_tile
          return newBoard
        })
      } else if (message.type === "board_solved") {
        setSolved(true)
        solvedOpacity.setValue(1)
        setTimeout(() => {
          Animated.timing(solvedOpacity, {
            toValue: 0,
            duration: 400,
            useNativeDriver: true,
          }).start(() => setSolved(false))
        }, 1000)
      } else {
        existingOnMessage?.(data)
      }
    }
  }, [socket])

  function getNeighborRef(row, col, direction) {
    const neighborRow = row + (direction === 'down' ? 1 : direction === 'up' ? -1 : 0)
    const neighborCol = col + (direction === 'right' ? 1 : direction === 'left' ? -1 : 0)
    return tileRefs.current[neighborRow]?.[neighborCol]
  }

  return (
    <View style={styles.container}>
      <View style={styles.container}>
        {boardInfo.full_board.map((row, rowIndex) => (
          <View key={rowIndex} style={styles.row}>
            {row.map((tileId, colIndex) => (
              <DemoTile
                key={colIndex}
                isPartOf={
                  colIndex <= division.end_x && colIndex >= division.start_x &&
                  rowIndex <= division.end_y && rowIndex >= division.start_y
                }
                tileId={tileId}
              />
            ))}
          </View>
        ))}
      </View>

      {/* Timer and score */}
      <View style={styles.statsRow}>
        <View style={styles.statCard}>
          <Text style={styles.statLabel}>⏱ TIME</Text>
          <Text style={styles.statValue}>{Math.round(timer / 1000)}s</Text>
        </View>
        <View style={styles.statDivider} />
        <View style={styles.statCard}>
          <Text style={styles.statLabel}>⭐ SCORE</Text>
          <Text style={styles.statValue}>{score}</Text>
        </View>
      </View>

      {/* Interactive board */}
      <View style={styles.container}>
        {board.map((row, rowIndex) => (
          <View key={rowIndex} style={styles.row}>
            {row.map((tileId, colIndex) => (
              <Tile
                key={colIndex}
                ref={tileRefs.current[rowIndex][colIndex]}
                tileId={tileId}
                onSwipeStart={(dir) => {
                  getNeighborRef(rowIndex, colIndex, dir)?.current?.animateShrinkGrow(dir)
                }}
                onSwipe={(dir) => {
                  if (!socket) return
                  socket.send(JSON.stringify({
                    type: "swap_tile",
                    from: { x: colIndex, y: rowIndex },
                    direction: dir,
                  }))
                }}
              />
            ))}
          </View>
        ))}
      </View>

      {solved && (
        <Animated.View style={[styles.solvedOverlay, { opacity: solvedOpacity }]}>
          <Text style={styles.solvedText}>Solved!</Text>
        </Animated.View>
      )}

      <Animated.View style={[styles.dangerOverlay, { opacity: dangerOpacity }]} pointerEvents="none">
        <LinearGradient colors={['rgba(255,0,0,0.55)', 'transparent']} style={styles.dangerEdgeTop} />
        <LinearGradient colors={['rgba(255,0,0,0.55)', 'transparent']} style={styles.dangerEdgeBottom} start={{ x: 0, y: 1 }} end={{ x: 0, y: 0 }} />
        <LinearGradient colors={['rgba(255,0,0,0.55)', 'transparent']} style={styles.dangerEdgeLeft} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} />
        <LinearGradient colors={['rgba(255,0,0,0.55)', 'transparent']} style={styles.dangerEdgeRight} start={{ x: 1, y: 0 }} end={{ x: 0, y: 0 }} />
      </Animated.View>
    </View>
  )
}

const styles = StyleSheet.create({
  page: {},
  container: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  row: { flexDirection: 'row' },
  tile: {
    width: TILE_SIZE,
    height: TILE_SIZE,
    margin: TILE_MARGIN,
    borderRadius: 10,
  },
  desiredOutputTile: {
    width: 22, height: 22, margin: 2,
    borderRadius: 6,
  },
  statsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
    borderRadius: 16,
    paddingVertical: 10,
    paddingHorizontal: 32,
    marginVertical: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 5,
  },
  statCard: {
    alignItems: 'center',
    minWidth: 70,
  },
  statLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: '#888',
    letterSpacing: 1.5,
    textTransform: 'uppercase',
  },
  statValue: {
    fontSize: 28,
    fontWeight: '800',
    color: '#fff',
    marginTop: 2,
  },
  statDivider: {
    width: 1,
    height: 40,
    backgroundColor: '#333',
    marginHorizontal: 24,
  },
  solvedOverlay: {
    position: 'absolute',
    top: 0, left: 0, right: 0, bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.55)',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 99,
  },
  solvedText: {
    fontSize: 48,
    fontWeight: 'bold',
    color: '#2ECC71',
  },
  dangerOverlay: {
    position: 'absolute',
    top: 0, left: 0, right: 0, bottom: 0,
    zIndex: 50,
  },
  dangerEdgeTop: {
    position: 'absolute',
    top: 0, left: 0, right: 0,
    height: 120,
  },
  dangerEdgeBottom: {
    position: 'absolute',
    bottom: 0, left: 0, right: 0,
    height: 120,
  },
  dangerEdgeLeft: {
    position: 'absolute',
    top: 0, bottom: 0, left: 0,
    width: 80,
  },
  dangerEdgeRight: {
    position: 'absolute',
    top: 0, bottom: 0, right: 0,
    width: 80,
  },
})
