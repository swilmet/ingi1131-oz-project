functor
import
   Config
   Utils
export
   Create
define
   fun {GetPlayerStrength Weapon}
      if Weapon then
         Config.playerWeaponStrength
      else
         Config.playerDefaultStrength
      end
   end

   fun {GetPlayerCategory HasWeapon}
      if HasWeapon then
         withWeapon
      else
         withoutWeapon
      end
   end

   % Get the first opponent's tower that can kill the player.
   % Search only in the towers located at other squares.
   % The tower on this square is managed differently.
   fun {GetFirstOpponentTower TeamNum State}
      fun {Step List}
         case List
         of nil then
            none
         [] Tower|OtherTowers then
            if Tower.owner \= TeamNum then
               Tower
            else
               {Step OtherTowers}
            end
         end
      end
   in
      {Step State.nearTowers}
   end

   % Whether a tower can kill a player located at Pos
   fun {CanKill Pos TowerPos}
      {Number.abs Pos.x-TowerPos.x} =< Config.towerPowerDist
      andthen {Number.abs Pos.y-TowerPos.y} =< Config.towerPowerDist
   end

   % To add or remove easily a player in the state.
   fun {ChangeNbPlayers TeamNum Weapon State Diff}
      PlayerCat = {GetPlayerCategory Weapon}
      NewTeamState = {AdjoinAt State.players.TeamNum
                      PlayerCat
                      State.players.TeamNum.PlayerCat + Diff}
      NewPlayersState = {AdjoinAt State.players TeamNum NewTeamState}
   in
      {AdjoinAt State players NewPlayersState}
   end

   % Create a new Square port object.
   % Pos: the position of the square on the map
   % HomePort: the atom 'none' or the home port if the square contains a home.
   % AllSquares: all the squares objects.
   %             AllSquares.Y.X is the square located at (X;Y).
   % StateStream: the internal state is repeated there (useful for the GUI).
   proc {Create Pos NbTeams HomePort AllSquares ?SquarePort ?StateStream}
      StatePort

      % A new player is on the square
      fun {PlayerIn TeamNum Weapon State ?Dead}
         fun {AddPlayer}
            {ChangeNbPlayers TeamNum Weapon State 1}
         end

         Strength = {GetPlayerStrength Weapon}
      in
         % Killed by the tower of this square.
         if State.tower \= none andthen State.tower.owner \= TeamNum then
            Dead = true
            {WeakenTower Strength State _}

         % Search if there is a dangerous tower in another square.
         else
            Tower = {GetFirstOpponentTower TeamNum State}
         in
            % No dangerous tower, everything is OK.
            if Tower == none then
               Dead = false
               {AddPlayer}

            % There is a dangerous tower, pay attention!
            else
               OK
            in
               % If a lot of players come at once on a square, we send a lot of
               % messages to weaken the tower, and the tower may be destroyed
               % in the meantime.
               {Send Tower.square weakenTower(Strength ?OK)}
               if OK then
                  % I warned you...
                  Dead = true
                  State
               else
                  % You know, you're very lucky!
                  % FIXME search another dangerous tower and try to weaken it
                  Dead = false
                  {AddPlayer}
               end
            end
         end
      end

      % A player has quit the square
      fun {PlayerOut TeamNum Weapon State}
         {ChangeNbPlayers TeamNum Weapon State ~1}
      end

      % Build a tower on this square
      fun {BuildTower TeamNum State ?OK}
         if State.tower \= none then
            OK = false
            State
         else
            OK = true
            {NotifyNeighbourSquares towerBuilt(TeamNum SquarePort Pos)}
            {AdjoinAt State tower tower(owner:TeamNum points:Config.towerInitPoints)}
         end
      end

      % Weaken the tower of this square
      fun {WeakenTower Strength State ?OK}
         if State.tower == none then
            OK = false
            State
         else
            NewTowerPoints = State.tower.points - Strength
            NewTowerState
         in
            OK = true

            if 0 < NewTowerPoints then
               NewTowerState = {AdjoinAt State.tower points NewTowerPoints}
            else
               NewTowerState = none
               {NotifyNeighbourSquares towerDestroyed(SquarePort Pos)}
            end

            {AdjoinAt State tower NewTowerState}
         end
      end

      % Notify the neighbour squares with a message
      proc {NotifyNeighbourSquares Msg}
         Dist = Config.towerVisibleDist
         NbRows = {Width AllSquares}
         NbCols = {Width AllSquares.1}
         MinX = {Max 1 Pos.x-Dist} % Minix!
         MaxX = {Min NbCols Pos.x+Dist}
         MinY = {Max 1 Pos.y-Dist}
         MaxY = {Min NbRows Pos.y+Dist}
         StopPos = pos(x:MaxX y:MaxY)

         fun {GetNextPos Pos}
            if Pos.x < MaxX then
               pos(x:Pos.x+1 y:Pos.y)
            else
               pos(x:MinX y:Pos.y+1)
            end
         end

         proc {NotifyStep CurPos}
            if CurPos \= Pos then
               {Send AllSquares.(CurPos.y).(CurPos.x) Msg}
            end

            if CurPos \= StopPos then
               {NotifyStep {GetNextPos CurPos}}
            end
         end
      in
         {NotifyStep pos(x:MinX y:MinY)}
      end

      % A tower has been built on an neighbour square
      fun {AddTower TeamNum SquarePort TowerPos State}
         NewTower = tower(location:TowerPos owner:TeamNum square:SquarePort)
         NewState
      in
         if {CanKill Pos TowerPos} then
            NewState = {AdjoinAt State nearTowers NewTower|State.nearTowers}
         else
            NewState = State
         end

         % The tower is at least visible
         {AdjoinAt NewState visibleTowers NewTower|State.visibleTowers}
      end

      % A tower has been destroyed on an neighbour square
      fun {RemoveTower SquarePort TowerPos State}
         fun {RemoveInList Towers}
            {Filter Towers fun {$ Tower} Tower.square \= SquarePort end}
         end

         NewNearState
      in
         if {CanKill Pos TowerPos} then
            NewNearState = {AdjoinAt State nearTowers {RemoveInList State.nearTowers}}
         else
            NewNearState = State
         end

         {AdjoinAt NewNearState visibleTowers {RemoveInList State.visibleTowers}}
      end

      fun {GetVisibleTowers State}
         % The return value must be suitable for the brain environment.
         % If this square has a tower, add it to the list.
         if State.tower == none then
            State.visibleTowers
         else
            tower(location:Pos owner:State.tower.owner) | State.visibleTowers
         end
      end

      % The player begins to exploit the resource.
      fun {BeginExploit TeamNum PlayerPort Weapon State ?Dead}
         % Add the player to the exploitation list of his team.
         NewPlayer = player(port:PlayerPort weapon:Weapon dead:Dead)
         NewExpl = {AdjoinAt State.exploitations TeamNum
                    NewPlayer|State.exploitations.TeamNum}

         fun {SearchOtherTeam OtherTeamNum}
            if NbTeams < OtherTeamNum then
               none
            elseif OtherTeamNum \= TeamNum
               andthen NewExpl.OtherTeamNum \= nil then
               OtherTeamNum
            else
               {SearchOtherTeam OtherTeamNum+1}
            end
         end

         fun {GetTotalStrength Team}
            fun {Step List Total}
               case List
               of nil then
                  Total
               [] P|OtherPlayers then
                  {Step OtherPlayers Total + {GetPlayerStrength P.weapon}}
               end
            end
         in
            {Step NewExpl.Team 0}
         end

         proc {SetDead Team IsDead}
            proc {Step List}
               case List
               of nil then
                  skip
               [] P|OtherPlayers then
                  P.dead = IsDead
                  {Step OtherPlayers}
               end
            end
         in
            {Step NewExpl.Team}
         end

         OtherTeamNum = {SearchOtherTeam 1}
      in
         % Only one team is exploiting the resource
         if OtherTeamNum == none then
            {AdjoinAt State exploitations NewExpl}

         % Fight!
         else
            NewTeamStrength = {GetTotalStrength TeamNum}
            OtherTeamStrength = {GetTotalStrength OtherTeamNum}
            NewTeamIsDead = NewTeamStrength =< OtherTeamStrength
            OtherTeamIsDead = OtherTeamStrength =< NewTeamStrength
         in
            {SetDead TeamNum NewTeamIsDead}
            {SetDead OtherTeamNum OtherTeamIsDead}

            {AdjoinAt State exploitations InitExploitations}
         end
      end

      % The player has finished to exploit the resource.
      % Remove the player from the exploitation list.
      fun {EndExploit TeamNum PlayerPort State}
         fun {RemoveInList Players}
            {Filter Players fun {$ P} P.port \= PlayerPort end}
         end

         NewPlayers = {RemoveInList State.exploitations.TeamNum}
         NewExplState = {AdjoinAt State.exploitations TeamNum NewPlayers}
      in
         {AdjoinAt State exploitations NewExplState}
      end

      fun {HandleMsg Msg State}
         % We send the new state to the StatePort only when the UI should be updated
         case Msg
         of playerIn(TeamNum Weapon ?Dead) then
            NewState = {PlayerIn TeamNum Weapon State ?Dead}
         in
            {Send StatePort NewState}
            NewState

         [] playerOut(TeamNum Weapon) then
            NewState = {PlayerOut TeamNum Weapon State}
         in
            {Send StatePort NewState}
            NewState

         [] buildTower(TeamNum ?OK) then
            NewState = {BuildTower TeamNum State ?OK}
         in
            if OK then
               {Send StatePort NewState}
            end
            NewState

         [] weakenTower(Strength ?OK) then
            NewState = {WeakenTower Strength State ?OK}
         in
            % destroyed
            if OK andthen NewState.tower == none then
               {Send StatePort NewState}
            end
            NewState

         [] towerBuilt(TeamNum SquarePort Pos) then
            {AddTower TeamNum SquarePort Pos State}

         [] towerDestroyed(SquarePort Pos) then
            {RemoveTower SquarePort Pos State}

         [] getVisibleTowers(?Towers) then
            Towers = {GetVisibleTowers State}
            State

         [] beginExploit(TeamNum PlayerPort Weapon ?Dead) then
            {BeginExploit TeamNum PlayerPort Weapon State ?Dead}

         [] endExploit(TeamNum PlayerPort) then
            {EndExploit TeamNum PlayerPort State}

         [] getHomePort(?HomePort) then
            HomePort = State.home
            State
         end
      end

      InitPlayers = {MakeTuple players NbTeams}
      InitExploitations = {MakeTuple exploitations NbTeams}
      InitState = state(players: InitPlayers
                        home: HomePort
                        tower: none
                        % A near tower can kill a player
                        nearTowers: nil
                        visibleTowers: nil
                        exploitations: InitExploitations)
   in
      for TeamNum in 1..NbTeams do
         % For each team, we know how many players have a weapon,
         % and how many players don't.
         InitPlayers.TeamNum = team(withoutWeapon:0 withWeapon:0)
         InitExploitations.TeamNum = nil
      end

      {NewPort StateStream StatePort}
      {Send StatePort InitState}
      SquarePort = {Utils.newPortObject HandleMsg InitState}
   end
end
