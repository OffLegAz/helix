--[[
    NutScript is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    NutScript is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with NutScript.  If not, see <http://www.gnu.org/licenses/>.
--]]

nut.class = nut.class or {}
nut.class.list = {}

local charMeta = FindMetaTable("Character")

-- Register classes from a directory.
function nut.class.loadFromDir(directory)
	-- Search the directory for .lua files.
	for k, v in ipairs(file.Find(directory.."/*.lua", "LUA")) do
		-- Get the name without the "sh_" prefix and ".lua" suffix.
		local niceName = v:sub(4, -5)
		-- Determine a numeric identifier for this class.
		local index = #nut.class.list + 1

		for k, v in ipairs(nut.class.list) do
			if (v.uniqueID == niceName) then
				continue
			end
		end

		-- Set up a global table so the file has access to the class table.
		CLASS = {index = index, uniqueID = niceName}
			-- Define some default variables.
			CLASS.name = "Unknown"
			CLASS.desc = "No description available."
			CLASS.limit = 0

			-- For future use with plugins.
			if (PLUGIN) then
				CLASS.plugin = PLUGIN.uniqueID
			end

			-- Include the file so data can be modified.
			nut.util.include(directory.."/"..v, "shared")

			-- Why have a class without a faction?
			if (!CLASS.faction or !team.Valid(CLASS.faction)) then
				ErrorNoHalt("Class '"..niceName.."' does not have a valid faction!\n")
				CLASS = nil

				continue
			end

			-- Allow classes to be joinable by default.
			if (!CLASS.onCanBe) then
				CLASS.onCanBe = function(client)
					return true
				end
			end

			-- Add the class to the list of classes.
			nut.class.list[index] = CLASS
		-- Remove the global variable to prevent conflict.
		CLASS = nil
	end
end

-- Determines if a player is allowed to join a specific class.
function nut.class.canBe(client, class)
	-- Get the class table by its numeric identifier.
	local info = nut.class.list[class]

	-- See if the class exists.
	if (!info) then
		return false, "no info"
	end

	-- If the player's faction matches the class's faction.
	if (client:Team() != info.faction) then
		return false, "not correct team"
	end

	if (client:getChar():getClass() == class) then
		return false, "same class request"
	end

	if (info.limit > 0) then
		if (#nut.class.getPlayers(data.index) >= info.limit) then
			return false, "class is full"
		end
	end

	-- See if the class allows the player to join it.
	return info:onCanBe(client)
end

function nut.class.getPlayers(class)
	local players = {}
	for k, v in ipairs(player.GetAll()) do
		local char = v:getChar()

		if (char and char:getClass() == class) then
			table.insert(players, v)
		end
	end

	return players
end

function charMeta:joinClass(class)
	if (!class) then
		self:kickClass()

		return
	end
	
	local client = self:getPlayer()
	if (nut.class.canBe(client, class)) then
		self:setClass(class)

		hook.Run("OnPlayerJoinClass", client, class)
		return true
	else
		return false
	end
end

function charMeta:kickClass()
	self:setClass()

	local client = self:getPlayer()
	hook.Run("OnPlayerJoinClass", client, class)
end

function GM:OnPlayerJoinClass(client, class)
	local info = nut.class.list[class]

	if (info.onSet) then
		info:onSet(client)
	end

	netstream.Start(player.GetAll(), "classUpdate")
end