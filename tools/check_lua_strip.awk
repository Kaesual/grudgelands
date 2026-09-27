# Lua 5.1 comment/string stripper for the grep sweeps of tools/check_lua.sh.
#
#   awk -v mode=code -f tools/check_lua_strip.awk file.lua
#   awk -v mode=text -f tools/check_lua_strip.awk file.lua
#
# Prints the file with the same number of lines, so rg line numbers still
# point at the source. Comments (`-- ...` and `--[=*[ ... ]=*]`) become one
# space and long-bracket strings (`[=*[ ... ]=*]`, where no escape is
# processed in either build) become `""`. mode=code also replaces every short
# string literal by `""`; mode=text keeps short strings verbatim (sweep 2
# looks for escapes inside them). Only meant for files the luac51 parser
# accepted: an unterminated short string ends at the end of its line.

function long_open(s) {
	# length of a long-bracket opener `[`, `=`*, `[` at the start of s, or 0
	if (match(s, /^\[=*\[/)) return RLENGTH
	return 0
}

BEGIN {
	if (mode != "code" && mode != "text") {
		print "check_lua_strip.awk: mode must be code or text" > "/dev/stderr"
		exit 2
	}
	state = 0   # 0 code, 1 inside a long bracket, 2 inside a short string
	level = 0   # number of `=` of the open long bracket
	quote = ""
}

{
	line = $0
	n = length(line)
	out = ""
	i = 1
	cont = 0    # this line ends inside a short string with backslash-newline
	while (i <= n) {
		if (state == 1) {
			closer = "]"
			for (k = 0; k < level; k++) closer = closer "="
			closer = closer "]"
			p = index(substr(line, i), closer)
			if (p == 0) {
				i = n + 1
			} else {
				i += p - 1 + length(closer)
				state = 0
			}
			continue
		}
		if (state == 2) {
			c = substr(line, i, 1)
			if (mode == "text") out = out c
			if (c == "\\") {
				if (i == n) { cont = 1; i++; continue }   # backslash-newline
				if (mode == "text") out = out substr(line, i + 1, 1)
				i += 2
				continue
			}
			i++
			if (c == quote) state = 0
			continue
		}
		# state 0: copy code up to the next character that may open a
		# comment, a string or a long bracket
		rest = substr(line, i)
		if (!match(rest, /[-"'[]/)) { out = out rest; break }
		out = out substr(rest, 1, RSTART - 1)
		i += RSTART - 1
		c = substr(line, i, 1)
		if (c == "-") {
			if (substr(line, i + 1, 1) != "-") { out = out c; i++; continue }
			out = out " "
			ol = long_open(substr(line, i + 2))
			if (ol > 0) {
				state = 1; level = ol - 2
				i += 2 + ol
			} else {
				i = n + 1   # line comment
			}
			continue
		}
		if (c == "[") {
			ol = long_open(substr(line, i))
			if (ol == 0) { out = out c; i++; continue }
			state = 1; level = ol - 2
			out = out "\"\""
			i += ol
			continue
		}
		# c is " or '
		state = 2; quote = c
		out = out (mode == "text" ? c : "\"\"")
		i++
	}
	# a short string without a backslash-newline cannot span lines
	if (state == 2 && !cont) state = 0
	print out
}
