functor
import
   Open at 'x-oz://system/Open.ozf'
   OS

   % Our functors
   Config
   Brain
   Gui
   Utils
   Home
   Player
   Square
define
   proc {CreateAllSquares Map Teams ?Squares ?Streams}
      NbRows = {Width Map}
      NbColumns = {Width Map.1}
      NbTeams = {Width Teams}

      fun {GetHomePort X Y}
         fun {SearchHome TeamNum}
            if NbTeams < TeamNum then
               none
            elseif Teams.TeamNum.homePos.x == X andthen Teams.TeamNum.homePos.y == Y then
               Teams.TeamNum.home
            else
               {SearchHome TeamNum+1}
            end
         end
      in
         if Map.Y.X \= home then
            none
         else
            {SearchHome 1}
         end
      end
   in
      Squares = {MakeTuple squares NbRows}
      Streams = {MakeTuple streams NbRows}

      for RowNum in 1..NbRows do
         Squares.RowNum = {MakeTuple row NbColumns}
         Streams.RowNum = {MakeTuple row NbColumns}

         for ColNum in 1..NbColumns do
            Pos = pos(x:ColNum y:RowNum)
            HomePort = {GetHomePort ColNum RowNum}
         in
            {Square.create Pos NbTeams HomePort Squares
             ?Squares.RowNum.ColNum
             ?Streams.RowNum.ColNum}
         end
      end
   end

   % At the beginning of the game, there is two towers in diagonal of each home.
   proc {BuildInitialTowers Squares Team}
      NbRows = {Width Squares}
      NbCols = {Width Squares.1}
   in
      if Team.homePos.x < NbCols andthen 1 < Team.homePos.y then
         TowerX = Team.homePos.x + 1
         TowerY = Team.homePos.y - 1
      in
         {Send Squares.TowerY.TowerX buildTower(Team.num _)}
      end

      if 1 < Team.homePos.x andthen Team.homePos.y < NbRows then
         TowerX = Team.homePos.x - 1
         TowerY = Team.homePos.y + 1
      in
         {Send Squares.TowerY.TowerX buildTower(Team.num _)}
      end
   end

   proc {BuildInitialPlayers Squares Map Team NbTeams}
      StaticEnv = game(board: Map
                       teams: NbTeams
                       team: Team.num
                       goal: Config.goal
                       home: Team.homePos)

      proc {BuildOnePlayer}
         PlayerPort = {Player.create Team Squares Map StaticEnv}
         BrainFunc = {Brain.createBrain StaticEnv none}
      in
         % Bind the player with its brain
         {Player.embody PlayerPort BrainFunc none}
      end
   in
      for I in 1..Config.nbInitialPlayers do
         {BuildOnePlayer}
      end
   end

   % Generate the teams according to the number and locations of the homes in the map.
   % Returns a tuple of teams, of the form:
   % teams(team(num:1 home:HomePort homePos:pos(x:1 y:2))
   fun {GenerateTeams Map UI}
      NbRows = {Width Map}
      NbCols = {Width Map.1}

      fun {GetNextPos Pos}
         if NbCols =< Pos.x then
            pos(x:1 y:Pos.y+1)
         else
            pos(x:Pos.x+1 y:Pos.y)
         end
      end

      fun {TraverseMap Pos Teams NbTeams}
         if NbRows < Pos.y then
            Teams
         else
            NextPos = {GetNextPos Pos}
         in
            if Map.(Pos.y).(Pos.x) == home then
               Port
               ResStream
               TeamNum = NbTeams+1
               NewTeam = team(num:TeamNum home:Port homePos:Pos)
            in
               {Home.create ?Port ?ResStream}
               {Gui.bindHome UI TeamNum Pos ResStream}
               {TraverseMap NextPos {Tuple.append Teams teams(NewTeam)} NbTeams+1}
            else
               {TraverseMap NextPos Teams NbTeams}
            end
         end
      end
   in
      {TraverseMap pos(x:1 y:1) teams() 0}
   end

   % Get a map from a file
   fun {GetMap Filename}
      fun {GetSquareType Char}
         case Char
         of &- then normal
         [] &M then mine
         [] &W then forest
         [] &Q then quarry
         [] &H then home
         [] &F then field
         end
      end

      fun {CreateMap CharsList Map CurRow}
         case CharsList

         % End of the current row
         of Char|NextChars andthen Char == &\n then
            % Add the current row to the map
            NewMap = {Tuple.append Map board(CurRow)}
         in
            {CreateMap NextChars NewMap row()}

         % A square
         [] Char|NextChars then
            SquareType = {GetSquareType Char}
            NewRow = {Tuple.append CurRow row(SquareType)}
         in
            {CreateMap NextChars Map NewRow}

         % End of the map
         [] nil then
            if 0 < {Width CurRow} then
               {Tuple.append Map board(CurRow)}
            else
               Map
            end
         end
      end

      File = {New Open.file init(name:Filename flags:[read])}
      CharsList
   in
      {File read(list:CharsList size:all)}
      {File close}
      {CreateMap CharsList board() row()}
   end

   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   % The "main function"

   Squares
   SquareStreams

   % Create the GUI object
   WorkingDir = {OS.getCWD}
   Map = {GetMap WorkingDir#'/map.txt'}

   Teams = {GenerateTeams Map UI}
   NbTeams = {Width Teams}
   NbRows = {Width Map}
   NbColumns = {Width Map.1}
   UI = {Utils.newActive Gui.mainWindow init(Map NbTeams)}
in
   % Create the squares objects
   {CreateAllSquares Map Teams ?Squares ?SquareStreams}

   % Bind the squares
   for RowNum in 1..NbRows do
      for ColNum in 1..NbColumns do
         {Gui.bindSquare UI ColNum RowNum Map.RowNum.ColNum SquareStreams.RowNum.ColNum}
      end
   end

   % Initial towers for each team
   for TeamNum in 1..NbTeams do
      {BuildInitialTowers Squares Teams.TeamNum}
   end

   % Initial players for each team
   for TeamNum in 1..NbTeams do
      {BuildInitialPlayers Squares Map Teams.TeamNum NbTeams}
   end
end
