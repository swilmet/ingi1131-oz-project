functor
import
   QTk at 'x-oz://system/wp/QTk.ozf'
   Application
   Utils
export
   MainWindow
   BindHome
   BindSquare
define
   % A player without a weapon is represented as "a", "b", "c", etc.
   fun {GetTeamID TeamNum}
      [&a + TeamNum - 1]
   end

   % A player with a weapon is represented as "A", "B", "C", etc.
   fun {GetTeamIDWeapon TeamNum}
      [&A + TeamNum - 1]
   end

   class MainWindow
      attr
         resources
         squares
         grid
         winnerTeam
         winnerTeamSet
         normal
         field
         forest
         quarry
         mine

      meth init(Map NbTeams)
         Grid
         WinnerTeamLabel
         Resources = {MakeTuple resources NbTeams}
         TeamsInfo = {MakeTuple td NbTeams}
         H = {Width Map} % height
         W = {Width Map.1} % width
      in
         % Colors
         normal := white
         field := c(255 100 100)
         forest := c(135 75 20)
         quarry := c(180 180 180)
         mine := yellow

         % Show resources of each team
         for TeamNum in 1..NbTeams do
            TeamsInfo.TeamNum = lr(label(text:"Team " # {GetTeamID TeamNum} # ": ")
                                   label(text:"" handle:Resources.TeamNum))
         end

         % Create the window
         {{QTk.build td(
                        % The map
                        grid(handle:Grid bg:white)

                        % Legend
                        lr(label(text:" Home " bg:black fg:white)
                           label(text:" Food " bg:@field)
                           label(text:" Wood " bg:@forest)
                           label(text:" Stone " bg:@quarry)
                           label(text:" Steel " bg:@mine))

                        % Resources of each team
                        TeamsInfo

                        % The winner team
                        label(text:"Winners :" handle:WinnerTeamLabel)

                        % Quit button
                        button(text:"Quit" action:proc {$} {Application.exit 0} end)
                        )} show}

         % Configure the grid
         for I in 1..H-1 do
            {Grid configure(lrline column:1 columnspan:2*W-1 row:I*2 sticky:we)}
         end
         for I in 1..W-1 do
            {Grid configure(tdline  row:1 rowspan:2*H-1 column:I*2 sticky:ns)}
         end
         for I in 1..W do
            {Grid columnconfigure(2*I-1 minsize:43)}
         end
         for I in 1..H do
            {Grid rowconfigure(2*I-1 minsize:43)}
         end

         % Keep a reference to the widgets, so we can modify them later
         grid := Grid
         resources := Resources
         winnerTeam := WinnerTeamLabel
         winnerTeamSet := false

         {self createMap(Map)}
      end

      meth createMap(Map)
         Squares = {MakeTuple squares {Width Map}}
      in
         for Y in {Arity Map} do
            Squares.Y = {MakeTuple row {Width Map.Y}}

            for X in {Arity Map.Y} do
               Squares.Y.X = handle(properties:_ players:_)

               case Map.Y.X
               of normal then
                  {self addSquare(X Y @normal black Squares.Y.X)}
               [] field then
                  {self addSquare(X Y @field black Squares.Y.X)}
               [] forest then
                  {self addSquare(X Y @forest black Squares.Y.X)}
               [] quarry then
                  {self addSquare(X Y @quarry black Squares.Y.X)}
               [] mine then
                  {self addSquare(X Y @mine black Squares.Y.X)}
               [] home then
                  {self addSquare(X Y black white Squares.Y.X)}
               else
                  raise 'Unknown map element: ' # Map.Y.X end
               end
            end
         end

         squares := Squares
      end

      % X: horizontal location (the minimum is 1, the left)
      % Y: vertical location (the minimum is 1, the top)
      % Handle: to be able to modify the label located at (X,Y)
      meth addSquare(X Y Bg Fg ?Handle)
         {@grid configure(td(label(bg: Bg
                                   fg: Fg
                                   width: 5
                                   height: 1
                                   handle: Handle.properties)
                             label(bg: Bg
                                   fg: Fg
                                   width: 5
                                   height: 2
                                   wraplength: 38
                                   handle: Handle.players))
                          row: 2*Y-1
                          column: 2*X-1)}
      end

      meth setResources(TeamNum Res)
         {@resources.TeamNum set("food: " # Res.food #
                                 "  wood: " # Res.wood #
                                 "  stone: " # Res.stone #
                                 "  steel: " # Res.steel)}
      end

      meth setWinnerTeam(TeamNum)
         if {Not @winnerTeamSet} then
            {@winnerTeam set("Winners: Team " # {GetTeamID TeamNum})}
            winnerTeamSet := true
         end
      end

      meth setSquareProperty(X Y Type TeamNum)
         Str
      in
         case Type
         of home then
            Str = "H" # {GetTeamID TeamNum}
         [] tower then
            Str = "T" # {GetTeamID TeamNum}
         [] none then
            Str = ""
         end

         {@squares.Y.X.properties set(Str)}
      end

      % 'Players' is a tuple: for each team, the number of players with and
      % without a weapon.
      meth setSquarePlayers(X Y Players)
         fun {StrCat CurStr StrToAppend}
            Begin
         in
            if CurStr == "" then
               Begin = ""
            else
               Begin = CurStr # " "
            end

            Begin # StrToAppend
         end

         fun {GetString TeamNum Str}
            if {Width Players} < TeamNum then
               Str
            else
               NbWithoutWeapon = Players.TeamNum.withoutWeapon
               NbWithWeapon = Players.TeamNum.withWeapon
               StrWithoutWeapon
               StrWithWeapon
               StrTeam
            in
               if 0 < NbWithoutWeapon then
                  StrWithoutWeapon = NbWithoutWeapon # {GetTeamID TeamNum}
               else
                  StrWithoutWeapon = ""
               end

               if 0 < NbWithWeapon then
                  StrWithWeapon = NbWithWeapon # {GetTeamIDWeapon TeamNum}
               else
                  StrWithWeapon = ""
               end

               StrTeam = {StrCat StrWithoutWeapon StrWithWeapon}
               {GetString TeamNum+1 {StrCat Str StrTeam}}
            end
         end
      in
         {@squares.Y.X.players set({GetString 1 ""})}
      end
   end

   proc {BindHome UI TeamNum Pos ResStream}
      thread
         % Show the home label ("Ha", "Hb", etc.)
         {UI setSquareProperty(Pos.x Pos.y home TeamNum)}

         % Update the number of resources
         for Res in ResStream do
            {UI setResources(TeamNum Res)}

            if {Utils.goalReached Res} then
               {UI setWinnerTeam(TeamNum)}
            end
         end
      end
   end

   proc {BindSquare UI X Y SquareType Stream}
      thread
         for Info in Stream do
            {UI setSquarePlayers(X Y Info.players)}

            % The property of a square can change only when the square is normal.
            if SquareType == normal then
               if Info.tower == none then
                  {UI setSquareProperty(X Y none _)}
               else
                  {UI setSquareProperty(X Y tower Info.tower.owner)}
               end
            end
         end
      end
   end
end
