pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- global variables
t = 0
last_bullet = 3 
update_objects = {}
draw_objects = {}
---------------------

-- lua-object from the following repo (github)
-- copyright 2015 alexander nusov. licensed under the mit license.
-- see @license text at http://www.opensource.org/licenses/mit-license.php
object = {}
function object:__getinstance()
  local o = setmetatable({___instanceof=self}, self)
  self.__index = self
  return o
end

function object:init()
end

function object:delete()
	del(update_objects,self)
	del(draw_objects,self)
end

function object:new(...)
  local o = self:__getinstance()
  o:init(...)
  return o
end

function object:extend(...)
  local cls = self:__getinstance()
  cls.init = function() end

  for k, f in pairs{...} do
    f(cls, self)
  end
  return cls
end

function object.is_typeof(instance, class)
  return instance ~= nil and (instance.___instanceof == class)
end

function object.is_instanceof(instance, class)
  return instance ~= nil and (instance.___instanceof == class or object.is_instanceof(instance.___instanceof, class))
end
---------------------

-- classes
c_cooldown = object:extend(function(class)
	function class:init(cooldown)
		self.cooldown = cooldown		
		self.last_try = -1000
	end
	function class:try()
		if (self.last_try + self.cooldown) <= time() then
			self.last_try = time()
			return true
		else
			return false
		end
	end
end)

c_anim = object:extend(function(class)
	function class:init(name, spritesheet, fps, width, height)	
		self.spritesheet = spritesheet	
		self.current_index = 1
		self.fps = fps			
		self.width = width or 1
		self.height = height or 1	
		self.paused = false	
		self.last_t = time()
		self.name = name
		add(update_objects,self)
	end
	function class:update()		
		if not self.paused and (self.last_t + 1/self.fps) < time() then
			self.current_index += 1
			if self.current_index > #self.spritesheet then
				self.current_index = 1
			end			
			self.last_t = time()		
		end
	end		
	function class:get_sprite()		
		return self.spritesheet[self.current_index]
	end
	function class:pause()
		self.paused = true
	end
	function class:resume()
		self.paused = false
	end
end)

c_animhandler = object:extend(function(class)
	function class:init()
		self.animations = {}
		self.current_animation = nil					
	end
	function class:add(anim)
		local no_anims = self.animations == nil
		self.animations[anim.name] = anim
		if not no_anims then
			self.current_animation = anim
		end
	end
	function class:remove(name, anim)
		self.animations[name] = anim
	end
	function class:pause()
		if self.current_animation then
			self.current_animation:pause()
		end
	end
	function class:resume()
		if self.current_animation then
			self.current_animation:resume()
		end
	end
	function class:set_animation(name)
		self.current_animation = self.animation[name]		
	end
	function class:get_animation()
		if self.current_animation then
			return self.current_animation
		end
	end
end)

c_box = object:extend(function(class)
	function class:init(x1, y1, x2, y2)
		self.x1 = x1
		self.y1 = y1
		self.x2 = x2
		self.y2 = y2
	end	
end)

c_player = object:extend(function(class)
	function class:init()
		self.health = 100
	end	
end)

--enemy states:
-- 0: get to position
-- 1: start attacking
c_enemy = object:extend(function(class)
	function class:init(x,y)
		self.sprite = 17
		self.pos_x = x
		self.pos_y = y
		self.x = x
		self.y = -20
		self.r = 15
		self.box = c_box:new(0, 0, 7, 7)
		self.state = 0	
		self.health = 10			
		add(update_objects,self)
		add(draw_objects,self)
	end

	function class:update()		
		self.y += 0.5
		-- if self.state == 0 then				
		-- self.x = lerp1d(self.x, self.pos_x, 0.05)
		-- self.y = lerp1d(self.y, self.pos_y, 0.05)
		-- if ceil(self.x) == self.pos_x and ceil(self.y) == self.pos_y then
		-- 	self.x = self.pos_x
		-- 	self.y = self.pos_y
		-- 	self.state = 1
		-- end		
		-- end			
		-- self.x = lerp1d(self.x, self.pos_x + (sin(t/50) * self.r), 0.05)			
		-- self.y = lerp1d(self.y, self.pos_y + (sin(t/50) * self.r), 0.1)	
	end

	function class:hurt(modifier)
		self.health += modifier
	end
end)

c_ship = object:extend(function(class)
	function class:init(x,y)		
		self.x = x
		self.y = y
		self.has_shield = true
		self.box = c_box:new(0,2,7,5)	
		self.firing_cooldown = c_cooldown:new(0.12)
		
		self.animations = c_animhandler:new()
		self.animations:add(c_anim:new("idle", {1,2}, 15))

		add(update_objects,self)
		add(draw_objects,self)
	end

	function class:update()	
		-- if (t%6<3) then
		-- 	self.sprite = 1
		-- else
		-- 	self.sprite = 2
		-- end		

		if btn(0) then self.x -= 2 end
		if btn(1) then self.x += 2 end
		if btn(2) then self.y -= 2 end
		if btn(3) then self.y += 2 end
		if btn(4) then 
			self:fire() 
		end
	end

	function class:fire()	
		if self.firing_cooldown:try() then	
			local x,y = self.x,self.y		
			add(bullets, c_bullet:new(x,y))
			add(bullets, c_bullet:new(x+7,y))
		end
	end
end)

c_bullet = object:extend(function(class)
	function class:init(x, y)
		self.sprite = 4
		self.box = c_box:new(0,0,0,1)
		self.x = x		
		self.y = y
		self.dx = 0
		self.dy = -3

		add(update_objects,self)
		add(draw_objects,self)
	end

	function class:update()
		self.x += self.dx
		self.y += self.dy
		if is_offscreen(self.x,self.y) then
			self:delete()		
		end
	end
end)

--------------------

-- core functions
function get_collision_box(s)
	local sbox = {
		x = s.x + s.box.x1,
		y = s.y + s.box.y1,
		width = s.box.x2 - s.box.x1,
		height = s.box.y2 - s.box.y1,
	}
	return sbox
end

function collides_with(s1, s2)
	local a = get_collision_box(s1)
	local b = get_collision_box(s2)
	return (abs(a.x - b.x) * 2 < (a.width + b.width)) and
         (abs(a.y - b.y) * 2 < (a.height + b.height))
end

--------------------

-- helper functions
function is_offscreen(x,y,how_far)
	local offscreen = {0,128}
	if (how_far) then
		offscreen[2] += how_far
		offscreen[1] -= how_far
	end
	if x < offscreen[1] or x > offscreen[2]
		or y < offscreen[1] or y > offscreen[2] then
		return true
	end
	return false
end

function ceil(x)
	return -flr(-x)
end

function lerp1d(start, target, percent)
	return (1-percent)*start + percent*target
end

function merge_tables(tbl1,tbl2)
	for k,v in pairs(tbl2) do 
		tbl1[k] = v 
	end
end

function tbl_removevalue(tbl, val)
	for k,v in pairs(tbl) do
		if v == val then
			tbl[k] = nil
			break
		end
	end
end

--------------------

-- game loop
current_part = 0
function next_part()
	current_part += 1
	if current_part == 1 then
		add(enemies, c_enemy:new(20,20))
		add(enemies, c_enemy:new(60,30))
		add(enemies, c_enemy:new(100,10))
	end
end

--------------------

-- system functions
function _init()
	ship = c_ship:new(60,60)
	player = c_player:new()
	bullets = {}
	enemies = {}
	next_part()
	-- for i=1,10 do		
	-- 	add(enemies, 
	-- 		new_enemy(i*16,30-i*8))
	-- end
end

function _update()
	t+=1

	for u in all(update_objects) do
		u:update()
	end	
end

function _draw()
	cls()
	palt()

	--print(stat(1),0,0,7)

	--spr(ship.sprite,ship.x,ship.y)

	-- for b in all(bullets) do
	-- 	spr(b.sprite,b.x,b.y)
	-- end
		
	for e in all(enemies) do
		-- spr(e.sprite,e.x,e.y)
		-- print(e.x .. ", " .. e.y)
		for b in all(bullets) do
			if collides_with(e, b) then
				e:delete()
				del(enemies,e)
				b:delete()
				del(bullets,b)
			end
		end
	end

	local anim
	for	d in all(draw_objects) do
		if d.animations then			
			anim = d.animations:get_animation()		
			print(anim.last_t .. ", " .. time())	
			if anim then							
				spr(anim:get_sprite(), d.x, d.y, anim.width, anim.height)
			end			
		elseif d.sprite then
			spr(d.sprite, d.x, d.y)
		end		
	end

	if ship.has_shield then
		spr(20, ship.x-4, ship.y-3, 2, 2)
	end

	--health
 	palt(11,true)
 	palt(0,false)
	
	spr(5,5,5,3,1)
	local h = player.health*22/100		
 
	for i = 1,h do
		line(i+5,6,i+5,7, 8)
	end 

	
end
--------------------

__gfx__
0000000000000000000000000000000aa0000000b6666666666666666666666b0000000000000000000000000000000000000000000000000000000000000000
0000000000011000000110000000000aa00000006000000000000000000000060000000000000000000000000000000000000000000000000000000000000000
00700700c0acca0cc0acca0c00000000000000006000000000000000000000060000000000000000000000000000000000000000000000000000000000000000
00077000c01cc10cc01cc10c0000000000000000b6666666666666666666666b0000000000000000000000000000000000000000000000000000000000000000
00077000cc1cc1cccc1cc1cc0000000000000000bbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000
0070070011188111111881110000000000000000bbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000
00000000001a01000010a1000000000000000000bbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000
000000000000a000000a00000000000000000000bbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000
00000000023333203233332002333323000008888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000322332233323322332233233000080000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000033a33a3333333a3333a33333000800000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000b333333bb333333bb333333b008000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000b3b33b3bb3b33b3bb3b33b3b080000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000b0b33b0bb0b3333bb3333b0b080000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000b0b00b0bb0b00b3bb3b00b0b080000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000b00b0000b00b0000b00b00080000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000080000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000080000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000008000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000800000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000080000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000008888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000
