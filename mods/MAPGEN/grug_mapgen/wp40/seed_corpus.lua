-- Fixed 32-seed WP40 R6 corpus. Full unsigned-64 values remain decimal text.

local corpus = {}

corpus.fixed = {
	"0", "1", "2", "42", "1013", "20260812", "2147483647",
	"2147483648", "2147483649", "4294967295", "4294967296",
	"4294967297", "6442450943", "6442450944", "8589934591",
	"9007199254740991", "9007199254740992", "9007199254740993",
	"18446744073709551615", "1181064378178512398",
	"9219515541647461526", "7258015152932567000",
	"9703954825944019383", "7072879937603433753",
	"6987984790047262299", "8118839283201131377",
	"14570731025329063210", "7821741934987559905",
	"11399677047323745148", "16078439638612932302",
	"14812808310873127952", "5945494226288913660",
}

corpus.sha_labels = {
	{label = "grudgelands-wp40-seed-01", digest = "7ff24c89bd170c96998174d1c6cb47fae6d53aa397956633ec017806d8319f07", first8 = "7ff24c89bd170c96", decimal = "9219515541647461526"},
	{label = "grudgelands-wp40-seed-02", digest = "64b9a653b4f2b7d8d762f170427314dda639b603382fb88bbc50344f11890af6", first8 = "64b9a653b4f2b7d8", decimal = "7258015152932567000"},
	{label = "grudgelands-wp40-seed-03", digest = "86ab5f801cd4b1b7aec86fd2dbd1969fe540bbe152e7e5a46c433c9b384cfa0c", first8 = "86ab5f801cd4b1b7", decimal = "9703954825944019383"},
	{label = "grudgelands-wp40-seed-04", digest = "6227ead45bd6f519c280727f8606445c2cc04481c6969ceee9ea4807556d6f46", first8 = "6227ead45bd6f519", decimal = "7072879937603433753"},
	{label = "grudgelands-wp40-seed-05", digest = "60fa4f248299865b0e9873dccd1969569ddb826bf015627e210ddcdaf653d7b0", first8 = "60fa4f248299865b", decimal = "6987984790047262299"},
	{label = "grudgelands-wp40-seed-06", digest = "70abe95007b0c37179d4a08f776121f9035d8eae8941c0308c9f290a2ed8d43b", first8 = "70abe95007b0c371", decimal = "8118839283201131377"},
	{label = "grudgelands-wp40-seed-07", digest = "ca35a2ab2280852a40bcaf678d998cb29c33a0b376499507d77acaad2bb0c9f8", first8 = "ca35a2ab2280852a", decimal = "14570731025329063210"},
	{label = "grudgelands-wp40-seed-08", digest = "6c8c68d937b5c3e19c702ec9e7bb5aec707724b2fb3fdcf5d9b599cf348ead8c", first8 = "6c8c68d937b5c3e1", decimal = "7821741934987559905"},
	{label = "grudgelands-wp40-seed-09", digest = "9e33c9e05fe7db7cd3abd4221dbef425166daf976892726e966729ae097ef52a", first8 = "9e33c9e05fe7db7c", decimal = "11399677047323745148"},
	{label = "grudgelands-wp40-seed-10", digest = "df2217aa021576ce21b469543fc545c0f928452a761d96f4685e22f199d1adb4", first8 = "df2217aa021576ce", decimal = "16078439638612932302"},
	{label = "grudgelands-wp40-seed-11", digest = "cd91aaad578bfc1000a27da563036c107c2b407c39eaad20c8bbeb8738e870b9", first8 = "cd91aaad578bfc10", decimal = "14812808310873127952"},
	{label = "grudgelands-wp40-seed-12", digest = "5282a37f8c162cfc77aceded6208b7b2b108a506464e0b999cad3e89061d783a", first8 = "5282a37f8c162cfc", decimal = "5945494226288913660"},
}

function corpus.fixture_rows()
	local rows = {}
	for i = 1, #corpus.fixed do
		local label = "literal"
		if i > 20 then label = corpus.sha_labels[i - 20].label end
		rows[i] = {tostring(i), "fixed", label, corpus.fixed[i]}
	end
	return rows
end

local function hex(bytes)
	return (bytes:gsub(".", function(char) return ("%02x"):format(char:byte()) end))
end

local function decimal_mul_add(decimal, multiplier, addend)
	local carry = addend
	local reversed = {}
	for i = #decimal, 1, -1 do
		local digit = decimal:byte(i) - 48
		local value = digit * multiplier + carry
		reversed[#reversed + 1] = string.char(48 + value % 10)
		carry = math.floor(value / 10)
	end
	while carry > 0 do
		reversed[#reversed + 1] = string.char(48 + carry % 10)
		carry = math.floor(carry / 10)
	end
	local result = {}
	for i = #reversed, 1, -1 do result[#result + 1] = reversed[i] end
	return table.concat(result)
end

local function first_eight_decimal(raw)
	local decimal = "0"
	for i = 1, 8 do decimal = decimal_mul_add(decimal, 256, raw:byte(i)) end
	return decimal
end

-- T2/T9 label-derived seeds use this one checked conversion. Full u64 values
-- remain canonical decimal text and never pass through a Lua number.
local function label_seed(label, raw_sha256)
	if type(label) ~= "string" or label == "" or
			not label:match("^grudgelands%-wp40%-%l[%l%d%-]*$") then
		error("WP40 corpus label is invalid", 0)
	end
	if type(raw_sha256) ~= "function" then error("WP40 corpus SHA missing", 0) end
	local raw = raw_sha256(label)
	if type(raw) ~= "string" or #raw ~= 32 then
		error("WP40 corpus label SHA is invalid", 0)
	end
	return {label = label, digest = hex(raw), first8 = hex(raw:sub(1, 8)),
		decimal = first_eight_decimal(raw)}
end
corpus.label_seed = label_seed

local function extreme_candidate(index, raw_sha256)
	if type(index) ~= "number" or index % 1 ~= 0 or index < 0 or index > 4095 then
		error("WP40 extreme candidate index is invalid", 0)
	end
	return label_seed(("grudgelands-wp40-extreme-%04d"):format(index),
		raw_sha256)
end
corpus.extreme_candidate = extreme_candidate

function corpus.verify(raw_sha256)
	if type(raw_sha256) ~= "function" then error("WP40 corpus SHA missing", 0) end
	if #corpus.fixed ~= 32 then error("WP40 fixed seed count changed", 0) end
	for i = 1, #corpus.sha_labels do
		local row = corpus.sha_labels[i]
		local raw = raw_sha256(row.label)
		if type(raw) ~= "string" or #raw ~= 32 or hex(raw) ~= row.digest or
				hex(raw:sub(1, 8)) ~= row.first8 or
				first_eight_decimal(raw) ~= row.decimal or
				corpus.fixed[20 + i] ~= row.decimal then
			error("WP40 seed known answer mismatch at " .. row.label, 0)
		end
	end
	return true
end

return corpus
