local Heroes = {"Nami","Brand", "Velkoz"}
if not table.contains(Heroes, myHero.charName) then print("Hero not supported: " .. myHero.charName) return end

local Scriptname,Version,Author,LVersion = "[Auto]","v1.0","Sikaka","0.01"


Callback.Add("Load",
function() 
	_G[myHero.charName]() 
	AutoUtil()
	TPred()
end)
 	

function CurrentPctLife(entity)
	local pctLife =  entity.health/entity.maxHealth  * 100
	return pctLife
end

function CurrentPctMana(entity)
	local pctMana =  entity.mana/entity.maxMana * 100
	return pctMana
end

function isValidTarget(obj,range)
	range = range or math.huge
	return obj ~= nil and obj.valid and obj.visible and not obj.dead and obj.isTargetable and obj.distance <= range
end


function CountEnemies(pos,range)
	local N = 0
	for i = 1,Game.HeroCount()  do
		local hero = Game.Hero(i)	
		if isValidTarget(hero,range) and hero.team ~= myHero.team then
			N = N + 1
		end
	end
	return N	
end

function CurrentTarget(range)
	if _G.SDK then
		return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
	elseif _G.EOW then
		return _G.EOW:GetTarget(range)
	else
		return _G.GOS:GetTarget(range,"AD")
	end
end
 
function Ready(spellSlot)
	return IsReady(spellSlot)
end

function IsReady(spell)
	return Game.CanUseSpell(spell) == 0
end

function IsRecalling()
	for K, Buff in pairs(GetBuffs(myHero)) do
		if Buff.name == "recall" and Buff.duration > 0 then
			return true
		end
	end
	return false
end

class "AutoUtil"
function AutoUtil:GetDistanceSqr(p1, p2)
	assert(p1, "GetDistance: invalid argument: cannot calculate distance to "..type(p1))
	assert(p2, "GetDistance: invalid argument: cannot calculate distance to "..type(p2))
	return (p1.x - p2.x) ^ 2 + ((p1.z or p1.y) - (p2.z or p2.y)) ^ 2
end

function AutoUtil:GetDistance(p1, p2)
	return math.sqrt(self:GetDistanceSqr(p1, p2))
end
function AutoUtil:NearestEnemyDistance(entity)
	local distance = 999999
	for i = 1,Game.HeroCount()  do
		local hero = Game.Hero(i)	
		if isValidTarget(hero,range) and hero.team ~= myHero.team then
			local d = self:GetDistance(entity.pos, hero.pos)
			if d < distance then
				distance = d
			end
		end
	end
	return distance
end

class "Brand"
local WCastPos, WCastTime


--Gets the time until our W will deal damage
function Brand:GetWHitTime()
	local deltaHitTime = WCastTime + W.Delay - Game.Timer()	
	return deltaHitTime
end

function Brand:__init()	
	print("Loaded [Auto] ".. myHero.charName)
	self:LoadSpells()
	self:CreateMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end
function Brand:LoadSpells()
	Q = {Range = 1050, Width = 80, Delay = 0.25, Speed = 1550, Collision = true, aoe = false, Sort = 'line'}
	W = {Range = 900, Width = 250, Delay = 0.625, Speed = math.huge, Collision = false, aoe = true, Sort = "circular"}
	E = {Range = 600, Delay = 0.25, Speed = math.huge, Collision = false }
	R = {Range = 750, Width = 0, Delay = 0.25, Speed = 1700, Collision = false, aoe = false, Sort = "circular"}
end

function Brand:CreateMenu()
	
	AIO = MenuElement({type = MENU, id = myHero.charName, name = "[Auto] "..myHero.charName})
	AIO:MenuElement({id = "Skills", name = "Skills", type = MENU})
	AIO.Skills:MenuElement({id = "QAcc", name = "Auto Q Accuracy", value = 3, min = 1, max = 5, step = 1 })
	
	AIO.Skills:MenuElement({id = "EMan", name = "Auto E Mana", value = 25, min = 1, max = 100, step = 5 })
	
	AIO.Skills:MenuElement({id = "WAcc", name = "Auto W Accuracy", value = 3, min = 1, max = 5, step = 1 })
	AIO.Skills:MenuElement({id = "WMan", name = "Auto W Mana", value = 25, min = 1, max = 100, step = 5})
	
	
	AIO.Skills:MenuElement({id = "RCount", name = "Auto R Enemy Count", value = 3, min = 1, max = 5, step = 1})
		
	AIO:MenuElement({id = "comboActive", name = "Combo key",value = true, toggle = true, key = string.byte(" ")})
	AIO:MenuElement({id = "reactionTime", name = "Target reaction time", value = .5, min = .1, max = 1, step = .05})
end

function Brand:Draw()
	if AIO.comboActive:Value() then
		local textPos = myHero.pos:To2D()
		Draw.Text("ON", 20, textPos.x - 25, textPos.y + 40, Draw.Color(220, 0, 255, 0))
	end
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)    
		if Hero.isEnemy and Hero.pathing.hasMovePath and Hero.pathing.isDashing and Hero.pathing.dashSpeed>500 then
			Draw.Circle(Hero:GetPath(1), 40, 20, Draw.Color(255, 255, 255, 255))
		end
	end
end

function Brand:Tick()	
	if myHero.dead or Game.IsChatOpen() == true or IsRecalling() == true  or not AIO.comboActive:Value() then return end

	Brand:AutoImobileCombo()
		
	--TODO: Clean up rest of the skills to follow new format of other champs
	local target = CurrentTarget(W.Range)
	if target == nil then return end
	local castpos,HitChance, pos = TPred:GetBestCastPosition(target, W.Delay , W.Width, W.Range, W.Speed, myHero.pos, W.Collision, W.Sort, AIO.reactionTime:Value())
	if Ready(_W) and HitChance >= AIO.Skills.WAcc:Value() and myHero.mana/myHero.maxMana >= AIO.Skills.WMan:Value() / 100 then
		Control.CastSpell(HK_W, castpos)
	end
	
	local target = CurrentTarget(E.Range)
	if target == nil then return end
	if Ready(_E) and myHero.mana/myHero.maxMana >= AIO.Skills.EMan:Value() / 100 then
		Control.CastSpell(HK_E, target.pos)
	end
	
	local target = CurrentTarget(Q.Range)
	if target == nil then return end
  
	local castpos,HitChance, pos = TPred:GetBestCastPosition(target, Q.Delay , Q.Width, Q.Range, Q.Speed, myHero.pos, Q.Collision, Q.Sort, AIO.reactionTime:Value())
	if Ready(_Q) and HitChance >= AIO.Skills.QAcc:Value() then
		--Check if target has burn status
		if TPred:HasBuff(target, "BrandAblaze") then				
			Control.CastSpell(HK_Q, castpos)
		end
	end
		
	--Check enemy count near our target. If the target is ablaze and enough enemies, cast ult! 
		--TODO: Check stack counts so that we use ult on 'central' target or one with 2 stacks already to force detonation
	if TPred:HasBuff(target, "BrandAblaze") and Ready(_R) and CountEnemies(target.pos, 350) >=AIO.Skills.RCount:Value() then
		Control.CastSpell(HK_R, target)
	end
end

--Will attempt to W or WQ any champions who are immobile (hourglass, using gapcloser)
function Brand:AutoImobileCombo()
	local target = TPred:GetInteruptTarget(myHero.pos, W.Range, W.Delay, W.Speed, AIO.reactionTime:Value())
	if target ~= nil then
		if Ready(_W) then
			Control.CastSpell(HK_W, target:GetPath(1))
			WCastPos = target:GetPath(1)
			WCastTime = Game.Timer()
		end
		
		local wHitTime = self:GetWHitTime()
		if Ready(_Q) and  wHitTime > 0 and TPred:GetSpellInterceptTime(myHero.pos, target:GetPath(1), Q.Delay, Q.Speed) > wHitTime then
			Control.CastSpell(HK_Q, target:GetPath(1))
		end		
	end
	
	--Check for stasis targets
	local target = TPred:GetStasisTarget(myHero.pos, W.Range, W.Delay, W.Speed, AIO.reactionTime:Value())
	if target ~= nil then
		if Ready(_W) then
			Control.CastSpell(HK_W, target.pos)
			WCastPos = target.pos
			WCastTime = Game.Timer()
		end
		
		local wHitTime = self:GetWHitTime()
		if Ready(_Q) and  wHitTime > 0 and TPred:GetSpellInterceptTime(myHero.pos, target.pos, Q.Delay, Q.Speed) > wHitTime then
			Control.CastSpell(HK_Q, target.pos)
		end
		--Check if our Q will intercept after W and not hit minions on the way, if so cast it as well.		
	end
end


class "Velkoz"

function Velkoz:__init()	
	print("Loaded [Auto] "..myHero.charName)
	self:LoadSpells()
	self:CreateMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Velkoz:LoadSpells()

	Q = {Range = 1050, Width = 55,Delay = 0.251, Speed = 1235,  Sort = "line"}
	W = {Range = 1050, Width = 80,Delay = 0.25, Speed = 1500,  Sort = "line"}
	E = {Range = 850, Width = 235,Delay = 0.75, Speed = math.huge,  Sort = "circular"}
	R = {Range = 1550,Width = 75, Delay = 0.25, Speed = math.huge, Sort = "line" }
end

function Velkoz:CreateMenu()
	AIO = MenuElement({type = MENU, id = myHero.charName, name = "[Auto] " .. myHero.charName})
	
	AIO:MenuElement({id = "Skills", name = "Skills", type = MENU})
	
	--%Mana needed for us to launch a Q vs immobile targets
	AIO.Skills:MenuElement({id = "QMana", name = "Auto Q Mana", value = 25, min = 5, max = 100, step = 1 })
	
	--%Mana needed for us to use W to detonate passive or steal a kill
	AIO.Skills:MenuElement({id = "WDetonateMana", name = "W Mana", value = 50, min = 5, max = 100, step = 5 })
	
	--Timing accuracy (seconds) for our E to land after hourglass/dash
	AIO.Skills:MenuElement({id = "ETiming", name = "E Interupt Delay", value = .25, min = .1, max = 1, step = .05 })	
	
	--Minimum E mana to use on stunned targets
	AIO.Skills:MenuElement({id = "EMana", name = "Auto E Mana", value = 25, min = 5, max = 100, step = 1 })	
	
	AIO:MenuElement({id = "autoSkillsActive", name = "Auto Skills Enabled",value = true, toggle = true, key = 0x7A })
end

function Velkoz:Draw()
	if AIO.autoSkillsActive:Value() then
		local textPos = myHero.pos:To2D()
		Draw.Text("ON", 20, textPos.x - 25, textPos.y + 40, Draw.Color(220, 0, 255, 0))
	end
	
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)    
		if Hero.isEnemy and Hero.pathing.hasMovePath and Hero.pathing.isDashing and Hero.pathing.dashSpeed>500 then
			Draw.Circle(Hero:GetPath(1), 40, 20, Draw.Color(255, 255, 255, 255))
		end
	end
end

function Velkoz:Tick()
	if myHero.dead or Game.IsChatOpen() == true or IsRecalling() == true or not AIO.autoSkillsActive:Value() then return end
	
	if Ready(_E) then 
		self:AutoEInterupt()
	end
	
	if Ready(_W) then
		self:AutoWDetonate()
	end
end


function Velkoz:FindEnemyWithBuff(buffName, range, stackCount)
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)    
		if Hero.isEnemy and AutoUtil:GetDistance(myHero.pos, Hero.pos) <= range then
			for bi = 1, Hero.buffCount do 
			local Buff = Hero:GetBuff(bi)
				if Buff.name == buffName and Buff.duration > 0 and Buff.count >= stackCount then
					return Hero
				end
			end
		end
	end
end

function Velkoz:AutoEInterupt()
	--Use E to target the end of a gapcloser
	local target = TPred:GetInteruptTarget(myHero.pos, E.Range, E.Delay, E.Speed, AIO.Skills.ETiming:Value())
	if target ~= nil then
		Control.CastSpell(HK_E, target:GetPath(1))
	end
	
	--Use E to target the end of a hourglass stasis
	local target = TPred:GetStasisTarget(myHero.pos, E.Range, E.Delay, E.Speed, AIO.Skills.ETiming:Value())
	if target ~= nil then
		Control.CastSpell(HK_E, target.pos)	
	end	
end


--Find an enemy with 2 stacks of passive on them and use W to pop it.
function Velkoz:AutoWDetonate()
	local Enemy = self:FindEnemyWithBuff("velkozresearchstack", W.Range, 2)
	if Enemy ~= nil then	
		local castpos,HitChance, pos = TPred:GetBestCastPosition(Enemy, W.Delay , W.Width, W.Range, W.Speed, myHero.pos, W.Collision, W.Sort)
		if HitChance >= 2 then
			Control.CastSpell(HK_W, castpos)
		end
	end
end

class "Nami"
local _adcHeroes = { "Ashe", "Caitlyn", "Corki", "Draven", "Ezreal", "Graves", "Jhin", "Jinx", "Kalista", "KogMaw", "Lucian", "MissFortune", "Quinn", "Sivir", "Teemo", "Tristiana", "Twitch", "Varus", "Vayne", "Xayah"}
	
function Nami:__init()	
	print("Loaded [Auto] "..myHero.charName)
	self:LoadSpells()
	self:CreateMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end
function Nami:LoadSpells()

	Q = {Range = 875, Width = 200,Delay = 0.95, Speed = math.huge,  Sort = "circular"}
	W = {Range = 725}
	E = { Range = 800}
	R = {Range = 2750,Width = 215, Speed = 850, Delay = 0.5, Sort = "line" }
end

function Nami:CreateMenu()
	AIO = MenuElement({type = MENU, id = myHero.charName, name = "[Auto] " .. myHero.charName})
	
	AIO:MenuElement({id = "Skills", name = "Skills", type = MENU})
	AIO.Skills:MenuElement({id = "QTiming", name = "Q Interupt Delay", value = .25, min = .1, max = 1, step = .05 })
	
	AIO.Skills:MenuElement({id = "WBouncePct", name = "W Health (Bounce)", value = 50, min = 1, max = 100, step = 5 })
	AIO.Skills:MenuElement({id = "WBounceMana", name = "W Mana (Bounce)", value = 50, min = 5, max = 100, step = 5 })
	
	AIO.Skills:MenuElement({id = "WEmergencyPct", name = "W Health (Emergency)", value = 10, min = 1, max = 100, step = 1 })
	AIO.Skills:MenuElement({id = "WEmergencyMana", name = "W Mana (Emergency)", value = 20, min = 5, max = 100, step = 1 })
	
	AIO.Skills:MenuElement({id = "EMana", name = "E Mana", value = 25, min = 5, max = 100, step = 1 })
	
	AIO:MenuElement({id = "autoSkillsActive", name = "Auto Skills Enabled",value = true, toggle = true, key = 0x7A })
end

function Nami:Draw()
	if AIO.autoSkillsActive:Value() then
		local textPos = myHero.pos:To2D()
		Draw.Text("ON", 20, textPos.x - 25, textPos.y + 40, Draw.Color(220, 0, 255, 0))
	end
	
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)    
		if Hero.isEnemy and Hero.pathing.hasMovePath and Hero.pathing.isDashing and Hero.pathing.dashSpeed>500 then
			Draw.Circle(Hero:GetPath(1), 40, 20, Draw.Color(255, 255, 255, 255))
		end
	end
end

function Nami:Tick()
	if myHero.dead or Game.IsChatOpen() == true or IsRecalling() == true or not AIO.autoSkillsActive:Value() then return end	
		
	--Try to interupt dashes or hourglass with Q if we can
	if Ready(_Q) then 
		self:AutoQInterupt()
	end
		
	--Use W on myself or ally if it will also bounce to an enemy. 
	if Ready(_W) and CurrentPctMana(myHero) >= AIO.Skills.WBounceMana:Value() then
		self:AutoWBounce()
	end
	
	--Use W on myself or ally if they are very close to death
	if Ready(_W) and CurrentPctMana(myHero) >= AIO.Skills.WEmergencyMana:Value() then	
			self:AutoWEmergency()
	end
		
	--Use E on our carry if they are attacking the enemy
	if Ready(_E) and CurrentPctMana(myHero) >= AIO.Skills.EMana:Value() then
		self:AutoE()
	end
	
	--Use crucible on carry if they are CCd
	self:AutoCrucible()
end


function Nami:AutoQInterupt()
	--Use Q to target the end of a gapcloser
	local target = TPred:GetInteruptTarget(myHero.pos, Q.Range, Q.Delay, Q.Speed, AIO.Skills.QTiming:Value())
	if target ~= nil then
		Control.CastSpell(HK_Q, target:GetPath(1))
	end
	
	--Use Q to target the end of a hourglass stasis
	local target = TPred:GetStasisTarget(myHero.pos, Q.Range, Q.Delay, Q.Speed, AIO.Skills.QTiming:Value())
	if target ~= nil then
		Control.CastSpell(HK_Q, target.pos)	
	end	
end

function Nami:AutoWEmergency()
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.isAlly and AutoUtil:GetDistance(myHero.pos, Hero.pos) <= W.Range and CurrentPctLife(Hero) <= AIO.Skills.WEmergencyPct:Value() then
			Control.CastSpell(HK_W, Hero.pos)			
		end
	end
end

function Nami:AutoWBounce()
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.isAlly and AutoUtil:GetDistance(myHero.pos, Hero.pos) <= W.Range and CurrentPctLife(Hero) <= AIO.Skills.WBouncePct:Value() then
			if AutoUtil:NearestEnemyDistance(Hero) < 500 then
				Control.CastSpell(HK_W, Hero.pos)
			end
		end
	end
end

function Nami:AutoE()
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if  Hero.isAlly and Hero ~= myHero and AutoUtil:GetDistance(myHero.pos, Hero.pos) <= E.Range and table.contains(_adcHeroes, Hero.charName) then
			--Check for targeted spells on enemies. Useful for caster ADCs
			local targetHandle = nil			
			if Hero.activeSpell and Hero.activeSpell.valid and Hero.activeSpell.target then
				targetHandle = Hero.activeSpell.target
			end
			--Check for a pure auto attack with no modifiers (shouldn't be needed but havent tested fully without it. Remove later)
			if Hero.attackData and Hero.attackData.state == STATE_WINDUP and Hero.attackData.target then
				targetHandle = Hero.attackData.target
			end
			
			if targetHandle then 
				for ei = 1, Game.HeroCount() do
					local Enemy = Game.Hero(ei)
					if Enemy.isEnemy and Enemy.handle == targetHandle then
						Control.CastSpell(HK_E, Hero.pos)
					end
				end
			end
		end
	end
end

function Nami:AutoCrucible()
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.isAlly and Hero ~= myHero then
			--Check if they are hard CCd
			--Check if they are our carry
			--Cast Crucible
		end
	end
end