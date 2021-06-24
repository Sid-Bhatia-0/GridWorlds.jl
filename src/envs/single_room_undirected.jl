module ModuleSingleRoomUndirected

import Crayons
import ..GridWorlds as GW
import ..Play
import Random
import REPL
import ReinforcementLearningBase as RLBase
import StaticArrays as SA
import StatsBase as SB

const MOVE_UP = 1
const MOVE_DOWN = 2
const MOVE_LEFT = 3
const MOVE_RIGHT = 4
const ACTION_NAMES = (:MOVE_UP, :MOVE_DOWN, :MOVE_LEFT, :MOVE_RIGHT)

const AGENT = 1
const WALL = 2
const GOAL = 3

const DUMMY_CHARACTER = '⋅'
const CHARACTERS = ('☻', '█', '♥')
const FOREGROUND_COLORS = (:light_red, :white, :light_red)

function sample_two_positions_without_replacement(rng, region)
    position1 = rand(rng, region)
    position2 = rand(rng, region)

    while position1 == position2
        position2 = rand(rng, region)
    end

    return position1, position2
end

function move(action::Integer, i, j)
    if action == MOVE_UP
        return i - 1, j
    elseif action == MOVE_DOWN
        return i + 1, j
    elseif action == MOVE_LEFT
        return i, j - 1
    elseif action == MOVE_RIGHT
        return i, j + 1
    else
        return i, j
    end
end

mutable struct SingleRoomUndirected{R, RNG} <: GW.AbstractGridWorld
    tile_map::BitArray{3}
    agent_position::CartesianIndex{2}
    reward::R
    rng::RNG
    done::Bool
    terminal_reward::R
    goal_position::CartesianIndex{2}
end

function SingleRoomUndirected(; R = Float32, height = 8, width = 8, rng = Random.MersenneTwister())
    tile_map = BitArray(undef, 3, height, width)

    inner_area = CartesianIndices((2 : height - 1, 2 : width - 1))

    tile_map[:, :, :] .= false
    tile_map[WALL, 1, :] .= true
    tile_map[WALL, height, :] .= true
    tile_map[WALL, :, 1] .= true
    tile_map[WALL, :, width] .= true

    agent_position, goal_position = sample_two_positions_without_replacement(rng, inner_area)

    tile_map[AGENT, agent_position] = true
    tile_map[GOAL, goal_position] = true

    reward = zero(R)
    done = false
    terminal_reward = one(R)

    env = SingleRoomUndirected(tile_map, agent_position, reward, rng, done, terminal_reward, goal_position)

    RLBase.reset!(env)

    return env
end

RLBase.StateStyle(env::SingleRoomUndirected) = RLBase.InternalState{Any}()
RLBase.state_space(env::SingleRoomUndirected, ::RLBase.InternalState) = nothing
RLBase.state(env::SingleRoomUndirected, ::RLBase.InternalState) = env.tile_map

RLBase.action_space(env::SingleRoomUndirected) = (MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT)
RLBase.reward(env::SingleRoomUndirected) = env.reward[]
RLBase.is_terminated(env::SingleRoomUndirected) = env.done[]

function RLBase.reset!(env::SingleRoomUndirected{R}) where {R}
    tile_map = env.tile_map
    rng = env.rng

    num_objects, height, width = size(tile_map)
    inner_area = CartesianIndices((2 : height - 1, 2 : width - 1))

    tile_map[AGENT, env.agent_position] = false
    tile_map[GOAL, env.goal_position] = false

    new_agent_position, new_goal_position = sample_two_positions_without_replacement(rng, inner_area)

    env.agent_position = new_agent_position
    tile_map[AGENT, new_agent_position] = true

    env.goal_position = new_goal_position
    tile_map[GOAL, new_goal_position] = true

    env.reward = zero(R)
    env.done = false

    return nothing
end

function (env::SingleRoomUndirected{R})(action) where {R}
    tile_map = env.tile_map
    agent_position = env.agent_position

    new_agent_position = CartesianIndex(move(action, agent_position.I...))

    if !tile_map[WALL, new_agent_position]
        tile_map[AGENT, agent_position] = false
        env.agent_position = new_agent_position
        tile_map[AGENT, new_agent_position] = true
    end

    if tile_map[GOAL, env.agent_position]
        env.reward = env.terminal_reward
        done = true
    else
        env.reward = zero(R)
        done = false
    end

    return nothing
end

function Base.show(io::IO, ::MIME"text/plain", env::SingleRoomUndirected)
    tile_map = env.tile_map

    num_objects, height, width = size(tile_map)

    print(io, "objects = ")
    for i in 1 : length(CHARACTERS)
        print(io, Crayons.Crayon(foreground = FOREGROUND_COLORS[i]), CHARACTERS[i], Crayons.Crayon(reset = true))
        if i < length(CHARACTERS)
            print(io, ", ")
        else
            print(io, "\n")
        end
    end
    println(io, "dummy character = ", DUMMY_CHARACTER)

    println(io)
    for i in 1:height
        for j in 1:width
            idx = findfirst(@view tile_map[:, i, j])
            if isnothing(idx)
                print(io, DUMMY_CHARACTER)
            else
                print(io, Crayons.Crayon(foreground = FOREGROUND_COLORS[idx]), CHARACTERS[idx], Crayons.Crayon(reset = true))
            end
        end

        println(io)
    end

    println(io, "reward = ", env.reward)
    println(io, "done = ", env.done)

    return nothing
end

get_string_key_bindings(env::SingleRoomUndirected) = """Key bindings:
                                                     'q': quit
                                                     'r': RLBase.reset!(env)
                                                     'w': MOVE_UP
                                                     's': MOVE_DOWN
                                                     'a': MOVE_LEFT
                                                     'd': MOVE_RIGHT
                                                     """

function play!(terminal::REPL.Terminals.UnixTerminal, env::SingleRoomUndirected; file_name::Union{Nothing, AbstractString} = nothing)
    REPL.Terminals.raw!(terminal, true)

    terminal_out = terminal.out_stream
    terminal_in = terminal.in_stream
    file = Play.open_maybe(file_name)

    Play.write_io1_maybe_io2(terminal_out, file, Play.CLEAR_SCREEN)
    Play.write_io1_maybe_io2(terminal_out, file, Play.MOVE_CURSOR_TO_ORIGIN)
    Play.write_io1_maybe_io2(terminal_out, file, Play.HIDE_CURSOR)

    action_chars = ('w', 's', 'a', 'd')

    char_to_action = Dict('w' => MOVE_UP,
                          's' => MOVE_DOWN,
                          'a' => MOVE_LEFT,
                          'd' => MOVE_RIGHT,
                         )

    try
        while true
            Play.write_io1_maybe_io2(terminal_out, file, get_string_key_bindings(env))
            Play.show_io1_maybe_io2(terminal_out, file, MIME("text/plain"), env)

            char = read(terminal_in, Char)

            Play.write_io1_maybe_io2(terminal_out, file, Play.EMPTY_SCREEN)

            if char == 'q'
                Play.write_io1_maybe_io2(terminal_out, file, Play.SHOW_CURSOR)
                Play.close_maybe(file)
                REPL.Terminals.raw!(terminal, false)
                return nothing
            elseif char == 'r'
                RLBase.reset!(env)
            elseif char in action_chars
                env(char_to_action[char])
            else
                @warn "No procedure exists for this character: $char"
            end

            Play.write_io1_maybe_io2(terminal_out, file, "Last character = $(char)\n")
        end
    finally
        Play.write_io1_maybe_io2(terminal_out, file, Play.SHOW_CURSOR)
        Play.close_maybe(file)
        REPL.Terminals.raw!(terminal, false)
    end

    return nothing
end

play!(env::SingleRoomUndirected; file_name = nothing) = play!(REPL.TerminalMenus.terminal, env, file_name = file_name)

end # module