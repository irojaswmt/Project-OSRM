-- Car profile

-- Begin of globals

bollards_whitelist = { [""] = true, ["cattle_grid"] = true, ["border_control"] = true, ["toll_booth"] = true, ["no"] = true, ["sally_port"] = true, ["gate"] = true}
access_tag_whitelist = { ["yes"] = true, ["motorcar"] = true, ["motor_vehicle"] = true, ["vehicle"] = true, ["permissive"] = true, ["designated"] = true  }
access_tag_blacklist = { ["no"] = true, ["private"] = true, ["agricultural"] = true, ["forestery"] = true }
access_tag_restricted = { ["destination"] = true, ["delivery"] = true }
access_tags = { "motorcar", "motor_vehicle", "vehicle" }
service_tag_restricted = { ["parking_aisle"] = true }
ignore_in_grid = { ["ferry"] = true, ["pier"] = true }

speed_profile = { 
  ["motorway"] = 100, 
  ["motorway_link"] = 90, 
  ["trunk"] = 90, 
  ["trunk_link"] = 90,
  ["primary"] = 70,
  ["primary_link"] = 60,
  ["secondary"] = 60,
  ["secondary_link"] = 50,
  ["tertiary"] = 50,
  ["tertiary_link"] = 40,
  ["unclassified"] = 30,
  ["residential"] = 40,
  ["road"] = 40,
  ["living_street"] = 10,
  ["service"] = 15,
--  ["track"] = 5,
  ["ferry"] = 5,
  ["pier"] = 5,
  ["default"] = 50
}


take_minimum_of_speeds 	= true
obey_oneway 			= true
obey_bollards 			= true
use_restrictions 		= true
ignore_areas 			= true -- future feature
traffic_signal_penalty 	= 2
u_turn_penalty 			= 20

-- End of globals

function node_function (node)
  local barrier = node.tags:Find ("barrier")
  local access = node.tags:Find ("access")
  local traffic_signal = node.tags:Find("highway")
  
  --flag node if it carries a traffic light
  
  if traffic_signal == "traffic_signals" then
	node.traffic_light = true;
  end
  
  if obey_bollards then
	  --flag node as unpassable if it black listed as unpassable
	  if access_tag_blacklist[barrier] then
		node.bollard = true;
	  end
	  
	  --reverse the previous flag if there is an access tag specifying entrance
	  if node.bollard and not bollards_whitelist[barrier] and not access_tag_whitelist[barrier] then
		node.bollard = false;
	  end
  end
  return 1
end

function way_function (way, numberOfNodesInWay)

  -- A way must have two nodes or more
  if(numberOfNodesInWay < 2) then
    return 0;
  end
  
  -- First, get the properties of each way that we come across
    local highway = way.tags:Find("highway")
    local name = way.tags:Find("name")
    local ref = way.tags:Find("ref")
    local junction = way.tags:Find("junction")
    local route = way.tags:Find("route")
    local maxspeed = parseMaxspeed(way.tags:Find ( "maxspeed") )
    local man_made = way.tags:Find("man_made")
    local barrier = way.tags:Find("barrier")
    local oneway = way.tags:Find("oneway")
    local cycleway = way.tags:Find("cycleway")
    local duration  = way.tags:Find("duration")
    local service  = way.tags:Find("service")
    local area = way.tags:Find("area")
    local access = way.tags:Find("access")

  -- Second parse the way according to these properties

	if ignore_areas and ("yes" == area) then
		return 0
	end
		
  -- Check if we are allowed to access the way
    if access_tag_blacklist[access] ~=nil and access_tag_blacklist[access] then
		return 0;
    end
    
  -- Check if our vehicle types are forbidden
    for i,v in ipairs(access_tags) do 
      local mode_value = way.tags:Find(v)
      if nil ~= mode_value and "no" == mode_value then
	    return 0;
      end
    end
  
    
  -- Set the name that will be used for instructions  
	if "" ~= ref then
	  way.name = ref
	elseif "" ~= name then
	  way.name = name
	end
	
	if "roundabout" == junction then
	  way.roundabout = true;
	end

  -- Handling ferries and piers

    if (speed_profile[route] ~= nil and speed_profile[route] > 0) or
       (speed_profile[man_made] ~= nil and speed_profile[man_made] > 0) 
    then
      if durationIsValid(duration) then
	    way.speed = parseDuration / math.max(1, numberOfSegments-1);
        way.is_duration_set = true;
      end
      way.direction = Way.bidirectional;
      if speed_profile[route] ~= nil then
         highway = route;
      elseif speed_profile[man_made] ~= nil then
         highway = man_made;
      end
      if not way.is_duration_set then
        way.speed = speed_profile[highway]
      end
      
    end
    
  -- Set the avg speed on the way if it is accessible by road class
    if (speed_profile[highway] ~= nil and way.speed == -1 ) then 
      if (0 < maxspeed and not take_minimum_of_speeds) or (maxspeed == 0) then
        maxspeed = math.huge
      end
      way.speed = math.min(speed_profile[highway], maxspeed)
    end
    
  -- Set the avg speed on ways that are marked accessible
    if access_tag_whitelist[access]  and way.speed == -1 then
      if (0 < maxspeed and not take_minimum_of_speeds) or maxspeed == 0 then
        maxspeed = math.huge
      end
      way.speed = math.min(speed_profile["default"], maxspeed)
    end

  -- Set access restriction flag if access is allowed under certain restrictions only
    if access ~= "" and access_tag_restricted[access] then
	  way.is_access_restricted = true
    end

  -- Set access restriction flag if service is allowed under certain restrictions only
    if service ~= "" and service_tag_restricted[service] then
	  way.is_access_restricted = true
    end
    
  -- Set direction according to tags on way
    if obey_oneway then
      if oneway == "no" or oneway == "0" or oneway == "false" then
	    way.direction = Way.bidirectional
	  elseif oneway == "-1" then
	    way.direction = Way.opposite
      elseif oneway == "yes" or oneway == "1" or oneway == "true" or junction == "roundabout" or highway == "motorway_link" or highway == "motorway" then
		way.direction = Way.oneway
      else
        way.direction = Way.bidirectional
      end
    else
      way.direction = Way.bidirectional
    end
    
  -- Override general direction settings of there is a specific one for our mode of travel
  
    if ignore_in_grid[highway] ~= nil and ignore_in_grid[highway] then
		way.ignore_in_grid = true
  	end
  	way.type = 1
  return 1
end