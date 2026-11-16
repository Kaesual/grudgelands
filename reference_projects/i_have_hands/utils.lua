utils = {}

function utils.Distance(x1, y1, z1, x2, y2, z2)
  local dx = x2 - x1
  local dy = y2 - y1
  local dz = z2 - z1
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function utils.StringContains(str, find)
  str = string.upper(str)
  find = string.upper(find)
  local i, _ = string.find(str, find)
  return i
end

function utils.SerializeMetaData(data)
  local node_containers = {}
  for i, v in pairs(data:to_table()) do
    local found_container = {}
    for container, container_items in pairs(v) do
      local found_inv = {}
      if type(container_items) == "table" then
        for slot, item in pairs(container_items) do
          table.insert(found_inv, slot, item:to_string())
        end
        found_container[container] = found_inv
      else
        found_container[container] = container_items
      end
    end
    node_containers[i] = found_container
  end
  return core.serialize(node_containers)
end

function utils.DeserializeMetaData(data)
  local node_containers = {}
  for i, v in pairs(data) do
    local found_container = {}
    for container, container_items in pairs(v) do
      local found_inv = {}
      if type(container_items) == "string" then
        found_container[container] = container_items
      else
        for slot, item in pairs(container_items) do
          found_inv[slot] = item
        end
        found_container[container] = found_inv
      end
    end
    node_containers[i] = found_container
  end
  return node_containers
end

function utils.Split(str, delimiter)
	local result = {}
	for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
		table.insert(result, match)
	end
	return result
end
