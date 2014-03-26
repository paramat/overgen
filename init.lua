-- overgen 0.1.0 by paramat
-- For latest stable Minetest and back to 0.4.8
-- Depends default
-- License: code WTFPL

-- Parameters

local YMIN = 6000 -- Upper and lower realm limits
local YMAX = 8000
local TCEN = 7000 -- Terrain centre, average surface level
local WATY = 7000 -- Approximate water y, is rounded down to near base of chunk
local TSCA = 128 -- Terrain scale, approximate average height of hills
local STOT = 0.04 -- Stone threshold, depth of stone surface
local STABLE = 2 -- Minimum number of stacked stone nodes in column required to support sand

-- 3D noise for terrain

local np_terrain = {
	offset = 0,
	scale = 1,
	spread = {x=256, y=192, z=256},
	seed = 5900033,
	octaves = 5,
	persist = 0.67
}

-- Stuff

stability = {}

waty = (80 * math.floor((WATY + 32) / 80)) - 32 + 15

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
	if minp.y < YMIN or maxp.y > YMAX then
		return
	end

	local t1 = os.clock()
	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	
	print ("[overgen] chunk minp ("..x0.." "..y0.." "..z0..")")
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()
	
	local c_air = minetest.get_content_id("air")
	local c_stone = minetest.get_content_id("overgen:stone")
	local c_sand = minetest.get_content_id("default:sand")
	local c_desand = minetest.get_content_id("default:desert_sand")
	local c_water = minetest.get_content_id("default:water_source")
	
	local sidelen = x1 - x0 + 1
	local chulens = {x=sidelen, y=sidelen+3, z=sidelen}
	local minpos = {x=x0, y=y0-2, z=z0}
	local nvals_terrain = minetest.get_perlin_map(np_terrain, chulens):get3dMap_flat(minpos)
	
	local ni = 1
	local stable = {}
	local under = {}
	for z = z0, z1 do -- for each xy plane progressing northwards
		for y = y0 - 2, y1 + 1 do -- for each x row progressing upwards
			local vi = area:index(x0, y, z) -- get voxel index for first node in x row
			for x = x0, x1 do -- for each node do
				local si = x - x0 + 1
				local grad = (TCEN - y) / TSCA
				local density = nvals_terrain[ni] + grad
				if y == y0 - 2 then
					if density >= 0 then
						stable[si] = 1
					else
						stable[si] = 0
					end
				elseif y == y0 - 1 then
					if density >= 0 then
						stable[si] = stable[si] + 1
					end
				elseif y >= y0 and y <= y1 then
					if density >= STOT then
						data[vi] = c_stone
						stable[si] = stable[si] + 1
						under[si] = 0
					elseif density >= 0 and density < STOT and stable[si] >= STABLE then
						data[vi] = c_sand
						under[si] = 1
					elseif y <= waty then
						data[vi] = c_water
						stable[si] = 0
						under[si] = 0
					else
						data[vi] = c_air
						if under[si] == 1 then
							local viu = area:index(x, y-1, z)
							data[viu] = c_desand
						end
						stable[si] = 0
						under[si] = 0
					end
				elseif y == y1 + 1 then
					if density < 0 and under[si] == 1 then
						local viu = area:index(x, y-1, z)
						data[viu] = c_desand
					end
				end
				ni = ni + 1 -- increment perlinmap noise index
				vi = vi + 1 -- increment voxel index along x row
			end
		end
	end
	
	vm:set_data(data)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	vm:write_to_map(data)
	local chugent = math.ceil((os.clock() - t1) * 1000)
	print ("[overgen] "..chugent.." ms")
end)