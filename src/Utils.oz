functor
import
   Config
export
   UnitDelay
   ResourcesSum
   GoalReached
   GetResourceType
   WaitTwo
   NewPortObject
   NewActive
define
   proc {UnitDelay}
      {Delay Config.unitDelay}
   end

   % Calculate the sum of the resources
   fun {ResourcesSum Res}
      Res.food + Res.wood + Res.stone + Res.steel
   end

   fun {GoalReached Res}
      Config.goal.food =< Res.food andthen
      Config.goal.wood =< Res.wood andthen
      Config.goal.stone =< Res.stone andthen
      Config.goal.steel =< Res.steel
   end

   fun {GetResourceType SquareType}
      case SquareType
      of forest then wood
      [] field then food
      [] quarry then stone
      [] mine then steel
      else none
      end
   end

   % Wait X and Y. As soon as one of the two variables gets bound,
   % return the value, which is 1 if X is bound first, or 2 if Y is bound first.
   fun {WaitTwo X Y}
      Ret
   in
      thread
         {Wait X}
         if {Not {IsDet Ret}} then Ret = 1 end
      end
      thread
         {Wait Y}
         if {Not {IsDet Ret}} then Ret = 2 end
      end
      Ret
   end

   % Creates a port object
   fun {NewPortObject Behaviour InitState}
      proc {MsgLoop Stream State}
         case Stream
         of nil then skip
         [] Msg|OtherMessages then
            {MsgLoop OtherMessages {Behaviour Msg State}}
         end
      end
      Stream
   in
      thread {MsgLoop Stream InitState} end
      {NewPort Stream}
   end

   % To be able to call methods asynchronously on an object
   fun {NewActive Class Init}
      Obj = {New Class Init}
      Port
   in
      thread Stream in
         {NewPort Stream Port}
         for Msg in Stream do {Obj Msg} end
      end
      proc {$ Msg} {Send Port Msg} end
   end
end
