-- Leprofit: prices. Auction prices come from Auctionator or TradeSkillMaster on this computer (their
-- own scans); vendor prices from what you or the source addon's players recorded at vendors.
-- From the source addon's GetPrice, with the vendor price falling through to the auction when unknown.
local ADDON, ns = ...

local Prices = {}
ns.Prices = Prices

local function Auctionator()
	local api = rawget(_G, "Auctionator")
	api = type(api) == "table" and type(api.API) == "table" and api.API.v1
	return type(api) == "table" and api or nil
end

local function TSM()
	local api = rawget(_G, "TSM_API")
	return (type(api) == "table" and api.GetCustomPriceValue) and api or nil
end

local function TSMPrice(source, itemID)
	local api = TSM()
	if not api then return nil end
	local price = ns.Try(api.GetCustomPriceValue, source, "i:" .. itemID)
	return type(price) == "number" and price > 0 and price or nil
end

-- The lowest buyout: Auctionator's last scan, else TSM's.
function Prices.Buyout(itemID)
	local api = Auctionator()
	if api and api.GetAuctionPriceByItemID then
		local price = ns.Try(api.GetAuctionPriceByItemID, ADDON, itemID)
		if type(price) == "number" and price > 0 then return price end
	end
	return TSMPrice("DBMinBuyout", itemID)
end

-- The market value: TSM only (Auctionator doesn't offer one).
function Prices.Market(itemID)
	return TSMPrice("DBMarket", itemID)
end

-- How many days old Auctionator's price is, or nil if unknown.
function Prices.Age(itemID)
	local api = Auctionator()
	if not (api and api.GetAuctionAgeByItemID) then return nil end
	local age = ns.Try(api.GetAuctionAgeByItemID, ADDON, itemID)
	return type(age) == "number" and age or nil
end

-- What a vendor charges for one, if anyone has recorded it.
function Prices.Vendor(itemID)
	local price = ns.adb and ns.adb.vendorPrices[itemID]
	if price then return price end
	for _, def in pairs(ns.professions) do
		if def.vendorPrices[itemID] then return def.vendorPrices[itemID] end
	end
	return nil
end

-- What buying one costs: a vendor's price (vendors never run out), else the auction house's.
-- Returns the price and where it's from ("vendor" or "auction").
function Prices.Buy(itemID)
	local vendor = Prices.Vendor(itemID)
	if vendor then return vendor, "vendor" end
	local auction = Prices.Buyout(itemID) or Prices.Market(itemID)
	if auction then return auction, "auction" end
	return nil, nil
end

function Prices.HasAuctionator() return Auctionator() ~= nil end
function Prices.HasTSM() return TSM() ~= nil end

function Prices.SourcesText()
	local parts = {}
	if Prices.HasAuctionator() then parts[#parts + 1] = "Auctionator" end
	if Prices.HasTSM() then parts[#parts + 1] = "TSM" end
	if #parts == 0 then return "no auction addon: install Auctionator and scan the auction house" end
	return table.concat(parts, " + ")
end
