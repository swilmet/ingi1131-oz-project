functor
import
   Utils
   Config
   Brain
export
   Embody
   Create
define
   proc {Embody PlayerPort BrainFunc InitState}
      proc {AskBrain Env State}
         [Action NextState] = {BrainFunc Env State}
         NextEnv
         Dead
      in
         {Send PlayerPort Action#?NextEnv#?Dead}
         {Wait NextEnv}
         {Wait Dead}
         if {Not Dead} then
            {AskBrain NextEnv NextState}
         end
      end
   in
      thread
         InitEnv
         Dead
      in
         % "noop" is actually useful
         {Send PlayerPort noop#?InitEnv#?Dead}
         {Wait InitEnv}
         {Wait Dead}

         if {Not Dead} then
            {AskBrain InitEnv InitState}
         end
      end
   end

   fun {Create Team Squares Map StaticEnv}
      InitBag = resources(food:0 wood:0 stone:0 steel:0)
      PlayerPort

      fun {PosOutOfMap X Y}
         X < 1
         orelse Y < 1
         orelse {Width Squares} < Y
         orelse {Width Squares.1} < X
      end

      % Move to a surrounding square. Returns the new state.
      fun {Move NewX NewY State}
         CurX = State.pos.x
         CurY = State.pos.y
      in
         {Utils.unitDelay}

         % Same position
         if NewX == CurX andthen NewY == CurY then
            State

         % Invalid position (out of the map)
         elseif {PosOutOfMap NewX NewY} then
            State

         % Not one of the 8 surrounding squares
         elseif 1 < {Number.abs CurX - NewX} orelse 1 < {Number.abs CurY - NewY} then
            State

         % OK, do the move
         else
            NewState
            Dead
         in
            {Send Squares.CurY.CurX playerOut(Team.num State.weapon)}
            {Send Squares.NewY.NewX playerIn(Team.num State.weapon ?Dead)}

            if Dead then
               NewState = {AdjoinAt State dead true}

            % If on home, deposit bag resources
            elseif NewX == Team.homePos.x andthen NewY == Team.homePos.y
               andthen 0 < {Utils.resourcesSum State.bag} then
               {Send Team.home addResources(State.bag)}
               NewState = {AdjoinAt State bag InitBag}
            else
               NewState = State
            end

            {AdjoinAt NewState pos pos(x:NewX y:NewY)}
         end
      end

      fun {ManageFight ResType State ?ResourceExploited}
         CurX = State.pos.x
         CurY = State.pos.y
         Dead
         Finished
      in
         {Send Squares.CurY.CurX beginExploit(Team.num PlayerPort State.weapon ?Dead)}

         thread
            {Utils.unitDelay}
            Finished = unit
         end

         % There is a fight
         if {Utils.waitTwo Dead Finished} == 1 then
            ResourceExploited = false

            % We are dead
            if Dead then
               {Send Squares.CurY.CurX playerOut(Team.num State.weapon)}
               {AdjoinAt State dead true}

            % We survived, but we lost the resource
            else
               State
            end

         % No fight, finished to exploit the resource
         else
            NewBag = {AdjoinAt State.bag ResType State.bag.ResType+1}
         in
            ResourceExploited = true
            {Send Squares.CurY.CurX endExploit(Team.num PlayerPort)}
            {AdjoinAt State bag NewBag}
         end
      end

      % Exploit a resource
      fun {Exploit State}
         CurX = State.pos.x
         CurY = State.pos.y
         SquareType = Map.CurY.CurX
      in
         % Not on a resource, a unit time is lost...
         if SquareType == normal orelse SquareType == home then
            {Utils.unitDelay}
            State

         % The bag is full
         elseif Config.bagLimit =< {Utils.resourcesSum State.bag} then
            {Utils.unitDelay}
            State

         % OK, exploit the resource
         else
            ResType = {Utils.getResourceType SquareType}
         in
            {ManageFight ResType State _}
         end
      end

      fun {Steal Type State}
         CurX = State.pos.x
         CurY = State.pos.y
         SquareType = Map.CurY.CurX
      in
         % Not an opponent's home
         if SquareType \= home orelse State.pos == Team.homePos then
            {Utils.unitDelay}
            State
         else
            Exploited
            NewState = {ManageFight Type State ?Exploited}
         in
            if Exploited then
               HomePort = {Send Squares.CurY.CurX getHomePort($)}
               ResourcesToRemove = {AdjoinAt InitBag Type 1}
               OK = {Send HomePort removeResources(ResourcesToRemove $)}
            in
               if OK then
                  NewState
               else
                  State
               end
            else
               NewState
            end
         end
      end

      fun {BuildWeapon State}
         {Utils.unitDelay}

         if State.weapon then
            State
         else
            OK
         in
            {Send Team.home removeResources(Config.costWeapon ?OK)}
            if OK then
               {AdjoinAt State weapon true}
            else
               State
            end
         end
      end

      fun {BuildPlayer InitPlayerState State}
         OK
      in
         {Utils.unitDelay}
         {Send Team.home removeResources(Config.costPlayer ?OK)}
         if OK then
            NewPlayer = {Create Team Squares Map StaticEnv}
            NewBrain = {Brain.createBrain StaticEnv InitPlayerState}
         in
            {Embody NewPlayer NewBrain InitPlayerState}
         end

         State
      end

      fun {BuildTower TowerPos State}
         CurX = State.pos.x
         CurY = State.pos.y

         fun {TowerPosIsValid}
            NotOutOfMap = {Not {PosOutOfMap TowerPos.x TowerPos.y}}
            NormalSquare = NotOutOfMap andthen Map.(TowerPos.y).(TowerPos.x) == normal

            % Next to the player, but not in diagonal
            NextToPlayer =
               (CurX == TowerPos.x andthen {Number.abs CurY-TowerPos.y} == 1)
               orelse
               (CurY == TowerPos.y andthen {Number.abs CurX-TowerPos.x} == 1)
         in
            NormalSquare andthen NextToPlayer
         end
      in
         {Utils.unitDelay}

         if {TowerPosIsValid} then
            RemoveResOK
         in
            {Send Team.home removeResources(Config.costTower ?RemoveResOK)}
            if RemoveResOK then
               TowerBuilt
            in
               {Send Squares.(TowerPos.y).(TowerPos.x) buildTower(Team.num ?TowerBuilt)}
               if TowerBuilt then
                  State
               else
                  {Send Team.home addResources(Config.costTower)}
                  State
               end
            else
               State
            end
         else
            State
         end
      end

      fun {GetBrainEnv State}
         HomeResources
         OpponentHomeResources
         VisibleTowers
         CurX = State.pos.x
         CurY = State.pos.y
      in
         {Send Team.home getNbResources(?HomeResources)}
         {Send Squares.CurY.CurX getVisibleTowers(?VisibleTowers)}
         {Wait HomeResources}
         {Wait VisibleTowers}

         if Map.CurY.CurX == home andthen State.pos \= Team.homePos then
            OpponentHome
         in
            {Send Squares.CurY.CurX getHomePort(?OpponentHome)}
            if OpponentHome == none then
               raise 'Get home port on opponent\'s home square failed.' end
            end
            {Send OpponentHome getNbResources(?OpponentHomeResources)}
         else
            OpponentHomeResources = none
         end

         env(location: State.pos
             bag: State.bag
             resources: HomeResources
             weapon: State.weapon
             opponentHome: OpponentHomeResources
             towers: VisibleTowers)
      end

      fun {HandleMsg Msg State}
         case Msg
         % Message from the brain
         of Action#?BrainEnv#?Dead then
            % If the player is already dead, do nothing
            if State.dead then
               Dead = true
               BrainEnv = {GetBrainEnv State}
               State
            else
               NewState
            in
               case Action
               of noop then
                  NewState = State
               [] move(pos(x:NewX y:NewY)) then
                  NewState = {Move NewX NewY State}
               [] exploit then
                  NewState = {Exploit State}
               [] steal(Type) then
                  NewState = {Steal Type State}
               [] build(weapon) then
                  NewState = {BuildWeapon State}
               [] build(player(InitPlayerState)) then
                  NewState = {BuildPlayer InitPlayerState State}
               [] build(tower(TowerPos)) then
		  NewState = {BuildTower TowerPos State}
	       else
		  NewState = State
               end

               Dead = NewState.dead
               BrainEnv = {GetBrainEnv NewState}
               NewState
            end
         end
      end

      HomeSquare = Squares.(Team.homePos.y).(Team.homePos.x)

      % Initially, the player is at its home and his bag is empty
      InitState = state(pos: Team.homePos
                        bag: InitBag
                        weapon: false
                        dead: false)

      Dead
      State
   in
      % FIXME can a player be killed by a tower here?
      {Send HomeSquare playerIn(Team.num InitState.weapon ?Dead)}

      if Dead then
         State = {AdjoinAt InitState dead true}
      else
         State = InitState
      end

      % Don't simplify the following two lines, the variable is used above!
      PlayerPort = {Utils.newPortObject HandleMsg State}
      PlayerPort
   end
end
