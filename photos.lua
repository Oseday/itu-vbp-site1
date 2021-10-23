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

local vips;
if pcall(require,"vips") then 
	vips = require"vips" 
else
	p("ERROR; vips could not be loaded")
end

local Tracker = require"ose/itu/tracker"

local OSS = jit.os=="Windows" and "\\" or "/"

local function OSSd(...)
	local s = ""
	for _,v in pairs(...) do
		s = s .. v
	end
	return s
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

local acceptedformats = {
	png=true,jpg=true,pneg=true,svg=true,jpeg=true,tif=true,tiff=true,ep=true,pdf=true,eps=true,ai=true,psd=true,indd=true,gif=true,giff=true
}

local ITUDir = _G.EXECPATH .. OSS.."deps/ose/itu/websites"
local PhotoDir = _G.EXECPATH ..OSS.. "itu" ..OSS.. "photos" ..OSS
local MinPhotoDir = _G.EXECPATH ..OSS.. "itu" ..OSS.. "minphotos" ..OSS

local Photos = {
	test={
		testanimal={"Kgo0bOfbHO.png","JH0SWGSwsd.png"}
	}
}

LoadTable(Photos,"photosmeta")

function addphoto(locid,animalname,photoname,tempdir)
	if animalname:len()<3 then return false,"animal name not long enough",400 end

	photoname = photoname:gsub(" ","")

	local exten = photoname:match(".%w*$"):sub(2):lower()
	if not acceptedformats[exten] then return false,"not an accepted format",400 end

	local loc = PhotoDir..locid
	fs.mkdir(loc)
	local aniloc = loc..OSS..animalname
	fs.mkdir(aniloc)

	local locmin = MinPhotoDir..locid
	fs.mkdir(locmin)
	local anilocmin = locmin..OSS..animalname
	fs.mkdir(anilocmin)

	if not Photos[locid] then Photos[locid]={} end
	if not Photos[locid][animalname] then Photos[locid][animalname]={} end

	local err,notf = fs.renameSync(tempdir, aniloc..OSS..photoname)
	if err == nil then 
		p("ERR1:",notf)
		timer.sleep(50);
		err,notf = fs.renameSync(tempdir, aniloc..OSS..photoname)
		if err == nil then 
			return false,notf,500 
		end
	end

	if vips then
		vips.Image.thumbnail(aniloc..OSS..photoname, 300):write_to_file(anilocmin..OSS..photoname)
	end

	table.insert(Photos[locid][animalname], photoname)

	SaveTable(Photos,"photosmeta")

	return true,"success",200
end

function deletephoto(locid,animalname,photoname)
	if not Photos[locid] or not Photos[locid][animalname] then return false,"no such loc-animal exists",403 end

	local t,b = Photos[locid][animalname]
	local f = 0
	for i,v in pairs(t) do
		if v==photoname then 
			Photos[locid][animalname][i] = Photos[locid][animalname][#Photos[locid][animalname]]
			Photos[locid][animalname][#Photos[locid][animalname]] = nil
			b=v 
		end
	end
	if not b then return false,"no such photo exists",403 end

	fs.unlink(PhotoDir..locid..OSS..animalname..OSS..photoname,function()end)
	fs.unlink(MinPhotoDir..locid..OSS..animalname..OSS..photoname,function()end)

	if #(Photos[locid][animalname]) == 0 then 
		Photos[locid][animalname] = nil 
		fs.rmdir(PhotoDir..locid..OSS..animalname,function()end) 
		fs.rmdir(MinPhotoDir..locid..OSS..animalname,function()end) 
	end

	SaveTable(Photos,"photosmeta")
end

local function strlower(s)
	return s--s:gsub("İ","i"):gsub("Ğ","ğ"):gsub("I","ı"):gsub("Ş","ş"):gsub("Ç","ç"):gsub("Ö","ö"):gsub("Ü","ü"):lower()
end


function module.setupServer(server)
	server:get("/photos/:locid", function(req, res)
		local locid = req.params.locid
		res:sendFile(ITUDir .. "/photosviewer.html")
	end)

	server:post("/photos/:locid/:animalname", function(req, res)
		local locid = req.params.locid
		local animalname = strlower(req.params.animalname)
		if not req.files then res:send("no file sent",400) end
		if not req.files.photo then res:send("file sent was not a photo",400) end
		coroutine.wrap(function()
			local succ,notf,code = addphoto(locid, animalname, req.files.photo.name, req.files.photo.path)
			if not succ then
				p("ERROR:",notf)
				return res:send(notf,code)
			end

			res:send("",200)
		end)()
	end)

	server:delete("/photos/:locid/:animalname", function(req, res)
		local locid = req.params.locid
		local animalname = req.params.animalname

		local photoname = req.body.photoname

		local succ,notf,code = deletephoto(locid,animalname,photoname)
		if not succ then
			p("ERROR:",notf)
			return res:send(notf,code)
		end

		res:send("",200)
	end)

	server:delete("/photos/:locid/:animalname/:photoname", function(req, res)
		local locid = req.params.locid
		local animalname = req.params.animalname
		local photoname = req.params.photoname

		photoname = photoname:gsub("%%20"," ")

		local succ,notf,code = deletephoto(locid,animalname,photoname)
		if not succ then
			p("ERROR:",notf)
			return res:send(notf,code)
		end

		res:send("",200)
	end)

	server:post("/photosmeta/:locid", function(req, res)
		local locid = req.params.locid
		if Photos[locid] then
			res:json(Photos[locid],200)
		else
			res:json({},200)
		end
	end)
end

return module 