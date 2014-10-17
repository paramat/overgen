-- overgen 0.2.0 by paramat
-- For latest stable Minetest and back to 0.4.8
-- Depends default
-- License: code WTFPL

-- use VM for ungen check and scanning chunk below
-- scan to 16 nodes below to initialise stability table 

-- Parameters

local YMIN = -2000 -- Approximate realm base
local YMAX = 1000 -- Approximate atmosphere top
local TCEN = 1 -- Terrain centre, average solid surface level
local WATY = 1 -- Water surface y
local TSCA = 192 -- Terrain scale, approximate average height of hills
local STOT = 0.03 -- Stone threshold, controls depth of stone below surface
local STABLE = 2 -- Minimum number of stacked stone nodes in column required to support sand

-- 3D noise for terrain

local np_terrain = {
	offset = 0,
	scale = 1,
	spread = {x=384, y=192, z=384}, -- largest scale in nodes
	seed = 5900033,
	octaves = 5, -- number of levels of detail
	persist = 0.63 -- roughness / crazyness, 0.4 = smooth, 0.6 = MT standard
}

-- Stuff

minetest.register_on_mapgen_init(function(mgparams)
	minetest.set_mapgen_params({mgname="singlenode", water_level=1})
end)

-- Nodes

minetest.register_node("overgen:stone", {
	description = "OVG Stone",
	tiles = {"default_stone.png"},
	is_ground_content = false,
	groups = {cracky=3},
	drop = "default:stone",
	sounds = default.node_sound_stone_defaults(),
})

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
	if minp.y < YMIN or maxp.y > YMAX then
		return
	end

	local t0 = os.clock()

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
	local c_ignore = minetest.get_content_id("ignore")
	local c_sand = minetest.get_content_id("default:sand")
	local c_desand = minetest.get_content_id("default:desert_sand")
	local c_water = minetest.get_content_id("default:water_source")
	
	local c_ovgstone = minetest.get_content_id("overgen:stone")
	
	local sidelen = x1 - x0 + 1
	local vvii = sidelen + 32
	local chulens = {x=sidelen, y=sidelen+17, z=sidelen}
	local minpos = {x=x0, y=y0-16, z=z0}
	local nvals_terrain = minetest.get_perlin_map(np_terrain, chulens):get3dMap_flat(minpos)
	
	local viu = area:index(x0, y0-1, z0)
	local ungen = data[viu] == c_ignore -- ungenerated mapchunk below
	
	local ni = 1
	local stable = {}
	local under = {}
	for z = z0, z1 do -- for each vertical plane
		for x = x0, x1 do -- set initial values of stability table to zero
			local si = x - x0 + 1 -- stability table index
			stable[si] = 0
		end
		for y = y0 - 16, y1 + 1 do -- for each horizontal row
			local vi = area:index(x0, y, z)
			for x = x0, x1 do -- for each node
				local si = x - x0 + 1
				local grad = (TCEN - y) / TSCA
				local density = nvals_terrain[ni] + grad
				if y < y0 then -- node layers below mapchunk
					if ungen then
						if density >= STOT then -- if node stone
							stable[si] = stable[si] + 1
						elseif density < 0 then -- air or water
							stable[si] = 0
						end
					else
						local nodid = data[vi]
						if nodid == c_air
						or nodid == c_water then
							stable[si] = 0
						elseif nodid == c_ovgstone then
							stable[si] = stable[si] + 1
						end
					end
				elseif y >= y0 and y <= y1 then -- mapchunk
					if density >= STOT then
						data[vi] = c_ovgstone
						stable[si] = stable[si] + 1
						under[si] = 0
					elseif density >= 0 and density < STOT
					and stable[si] >= STABLE then
						data[vi] = c_sand
						under[si] = 1
					elseif y <= WATY then
						data[vi] = c_water
						stable[si] = 0
						under[si] = 0
					else -- air, possibly above surface
						data[vi] = c_air
						if under[si] == 1 then -- if air above surface node
							local viu = vi - vvii -- index of 'under' node
							data[viu] = c_desand -- replace node below with surface node
						end
						stable[si] = 0
						under[si] = 0
					end
				elseif y == y1 + 1 then -- layer of nodes above mapchunk
					if density < 0 and y > WATY then -- air, possibly above surface
						if under[si] == 1 then -- if air above surface node
							local viu = vi - vvii -- index of 'under' node
							data[viu] = c_desand -- replace node below with surface node
						end
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
	--vm:update_liquids()

	local chugent = math.ceil((os.clock() - t0) * 1000)
	print ("[overgen] "..chugent.." ms")
end)
