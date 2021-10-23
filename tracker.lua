local mc
if jit.os=="Windows"then
	mc = "mooncake"
else
	mc = "depsMoonCake/mooncake"
end

local fs = require"fs"
local json = require"json"
local timer = require"timer"
local helpers = require(mc.."/libs/helpers")
local tick = function() return helpers.getTime()/1000 end

local quickio = require"ose/quickio"
local pafix = require"ose/pafix"
local rndid = require"ose/rndid"

local OSS = jit.os=="Windows" and "\\" or "/"

function direxists(dir) 
	return os.execute("[ -d itu"..OSS..dir.." ]")==true
end

function makedir(dir)
	return os.execute("mkdir itu"..OSS..dir)
end

function removedir(dir)
	return os.execute("rm -rf itu"..OSS..dir)
end

function GeoDistance(lat1,lon1,lat2,lon2)
	local R = 6371e3
	local p1 = lat1 * math.pi/180
	local p2 = lat2 * math.pi/180
	local dp = (lat2-lat1) * math.pi/180
	local dl = (lon2-lon1) * math.pi/180
	local a = math.sin(dp/2) * math.sin(dp/2) +
			math.cos(p1) * math.cos(p2) *
			math.sin(dl/2) * math.sin(dl/2)
	local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
	return R * c
end

function GetStringGeoDistance(lat1,lon1,lat2,lon2)
	local f = math.floor(GeoDistance(lat1,lon1,lat2,lon2)+0.5)
	return f>900 and "900m" or tostring(f).."m"
end

local function TableToString(t)
	local s = "{"
	for k,v in pairs(t) do
		if type(v)=="string" then v = "[==["..v.."]==]" end
		local ts = type(v)=="table" and TableToString(v) or v
		if ts==true then ts="true" elseif ts==false then ts="false" end
		if type(k)=="number" then
			s=s.."["..k.."]="..ts..","
		else
			s=s.."['"..k.."']="..ts..","
		end
	end
	return s.."}"
end

function TableToLoadstringFormat(t)
	return "return "..TableToString(t)
end

function SerializeHashmap(tab)
	local t = {}
	local f = 0
	for k in pairs(tab) do
		f = f + 1
		t[f]=k
	end
	return t
end

local Users = {testuser={fullname="Test User"},cancakir={fullname="Can Çakır"}}


local Locations = {
	--[[
	["Lokasyon A"] = {checked=true, id="abca", details="",  username="testuser", date="15:07", pos={latitude=0,longitude=0}, dist="1m",},
	["Lokasyon B"] = {checked=true, id="abcb", details="",  username="cancakir", date="10:41", pos={latitude=0,longitude=0}, dist="1m",},
	["Lokasyon C"] = {checked=false, id="abcc", details="", username="", date="", pos={latitude=0,longitude=0}, dist="1m",},
	["Lokasyon D"] = {checked=false, id="abcd", details="", username="", date="", pos={latitude=0,longitude=0}, dist="1m",},
	["Lokasyon E"] = {checked=false, id="abce", details="", username="", date="", pos={latitude=41.0157051,longitude=28.9701888}, dist="1m",},
	]]
}


function ResetLocations()
	for k,v in pairs(Locations) do
		Locations[k].checked = false
		Locations[k].username = ""
		Locations[k].date = ""
		Locations[k].dist = "0m"
	end
	SaveTable(Locations,"locations")
end

local IDtoLoc = {}

local genids = {}

module.Locations = Locations
module.IDtoLoc = IDtoLoc

function newLocation(locationname, details, lat, long, id)
	id = id or rndid(genids)
	Locations[locationname]={
		id=id,
		checked=false, 
		details=details and details or "", 
		username="", 
		date="", 
		pos={latitude=tonumber(lat) or 0,longitude=tonumber(long) or 0}, 
		dist="0m"
	}
	IDtoLoc[id]=locationname
end

local function deleteLocation(location)
	local loc = Locations[location]
	if not loc then
		return "no locations with this name, go back",400
	end
	IDtoLoc[loc.id]=nil
	genids[loc.id]=nil
	Locations[location]=nil
	SaveTable(Locations,"locations")
	return "deleted, go back",200
end

function SaveTable(tab,path)
	local f,w = quickio.write(pafix("itu/"..path), TableToLoadstringFormat(tab))
	if not f then print("ERROR: Couldn't save "..path..":", w) end
end

function LoadTable(tab,path)
	local f,w = quickio.read(pafix("itu/"..path))
	if f then
		for k in pairs(tab) do
			tab[k]=nil
		end
		local temp = loadstring(f)()
		for k,v in pairs(temp) do
			tab[k]=v
		end
	else
		print("Error opening itu/"..path..":", w)
		SaveTable(tab,path)
	end
end

do --Server start read users and locations
	LoadTable(Users,"users")
	LoadTable(Locations,"locations")
	for k,v in pairs(Locations) do
		genids[v.id] = true
		IDtoLoc[v.id] = k
	end
end

do --Server interval timer
	local h,m,s = 06,10,10
	function EverydayResetter()
		print"daily reset"
		ResetLocations()
		local timet = os.time()
		local ct = os.date("*t",timet)
		local nct = os.date("*t",timet)
		nct.hour = h
		nct.min = m
		nct.sec = s-1
		if timet > os.time(nct) then
			ct = os.date("*t",timet + (24-ct.hour)*3600)
		end
		ct.hour = h
		ct.min = m
		ct.sec = s
		local interval = os.time(ct)-timet
		if interval <= 1 then
			interval = 1
		end
		print("waiting for:",interval)
		timer.setTimeout(interval*1000, EverydayResetter)
	end
	EverydayResetter()
end


function module.setupServer(server)

	server:post("/login", function(req, res)
		local username = req.body.username
		if Users[username] then
			res:send("",200)
		else
			res:send("",400)
		end
	end)

	server:post("/viewer/tabledata", function(req, res)
		local t = {}
		for Location,tab in pairs(Locations) do
			local occupancy = tab.username
			local isChecked = tab.checked

			local isDisabled = not( (occupancy == "") or (occupancy == req.body.username) )

			t[#t+1]={Location, isChecked, isDisabled, (occupancy~="") and Users[occupancy].fullname or "", tab.date, tab.details, tab.dist, tab.pos, tab.id}
		end
		res:json(t,200)
	end)


	server:post("/viewer/tabledata-v2", function(req, res)
		req.body.username = req.body.username or ""
		local t = {}
		for Location,tab in pairs(Locations) do
			t[#t+1]={
				loc=Location,
				checked=tab.checked,
				disabled=not( (tab.username == "") or (tab.username == req.body.username) ),
				occupancy=(tab.username~="") and Users[tab.username].fullname or "",
				date=tab.date,
				details=tab.details,
				dist=tab.dist,
				pos=tab.pos,
				id=tab.id,
			}
		end
		res:json(t,200)
	end)

	server:post("/viewer/tablesubmit", function(req, res)

		p(req.body)

		local username = req.body.username

		if not Users[username] then
			res:send("Invalid username",400)
		end

		local dataT = req.body.data
		local pos = req.body.pos

		local data = {}
		for i,v in pairs(dataT) do
			data[v.name]=v.value
		end

		for loc,tab in pairs(Locations) do
			if data[loc] then
				if tab.username == ""  then
					Locations[loc].username = username
					Locations[loc].checked = true
					Locations[loc].date = os.date("%H:%M", os.time()+3*60*60)
					local posL = Locations[loc].pos
					p(loc, pos, posL)
					Locations[loc].dist = GetStringGeoDistance(pos.latitude,pos.longitude,posL.latitude,posL.longitude)
				end
			else
				if tab.checked and tab.username == username then
					Locations[loc].username = ""
					Locations[loc].checked = false
					Locations[loc].date = ""
					Locations[loc].dist = "0m"
				end
			end
		end

		res:send("Success",200)
	end)

	server:post("/admin/editlocation", function(req, res)
		local id = req.body.id
		if not id then
			res:send("No location id var body",400)
		end
		local locationname = IDtoLoc[id]
		if not locationname then
			res:send("No location with that id",400)
		end
		local loc = Locations[locationname]
		local tab = {
			id = id,
			location = locationname,
			details = loc.details,
			latitude = loc.pos.latitude,
			longitude = loc.pos.longitude,
		}
		res:json(tab,200)
	end)

	server:post("/admin/editlocation/edit", function(req, res)
		local id = req.body.id
		if not id then
			res:send("No location id var body",400)
		end

		if not IDtoLoc[id] then
			res:send("No location with that id",400)
		end

		local locname = IDtoLoc[id]

		deleteLocation(locname)

		local loc = Locations[locname]

		p(req.body.location,req.body.details,req.body.pos.latitude,req.body.pos.longitude, id)

		newLocation(req.body.location,req.body.details,req.body.pos.latitude,req.body.pos.longitude, id)
		SaveTable(Locations,"locations")

		res:send("",200)
	end)


	server:post("/admin/userdata", function(req, res)
		local t = {}
		for username,v in pairs(Users) do

			local owned = ""
			for loc,ltab in pairs(Locations) do
				if ltab.username == username then
					owned = owned .. loc .. ", " 
				end
			end
			owned = owned:sub(1,-3)

			t[#t+1] = {username, v.fullname, owned}
		end
		res:json(t,200)
	end)

	server:post("/admin/createuser", function(req, res)
		p(req.body)
		p(req.body.username)
		if Users[req.body.username] then
			res:send("already an user with this name, go back",400)
		end
		Users[req.body.username]={fullname=req.body.fullname}
		p("created")
		SaveTable(Users,"users")
		res:send("created, go back",200)
	end)

	local function deleteuser(username)
		if not Users[username] then
			return "no user with this name, go back",400
		end
		Users[username]=nil
		SaveTable(Users,"users")
		return "deleted, go back",200
	end

	server:post("/admin/deleteuser", function(req, res)
		res:send(deleteuser(req.body.username))
	end)

	server:post("/admin/bulkdeleteusers", function(req, res)
		for username in pairs(req.body) do
			deleteuser(username)
		end
		res:send("deleted",200)
	end)



	server:get("/admin/resetalllocations", function(req, res)
		ResetLocations()
		res:send("Locations reset, go back",200)
	end)

	server:post("/admin/createlocation", function(req, res)
		req.body = json.parse((next(req.body)))
		if Locations[req.body.location] then
			res:send("already a location with this name, go back",400)
		end
		--tonumber(req.body.pos.longitude)
		newLocation(req.body.location,req.body.details,req.body.pos.latitude,req.body.pos.longitude)
		SaveTable(Locations,"locations")
		res:send("created, go back",200)
	end)

	server:post("/admin/locationdata", function(req, res)
		local t = {}
		for k,v in pairs(Locations) do
			local fullname = v.username=="" and "" or Users[v.username].fullname
			t[#t+1] = {k,v.checked,v.username,fullname,v.dist,v.id,v.details,v.date}
		end
		res:json(t,200)
	end)

	server:post("/admin/deletelocation", function(req, res)
		res:send(deleteLocation(req.body.location))
	end)

	server:post("/admin/bulkdeletelocations", function(req, res)
		for location in pairs(req.body) do
			deleteLocation(location)
		end
		res:send("deleted",200)
	end)


	server:get("/locnamefromid/:locid", function(req, res)
		local name = IDtoLoc[req.params.locid]
		if not name then
			res:send("no such location with that id",500)
		end
		res:send(name,200)
	end)
end


return module