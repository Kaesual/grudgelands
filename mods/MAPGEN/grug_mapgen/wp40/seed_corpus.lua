-- Fixed WP40 seed corpus foundation. Slots 28-32 intentionally remain
-- unresolved until T2 measurement and T9 production-seed selection.

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
	"14570731025329063210",
}

corpus.sha_labels = {
	{label = "grudgelands-wp40-seed-01", digest = "7ff24c89bd170c96998174d1c6cb47fae6d53aa397956633ec017806d8319f07", first8 = "7ff24c89bd170c96", decimal = "9219515541647461526"},
	{label = "grudgelands-wp40-seed-02", digest = "64b9a653b4f2b7d8d762f170427314dda639b603382fb88bbc50344f11890af6", first8 = "64b9a653b4f2b7d8", decimal = "7258015152932567000"},
	{label = "grudgelands-wp40-seed-03", digest = "86ab5f801cd4b1b7aec86fd2dbd1969fe540bbe152e7e5a46c433c9b384cfa0c", first8 = "86ab5f801cd4b1b7", decimal = "9703954825944019383"},
	{label = "grudgelands-wp40-seed-04", digest = "6227ead45bd6f519c280727f8606445c2cc04481c6969ceee9ea4807556d6f46", first8 = "6227ead45bd6f519", decimal = "7072879937603433753"},
	{label = "grudgelands-wp40-seed-05", digest = "60fa4f248299865b0e9873dccd1969569ddb826bf015627e210ddcdaf653d7b0", first8 = "60fa4f248299865b", decimal = "6987984790047262299"},
	{label = "grudgelands-wp40-seed-06", digest = "70abe95007b0c37179d4a08f776121f9035d8eae8941c0308c9f290a2ed8d43b", first8 = "70abe95007b0c371", decimal = "8118839283201131377"},
	{label = "grudgelands-wp40-seed-07", digest = "ca35a2ab2280852a40bcaf678d998cb29c33a0b376499507d77acaad2bb0c9f8", first8 = "ca35a2ab2280852a", decimal = "14570731025329063210"},
}

corpus.pending = {
	{
		slots = "28-31",
		status = "T2_MEASURED",
		label = "grudgelands-wp40-extreme-NNNN",
		decimal = "DO_NOT_INVENT",
		rule = "Candidates 0000-4095 from SHA-256 label grudgelands-wp40-extreme-NNNN; select greatest/least coast then greatest/least non-coast normalized score, skip duplicates, numeric-decimal seed tie-break.",
	},
	{
		slots = "32",
		status = "T9_PRODUCTION",
		label = "production-or-next-unique-seed-label",
		decimal = "DO_NOT_INVENT",
		rule = "Selected production seed after all audits; if already present use the next unique broad label starting at grudgelands-wp40-seed-08.",
	},
}

function corpus.fixture_rows()
	local rows = {}
	for i = 1, #corpus.fixed do
		local label = "literal"
		if i > 20 then label = corpus.sha_labels[i - 20].label end
		rows[i] = {tostring(i), "fixed", label, corpus.fixed[i]}
	end
	for i = 1, #corpus.pending do
		local pending = corpus.pending[i]
		rows[#rows + 1] = {pending.slots, pending.status, pending.label,
			pending.decimal}
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
	if #corpus.fixed ~= 27 then error("WP40 fixed seed count changed", 0) end
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
