// Parth Kalkar, BS-19-02, p.kalkar@innopolis.university

// Kotlin based UI for supporting prolog game, made using Compose Library and gradle

import androidx.compose.desktop.LocalAppWindow
import androidx.compose.desktop.Window
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.shortcuts
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.jpl7.Compound
import org.jpl7.PrologException
import org.jpl7.Query
import kotlin.concurrent.thread
import kotlin.time.ExperimentalTime
import kotlin.time.measureTime
import kotlin.time.seconds


data class Coordinate(val x: Int, val y: Int) // Class coordinates just for coordinates

@ExperimentalTime
fun main() { // main function which will start the game and open a new game window
    // All other comments about UI implementation can be found on github @ParthKalkar

    Window {
        var width by remember { mutableStateOf<Int?>(null) }
        var homeX by remember { mutableStateOf<Int?>(null) }
        var homeY by remember { mutableStateOf<Int?>(null) }
        var algo by remember { mutableStateOf(Algos.BACKTRACKING) }
        var menuExpanded by remember { mutableStateOf(false) }

        MaterialTheme {
            val startTheGame = { width?.let { game(it, Coordinate(homeX!!, homeY!!), algo) } ?: Unit }

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.SpaceEvenly,
                modifier = Modifier.padding(100.dp).fillMaxSize()
            ) {
                Column {
                    Text("Enter the width")
                    TextField(width?.toString() ?: "",
                        {
                            width = it.toIntOrNull()
                        }, modifier = Modifier.shortcuts {
                            on(Key.Enter, startTheGame)
                        })
                }
                Column {
                    Text("Enter the home's x coordinate")
                    TextField(homeX?.toString() ?: "", {
                        homeX = it.toIntOrNull()
                    })
                }
                Column {
                    Text("Enter the home's y coordinate")
                    TextField(homeY?.toString() ?: "", {
                        homeY = it.toIntOrNull()
                    })
                }
                Column {
                    Text("Choose the algorithm: ${algo.name}", modifier = Modifier.clickable { menuExpanded = !menuExpanded })
                    DropdownMenu(menuExpanded, { menuExpanded = false }) {
                        Algos.values().forEach { algorithm ->
                            DropdownMenuItem({
                                algo = algorithm
                            }) {
                                Text(algorithm.name)
                            }
                        }
                    }
                }
                Button(startTheGame) { Text("Start") }
            }

        }
    }
}

val queries = mutableMapOf<Thread, Query>()

sealed class State()
data class Playing(val thread: Thread? = null) : State()
object Won : State()
object Lost : State()

enum class Algos(val path: String) {
    BACKTRACKING("prolog/backtracking.pl"),
    A_STAR("prolog/a_star.pl"),
    A_STAR_V2("prolog/a_star_v2.pl")
}

@ExperimentalTime
fun game(width: Int, home: Coordinate, algorithm: Algos) {
    val coordinates = Coordinates(width, home)
    Window {
        var state by remember { mutableStateOf<State>(Playing()) }
        LocalAppWindow.current.events.onClose = {
            state.let {
                if (it is Playing && it.thread?.isInterrupted == true) {
                    it.thread.interrupt()
                    queries.remove(it.thread)?.close()
                }
            }
        }
        var actorCoordinates by remember { mutableStateOf(Coordinate(0, 0)) }

        if (state is Playing && (state as Playing).thread == null) {

            consult(algorithm.path) {
                state = (state as Playing).copy(thread = thread {
                    coordinates.run {
                        val result = query(
                            "run",
                            width - 1,
                            covids[0].x,
                            covids[0].y,
                            covids[1].x,
                            covids[1].y,
                            mask.x,
                            mask.y,
                            doctor.x,
                            doctor.y,
                            home.x,
                            home.y,
                            "Path"
                        )
                        queries[Thread.currentThread()] = result
                        println(
                            """run(${
                                listOf(
                                    width - 1,
                                    covids[0].x,
                                    covids[0].y,
                                    covids[1].x,
                                    covids[1].y,
                                    mask.x,
                                    mask.y,
                                    doctor.x,
                                    doctor.y,
                                    home.x,
                                    home.y,
                                ).joinToString(", ")
                            }, Path)."""
                        )
                        val time = measureTime {
                            val isSuccessful = try {
                                result.hasNext().also(::println)
                            } catch (e: PrologException) {
                                e.printStackTrace()
                                false
                            }
                            if (!isSuccessful) {
                                println("No Solutions")
                                queries.remove(Thread.currentThread())
                                Thread.sleep(1000L)
                                state = Lost
                                return@thread
                            }
                        }

                        val path = (result.next()["Path"] as? Compound)
                            ?.also(::println)
                            ?.listToTermArray()
                            ?.map { it as Compound }
                            ?.map { it.listToTermArray().run { Coordinate(get(0).intValue(), get(1).intValue()) } }

                        println("Number of steps: ${path?.size}\n" +
                                "Time: $time")
                        if (path == null) {
                            println("Strange solution")
                            return@thread
                        }
                        println("running")

                        GlobalScope.launch {
                            delay(1.seconds)
                            path.forEach {
                                actorCoordinates = it
                                delay(.5.seconds)
                            }
                            state = Won
                        }
                    }
                })
            }
        }

        MaterialTheme {
            when (state) {
                is Playing -> {
                    for (x in 0 until width) {
                        for (y in 0 until width) {
                            Canvas(Modifier.grid(Coordinate(x, y), width)) {
                                drawRoundRect(
                                    Color.LightGray,
                                    Offset(2F, 2F),
                                    Size(gridSize.toPx() - 4, gridSize.toPx() - 4),
                                    CornerRadius(5F, 5F),
                                )
                            }
                        }

                    }

                    coordinates.run {
                        Home(home)
                        Doctor(doctor)
                        Mask(mask)
                        covids.forEach { coordinate ->
                            Covid(coordinate)
                        }
                        Actor(actorCoordinates)
                    }
                }
                is Won -> windowWithText("You won")
                is Lost -> windowWithText("You lost")
            }
        }
    }
}

@Composable
fun windowWithText(text: String) {
    Box(Modifier.fillMaxSize(), Alignment.Center) {
        Text(text, fontSize = 30.sp, fontWeight = FontWeight.Bold)
    }
}

class Coordinates(val width: Int, val home: Coordinate) {

    private val alreadyGeneratedCoordinates = mutableSetOf<Coordinate>(Coordinate(0, 0), home)
    val doctor = randomCoordinates()
    val mask = randomCoordinates()
    val covids = (1..2).map { randomCoordinates() }

    private fun randomCoordinates(): Coordinate {
        while (true) {
            val newCoordinates = Coordinate((0 until width).random(), (0 until width).random())
            if (newCoordinates in alreadyGeneratedCoordinates) continue
            alreadyGeneratedCoordinates += newCoordinates
            return newCoordinates
        }
    }
}

val gridSize = 50.dp

fun Modifier.grid(coordinate: Coordinate, width: Int) =
    absoluteOffset(left.first + gridSize * coordinate.x, left.second + gridSize * (width - 1 - coordinate.y))
        .size(gridSize)

val left = 10.dp to 0.dp

@Composable
fun Coordinates.Entity(image: String, coordinate: Coordinate, modifier: Modifier = Modifier) {
    ResourceImage(
        image, modifier = modifier
            .grid(coordinate, width)
    )
}

@Composable
fun Coordinates.Actor(coordinate: Coordinate) = Entity("actor.jpg", coordinate)

@Composable
fun Coordinates.Mask(coordinate: Coordinate) = Entity("mask.png", coordinate)

@Composable
fun Coordinates.Doctor(coordinate: Coordinate) = Entity("doctor.png", coordinate)

@Composable
fun Coordinates.Home(coordinate: Coordinate) = Entity("home.png", coordinate)

@Composable
fun Coordinates.Covid(coordinate: Coordinate) = Entity("covid.png", coordinate)
