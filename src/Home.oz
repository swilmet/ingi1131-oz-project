functor
import
   Utils
   Config
export
   Create
define
   % Creates a home object.
   % HomePort: get the port to which we can send messages.
   % StateStream: get a stream containing all the states.
   % The state contains only the number of resources.
   % The purpose of the state stream is to be notified when the number of resources change,
   % so we can, for example, update the user interface.
   proc {Create ?HomePort ?StateStream}
      StatePort

      fun {HandleMsg Msg State}
         case Msg
         of getNbResources(?Res) then
            Res = State
            State

         [] addResources(Res) then
            NewState = resources(food: Res.food + State.food
                                 wood: Res.wood + State.wood
                                 stone: Res.stone + State.stone
                                 steel: Res.steel + State.steel)
         in
            {Send StatePort NewState}
            NewState

         [] removeResources(Res ?OK) then
            if State.food < Res.food orelse
               State.wood < Res.wood orelse
               State.stone < Res.stone orelse
               State.steel < Res.steel then
               OK = false
               State
            else
               NewState = resources(food: State.food - Res.food
                                    wood: State.wood - Res.wood
                                    stone: State.stone - Res.stone
                                    steel: State.steel - Res.steel)
            in
               OK = true
               {Send StatePort NewState}
               NewState
            end
         end
      end
   in
      {NewPort StateStream StatePort}
      {Send StatePort Config.initResources}
      HomePort = {Utils.newPortObject HandleMsg Config.initResources}
   end
end
