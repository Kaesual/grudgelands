local repo=arg[1] or "."
for _,name in ipairs({"character","group"}) do
 io.write(dofile(repo.."/tools/r15_ui_followup/"..name..".lua")(repo))
end
print("round15-ui-followup: PASS")
