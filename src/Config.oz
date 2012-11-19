functor
export
   UnitDelay
   InitResources
   Goal
   BagLimit
   PlayerDefaultStrength
   PlayerWeaponStrength
   TowerInitPoints
   TowerVisibleDist
   TowerPowerDist
   CostWeapon
   CostPlayer
   CostTower
   NbInitialPlayers
define
   UnitDelay = 1000
   InitResources = resources(food:0 wood:0 stone:0 steel:0)
   Goal = resources(food:200 wood:200 stone:200 steel:200)
   BagLimit = 10
   PlayerDefaultStrength = 1
   % A player _with_ a weapon, not the strength of the weapon:
   PlayerWeaponStrength = 3
   TowerInitPoints = 20
   TowerVisibleDist = 4
   TowerPowerDist = 2
   CostWeapon = resources(food:0 wood:0 stone:0 steel:25)
   CostPlayer = resources(food:10 wood:0 stone:0 steel:0)
   CostTower = resources(food:0 wood:50 stone:50 steel:0)
   NbInitialPlayers = 5
end
