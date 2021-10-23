local module = {}
local EXECPATH_local = debug.getinfo(1).source:sub(2):gsub("\\","/"):match(".+/"):sub(1,-2)

local stream = require"stream"

local StaticFS = require"ose/staticfs"
local Sleep = require"ose/sleep"
local timer = require"timer"

print("EXECPATH:",_G.EXECPATH)

function module.setupServer(Server,MoonCake)
	local ITUDir = _G.EXECPATH .. "deps/ose/itu/websites"

	Server:get("/ping", function(req, res)
		res:finish("<p>pong</p>")
	end)

	Server:get("/",function(req, res) res:sendFile(ITUDir.."/index.html") end)

	Server:get("/viewer/:username",function(req, res) res:sendFile(ITUDir.."/viewer.html") end)
	Server:get("/admin/editlocation/:locationid",function(req, res) res:sendFile(ITUDir.."/admin/editlocation.html") end)

	StaticFS.addstatic(ITUDir.."/","/")
	StaticFS.addstatic(_G.EXECPATH.."itu/photos","/photos")
	StaticFS.addstatic(_G.EXECPATH.."itu/minphotos","/minphotos")

	----StaticFS.addstatic(_G.EXECPATH.."ssl-certs/","/.well-known/acme-challenge")
	----StaticFS.addstatic(_G.EXECPATH.."zerossl/","/.well-known/acme-challenge")


	Server:use(function(req, res, next)--
		local t = StaticFS.use(req, res)
		if t then next() end
	end)
	
	--[[MoonCake.notFound = function(req, res, err)
	    if(err) then
	        MoonCake.serverError(req, res, err)
	    else
	        --p("404 - Not Found!")
	        --res:status(404):render("./libs/template/404.html")
	        res:sendFile(AnalyticsDir.."/build/index.html")
	    end
	end]]

end

return module



--[[

le.pl --key account.key --csr mydomain.csr --csr-key mydomain.key --crt mydomain.crt --domains "server.roblox.observer" --path /home/bitnami/zerossl/ --generate-missing --unlink

]]
