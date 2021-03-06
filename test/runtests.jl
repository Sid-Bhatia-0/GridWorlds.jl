import GridWorlds
import GridWorlds: GW
import Test
import Random
import ReinforcementLearningBase
import ReinforcementLearningBase: RLBase

ENVS = [GW.EmptyRoomDirected,
        GW.EmptyRoomUndirected,
        GW.GridRoomsDirected,
        GW.GridRoomsUndirected,
        GW.SequentialRoomsDirected,
        GW.SequentialRoomsUndirected,
        GW.MazeDirected,
        GW.MazeUndirected,
        GW.GoToTargetDirected,
        GW.GoToTargetUndirected,
        GW.DoorKeyDirected,
        GW.DoorKeyUndirected,
        GW.CollectGemsDirected,
        GW.CollectGemsUndirected,
        GW.DynamicObstaclesDirected,
        GW.DynamicObstaclesUndirected,
        GW.SokobanDirected,
        GW.SokobanUndirected,
        GW.Snake,
        GW.Catcher,
        GW.TransportDirected,
        GW.TransportUndirected,
       ]

const MAX_STEPS = 3000
const NUM_RESETS = 3

get_terminal_returns(env::GW.EmptyRoomDirected) = (env.terminal_reward,)
get_terminal_returns(env::GW.EmptyRoomUndirected) = (env.terminal_reward,)
get_terminal_returns(env::GW.GridRoomsDirected) = (env.terminal_reward,)
get_terminal_returns(env::GW.GridRoomsUndirected) = (env.terminal_reward,)
get_terminal_returns(env::GW.SequentialRoomsDirected) = (env.terminal_reward,)
get_terminal_returns(env::GW.SequentialRoomsUndirected) = (env.terminal_reward,)
get_terminal_returns(env::GW.MazeDirected) = (env.terminal_reward,)
get_terminal_returns(env::GW.MazeUndirected) = (env.terminal_reward,)
get_terminal_returns(env::GW.GoToTargetDirected) = (env.terminal_reward, env.terminal_penalty)
get_terminal_returns(env::GW.GoToTargetUndirected) = (env.terminal_reward, env.terminal_penalty)
get_terminal_returns(env::GW.DoorKeyDirected) = (env.terminal_reward,)
get_terminal_returns(env::GW.DoorKeyUndirected) = (env.terminal_reward,)
get_terminal_returns(env::GW.CollectGemsDirected) = (env.num_gem_init * env.gem_reward,)
get_terminal_returns(env::GW.CollectGemsUndirected) = (env.num_gem_init * env.gem_reward,)
get_terminal_returns(env::GW.DynamicObstaclesDirected) = (env.terminal_reward, env.terminal_penalty)
get_terminal_returns(env::GW.DynamicObstaclesUndirected) = (env.terminal_reward, env.terminal_penalty)
get_terminal_returns(env::GW.SokobanDirected{T}) where {T} = (T(length(env.box_pos)),)
get_terminal_returns(env::GW.SokobanUndirected{T}) where {T} = (T(length(env.box_pos)),)

get_terminal_returns_win(env::GW.Snake{T}) where {T} = GW.get_terminal_reward(env):GW.get_food_reward(env):convert(T, GW.get_terminal_reward(env) + GW.get_height(env)*GW.get_width(env)*GW.get_food_reward(env))
get_terminal_returns_lose(env::GW.Snake{T}) where {T} = GW.get_terminal_penalty(env):GW.get_food_reward(env):convert(T, GW.get_terminal_penalty(env) + GW.get_height(env)*GW.get_width(env)*GW.get_food_reward(env))

get_terminal_returns(env::GW.Catcher) = env.terminal_reward:env.ball_reward:MAX_STEPS*env.ball_reward
get_terminal_returns(env::GW.TransportDirected) = (GW.get_terminal_reward(env),)
get_terminal_returns(env::GW.TransportUndirected) = (GW.get_terminal_reward(env),)

Test.@testset "GridWorlds.jl" begin
    for Env in ENVS
        Test.@testset "$(Env)" begin
            T = Float32
            env = Env(T = T)
            for _ in 1:NUM_RESETS
                RLBase.reset!(env)
                Test.@test RLBase.reward(env) == zero(T)
                Test.@test RLBase.is_terminated(env) == false

                total_reward = zero(T)
                for i in 1:MAX_STEPS
                    action = rand(RLBase.action_space(env))
                    env(action)
                    total_reward += RLBase.reward(env)

                    Test.@test 1 ≤ GW.get_agent_pos(env)[1] ≤ GW.get_height(env)
                    Test.@test 1 ≤ GW.get_agent_pos(env)[2] ≤ GW.get_width(env)

                    if RLBase.is_terminated(env)
                        if Env == GW.Snake
                            Test.@test (total_reward in get_terminal_returns_win(env) || total_reward in get_terminal_returns_lose(env))
                        else
                            Test.@test total_reward in get_terminal_returns(env)
                        end
                        break
                    end

                    if i == MAX_STEPS
                        @info "$Env not terminated after MAX_STEPS = $MAX_STEPS"
                    end
                end
            end
        end
    end
end
