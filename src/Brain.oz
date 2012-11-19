functor
import
   Utils
   OS
   Config
export
   CreateBrain
define
   fun {GetRandBetween Min Max}
      ({OS.rand} mod (Max-Min+1)) + Min
   end

   % For some brains, we have to modify the Config.

   fun {CreateBrainBuildPlayer StaticEnv Init}
      fun {$ Env State}
         if State == none then
            [build(player(none)) noop]
         else
            [move(Env.location) noop]
         end
      end
   end

   fun {CreateBrainKilledByTower StaticEnv Init}
      fun {$ Env State}
         NextLoc = {GetNextLoc Env.location pos(x:7 y:5)}
      in
         [move(NextLoc) none]
      end
   end

   fun {CreateBrainBuildTower StaticEnv Init}
      fun {$ Env State}
         TowerLoc = pos(x:Env.location.x y:Env.location.y-1)
      in
         [build(tower(TowerLoc)) none]
      end
   end

   fun {CreateBrainFight StaticEnv Init}
      fun {$ Env State}
         if Env.location == pos(x:2 y:6) then
            [exploit none]
         else
            NextLoc = {GetNextLoc Env.location pos(x:2 y:6)}
         in
            [move(NextLoc) none]
         end
      end
   end

   % To test this one, we can e.g. comment the code that builds the initial towers
   fun {CreateBrainSteal StaticEnv Init}
      fun {$ Env State}
         case State
         of none then
            if Env.location == pos(x:6 y:6) then
               [steal(wood) returnHome]
            else
               NextLoc = {GetNextLoc Env.location pos(x:6 y:6)}
            in
               [move(NextLoc) none]
            end
         [] returnHome then
            NextLoc = {GetNextLoc Env.location pos(x:2 y:2)}
         in
            [move(NextLoc) returnHome]
         end
      end
   end

   % This one is really funny with a lot of initial players :)
   fun {CreateBrainRandomMove StaticEnv Init}
      fun {$ Env State}
         X = {GetRandBetween 1 7}
         Y = {GetRandBetween 1 7}
         NextLoc = {GetNextLoc Env.location pos(x:X y:Y)}
      in
         [move(NextLoc) none]
      end
   end

   % This brain search for the closest field to go and exploit it.
   fun {CreateBrainGetFood StaticEnv Init}
      fun {$ Env State}
	 X = Env.location.x
	 Y = Env.location.y
      in
	 if Env.bag.food >= Config.bagLimit then
	    NextLoc = {GetNextLoc Env.location StaticEnv.home}
	 in
	    [move(NextLoc) returnHome]
	 elseif StaticEnv.board.Y.X == 'field' then [exploit none]
	 else
	    FoodPos = {Closest 'field' Env.location StaticEnv.board}.1
	    NextLoc = {GetNextLoc Env.location FoodPos}
	 in
	    [move(NextLoc) none]
	 end
      end
   end

   % Put here to brain you want to use
   fun {CreateBrain StaticEnv Init}
      {CreateBrainGetFood StaticEnv Init}
   end

   % We are at CurLoc and we want to go to WantedLoc, what is the next location?
   fun {GetNextLoc CurLoc WantedLoc}
      X
      Y
      NextLoc = pos(x:X y:Y)
   in
      if WantedLoc.x < CurLoc.x then
         X = CurLoc.x - 1
      elseif CurLoc.x < WantedLoc.x then
         X = CurLoc.x + 1
      else
         X = CurLoc.x
      end

      if WantedLoc.y < CurLoc.y then
         Y = CurLoc.y - 1
      elseif CurLoc.y < WantedLoc.y then
         Y = CurLoc.y + 1
      else
         Y = CurLoc.y
      end

      NextLoc
   end


   % Returns a list with all the closest squares to the player of SquareType type
   % The first element of the list is the minimum amount of moves needed to go to
   % a location in the list
   fun {Closest SquareType Location Map}
      fun {Loop I Type Acc R}
         if I < R*8 then
	    local A B in
               if I < R*2+1 then
		  A = Location.x+I-R
		  B = Location.y-R
	       elseif R*2 < I andthen I < R*4 then
		  A = Location.x+R
		  B = Location.y+I-R*3
	       elseif R*4-1 < I andthen I < R*6+1 then
		  A = Location.x-I+R*5
		  B = Location.y+R
	       else
		  A = Location.x-R
		  B = Location.y-I+R*7
	       end
	       if A > 0 andthen A =< {Width Map.1} andthen B > 0 andthen B =< {Width Map} then
		  if Map.B.A == Type then
		     {Loop I+1 Type pos(x:A y:B)|Acc R}
		  else {Loop I+1 Type Acc R}
		  end
	       else {Loop I+1 Type Acc R}
	       end
	    end
	 elseif Acc == nil then {Loop 0 Type Acc R+1}
	 else Acc
	 end
      end
   in
      {Loop 0 SquareType nil 1}
   end
end
