local function log(msg) DEFAULT_CHAT_FRAME:AddMessage(msg) end -- alias for convenience

QuestieTracker = CreateFrame("Frame", "QuestieTracker", UIParent, "ActionButtonTemplate")

function QuestieTracker:OnEvent() -- functions created in "object:method"-style have an implicit first parameter of "this", which points to object || in 1.12 parsing arguments as ... doesn't work
	QuestieTracker[event](QuestieTracker, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10) -- route event parameters to Questie:event methods
end
QuestieTracker:SetScript("OnEvent", QuestieTracker.OnEvent)
QuestieTracker:RegisterEvent("PLAYER_LOGIN")
QuestieTracker:RegisterEvent("ADDON_LOADED")

local _QuestWatch_Update = QuestWatch_Update;
local _RemoveQuestWatch = RemoveQuestWatch;
local _IsQuestWatched = IsQuestWatched;
local _GetNumQuestWatches = GetNumQuestWatches;
local _AddQuestWatch = AddQuestWatch;
local _GetQuestIndexForWatch = GetQuestIndexForWatch;
local _QuestLogTitleButton_OnClick = QuestLogTitleButton_OnClick;

local function trim(s)
	return string.gsub(s, "^%s*(.-)%s*$", "%1");
end

function QuestieTracker:addQuestToTracker(questName, desc, typ, done, line, level, isComplete) -- should probably get a table of parameters
	if(type(QuestieCurrentQuests[questName]) ~= "table") then
		QuestieCurrentQuests[questName] = {};
	end
	if(type(QuestieCurrentQuests[questName].tracked) ~= "table") then
		QuestieCurrentQuests[questName]["tracked"] = {};
	end
	
	QuestieCurrentQuests[questName]["tracked"]["line"..line] = desc
	QuestieCurrentQuests[questName]["tracked"]["level"] = level
	QuestieCurrentQuests[questName]["tracked"]["isComplete"] = isComplete
end 

function QuestieTracker:removeQuestFromTracker(questName)
	if(type(QuestieCurrentQuests[questName].tracked) ~= "table") then
		QuestieCurrentQuests[questName]["tracked"] = {};
	end
	QuestieCurrentQuests[questName]["tracked"] = nil
end

function QuestLogTitleButton_OnClick(button)
	if(EQL3_Player) then -- could also hook EQL3_AddQuestWatch(index) I guess
		if ( IsShiftKeyDown() ) then
			QuestieTracker:setQuestInfo(this:GetID());
		end
		_QuestLogTitleButton_OnClick(button);
		EQL3_QuestWatchFrame:Hide();
	else
		if ( button == "LeftButton" ) then
			if ( IsShiftKeyDown() ) then
				if(ChatFrameEditBox:IsVisible()) then
					ChatFrameEditBox:Insert(this:GetText());
				end
				-- add/remove quest to/from tracking
				QuestieTracker:setQuestInfo(Questie:findIdByName(trim(this:GetText())));
			end
			QuestLog_SetSelection(this:GetID() + FauxScrollFrame_GetOffset(QuestLogListScrollFrame))
			QuestLog_Update();
		end	
	end
	
	QuestWatchFrame:Hide()
	this = QuestieTracker;
	this:fillTrackingFrame();
end

function Questie:findIdByName(name)
	for i=1,GetNumQuestLogEntries() do
		local questName, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i);
		if(name == questName) then
			return i;
		end	
	end
end

function QuestieTracker:isTracked(quest)
	if(type(quest) == "string") then
		if(QuestieCurrentQuests[quest] and QuestieCurrentQuests[quest]["tracked"] ~= nil) then
			return true;
		end	
	else
		local questName, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(quest);
		if(QuestieCurrentQuests[questName]["tracked"] ~= nil) then
			return true;
		end	
	end
	return false;
end

function QuestieTracker:setQuestInfo(id)
	local questInfo = {};
	local questName, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(id);
	local startid = GetQuestLogSelection();
	SelectQuestLogEntry(id);
	
	if(QuestieTracker:isTracked(questName)) then
		QuestieTracker:removeQuestFromTracker(questName);
		return;
	end
	
	for i=1, GetNumQuestLeaderBoards() do
		local desc, typ, done = GetQuestLogLeaderBoard(i);
		QuestieTracker:addQuestToTracker(questName, desc, typ, done, i, level, isComplete)
	end
	if(GetNumQuestLeaderBoards() == 0) then
		QuestieTracker:addQuestToTracker(questName, "Run to the end", "", true, 1, level, isComplete)
	end
	SelectQuestLogEntry(startid);
end

function QuestieTracker:PLAYER_LOGIN()
	this:createTrackingFrame();
	this:createTrackingButtons();
	this:RegisterEvent("QUEST_LOG_UPDATE");
	this:RegisterEvent("PLAYER_LOGOUT");
	
	this:syncEQL3();
end

function QuestieTracker:syncEQL3()
	if(EQL3_Player) then
		for id=1, GetNumQuestLogEntries() do
			local questName, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(id);
			if ( not isHeader and EQL3_IsQuestWatched(id) and not this:isTracked(questName) ) then
				for i=1, GetNumQuestLeaderBoards() do
					local desc, typ, done = GetQuestLogLeaderBoard(i);
					this:addQuestToTracker(questName, desc, typ, done, i, level, isComplete);
				end
			elseif( not isHeader and not EQL3_IsQuestWatched(id) and this:isTracked(questName) ) then
				this:removeQuestFromTracker(questName);
			end
		end
	end
end

-- OBVIOUSLY NEEDS A MORE EFFECTIVE SYSTEM! In general, adding/removing notes and updating the visible elements needs to be handled better
-- it takes no strain on performance, but is still done terribly
function QuestieTracker:QUEST_LOG_UPDATE()
	local startid = GetQuestLogSelection();
	for id=1, GetNumQuestLogEntries() do
	
		local questName, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(id);
		if ( AUTO_QUEST_WATCH == "1" and not QuestieCurrentQuests[questName] and not this:isTracked(questName) and not isHeader) then
			this:setQuestInfo(id);
		end
		
		if( this:isTracked(questName) ) then
			SelectQuestLogEntry(id);
			for i=1, GetNumQuestLeaderBoards() do
				local desc, typ, done = GetQuestLogLeaderBoard(i);
				this:addQuestToTracker(questName, desc, typ, done, i, level, isComplete)
			end
		end
	end
	SelectQuestLogEntry(startid);
end

function QuestieTracker:ADDON_LOADED()
	if not ( QuestieTrackerVariables ) then
		QuestieTrackerVariables = {};
		QuestieTrackerVariables["position"] = {
			point = "CENTER",
			relativeTo = "UIParent",
			relativePoint = "CENTER",
			xOfs = 0,
			yOfs = 0,
		};
	end
end

function QuestieTracker:updateTrackingFrameSize()
	local frameHeight = 0;
	local shown = 0;
	for i=1,8 do
		local button = getglobal("QuestieTrackerButton"..i);
		if button:IsShown() then 
			button:SetParent(this.frame);
			button:SetWidth(240);
			local height = 20;
			button:SetHeight(20);
			shown = shown + 1;
			if(i == 1) then
				button:SetPoint("TOPLEFT", this.frame, "TOPLEFT", 5, -5);
			else
				button:SetPoint("TOPLEFT", "QuestieTrackerButton"..i-1, "BOTTOMLEFT", 0, -5);
			end
			for j=1,8 do
				if( getglobal("QuestieTrackerButton"..i.."QuestWatchLine"..j):IsShown() ) then
					height = height + 12;
				end
			end
			button:SetHeight(height);
			frameHeight = frameHeight + height;
		end
		this.frame.buttons[i] = button;
	end
	if shown == 0 then
		this.frame:Hide();
	else
		this.frame:SetHeight(frameHeight+shown*5 + 5);
		this.frame:Show();
	end
end

function QuestieTracker:clearTrackingFrame()
	for i=1, 8 do
		getglobal("QuestieTrackerButton"..i):Hide();
		for j=1,20 do
			getglobal("QuestieTrackerButton"..i.."QuestWatchLine"..j):Hide();
		end
	end
end

function QuestieTracker:getRGBForObjective(objective)
	if not (type(objective) == "function") then -- seriously wtf
		local lastIndex = findLast(objective, ":");
		if not (lastIndex == nil) then -- I seriously CANT shake this habit
			local progress = string.sub(objective, lastIndex+2);
			
			-- There HAS to be a better way of doing this
			local slash = findLast(progress, "/");
			local have = tonumber(string.sub(progress, 0, slash-1))
			local need = tonumber(string.sub(progress, slash+1))
			
			local float = have / need;
			local part = float-0.5;
			if part < 0 then part = 0; end -- derp
			part = part * 2;
			return 1.0-part, float*2, 0;
		end
	end
	return 0.2, 1, 0.2;
end

function QuestieTracker:fillTrackingFrame()

	-- currently if there aren't any notes, it doesn't add the quest to the tracker
	-- eventually, that should be changed, but since we are lacking distance and such, there needs to be some kind of workaround!
	-- like creating dummy notes on SetQuestInfo() probably?
	local BADCODE_ZONEID = getCurrentMapID() -- bad bad bad
	this:clearTrackingFrame();
	local sortedByDistance = {};
	local distanceControlTable = {};
	-- sort notes by distance before using this
	for k,v in (QuestieCurrentNotes) do
		--log(v["questName"] .. "  " .. v["distance"])
		local questName = v["questName"]
		-- needs to somehow include a better way to only include complete waypoints once the quest is completed
		-- would be best to delete all notes except the finisher note once the quest is completed
		-- also find out why some quests, despite lower distance, show up in the wrong order
		-- this just takes the first note (ordered by distance) related to a quest that isn't the pickup
		-- it should therefore always pick the closest note
		-- maybe the distance in QuestieCurrentQuests[questName] isn't always the closest non available one?
		-- that would mean it's only a visual bug
		-- dumping sortedByDistance at the end of this could help
		if( QuestieCurrentQuests[questName] and QuestieCurrentQuests[questName]["tracked"] and v["icon"] ~= "Available" ) then
			if (not distanceControlTable[questName] and v["icon"] ~= "Complete") then
				distanceControlTable[questName] = true; 
				QuestieCurrentQuests[questName]["questName"] = v["questName"];
				QuestieCurrentQuests[questName]["distance"] = v["distance"];
				QuestieCurrentQuests[questName]["formatDistance"] = v["formatDistance"];
				QuestieCurrentQuests[questName]["formatUnits"] = v["formatUnits"];
				QuestieCurrentQuests[questName]["x"] = v["x"];
				QuestieCurrentQuests[questName]["y"] = v["y"];
				--QuestieCurrentQuests[questName]['zoneID'] = v['zoneID'];
				table.insert(sortedByDistance, QuestieCurrentQuests[questName]);
			elseif (v["icon"] == "Complete") then
				for ke,va in pairs(sortedByDistance) do
					if(va["questName"] == questName) then
						table.remove(sortedByDistance, ke);
					end
				end
				distanceControlTable[questName] = true; 
				QuestieCurrentQuests[questName]["questName"] = v["questName"];
				QuestieCurrentQuests[questName]["distance"] = v["distance"];
				QuestieCurrentQuests[questName]["formatDistance"] = v["formatDistance"];
				QuestieCurrentQuests[questName]["formatUnits"] = v["formatUnits"];
				QuestieCurrentQuests[questName]["x"] = v["x"];
				QuestieCurrentQuests[questName]["y"] = v["y"];
				--QuestieCurrentQuests[questName]['zoneID'] = v['zoneID'];
				table.insert(sortedByDistance, QuestieCurrentQuests[questName]);
			end
		end
	end
	
	local i = 1;
	for index,quest in pairs(sortedByDistance) do
		for k,v in pairs(quest) do
			if(k == "tracked") then
				local frame = getglobal("QuestieTrackerButton"..i);
				if not frame then break; end
				frame:Show();
				local j = 1;
				for key,val in pairs(v) do
					if (key == "level") then
						getglobal("QuestieTrackerButton"..i.."HeaderText"):SetText("[" .. val .. "] " .. quest["questName"] .. " (" .. quest["formatDistance"] .. " " .. quest["formatUnits"] .. ")");
						frame.dist = quest["distance"]
						frame.title = quest["questName"]
						frame.point = { 
							x = quest["x"],
							y = quest["y"],
							zoneID = BADCODE_ZONEID
						}
						
					elseif (key == "isComplete") then
						
					else
						getglobal("QuestieTrackerButton"..i.."QuestWatchLine"..j):SetText(val);
						getglobal("QuestieTrackerButton"..i.."QuestWatchLine"..j):SetTextColor(QuestieTracker:getRGBForObjective(val));
						getglobal("QuestieTrackerButton"..i.."QuestWatchLine"..j):Show();
						j = j + 1;
					end
				end
				i = i + 1;
			end
		end
	end
	this:updateTrackingFrameSize();
end

function QuestieTracker:createTrackingButtons()
	this.frame.buttons = {};
	local frameHeight = 20;
	for i=1,8 do
		local button = CreateFrame("Button", "QuestieTrackerButton"..i, this.frame, "QuestieTrackerButtonTemplate");
		button:SetParent(this.frame);
		button:SetWidth(240);
		button:SetHeight(12);
	
		if(i == 1) then
			button:SetPoint("TOPLEFT", this.frame, "TOPLEFT", 5, -15);
			local height = 12;
			for j=1,8 do
				if( getglobal("QuestieTrackerButton"..i.."QuestWatchLine"..j):IsShown() ) then
					height = height + 12;
				end
			end
			button:SetHeight(height);
		else
			button:SetPoint("TOPLEFT", "QuestieTrackerButton"..i-1, "BOTTOMLEFT", 0, -5);
			local height = 12;
			for j=1,8 do
				if( getglobal("QuestieTrackerButton"..i.."QuestWatchLine"..j):IsShown() ) then
					height = height + 12;
				end
			end
			button:SetHeight(height);
		end
		getglobal("QuestieTrackerButton"..i.."HeaderText"):SetText("QuestName");
		frameHeight = frameHeight + button:GetHeight();
		this.frame.buttons[i] = button;
	end
	this.frame:SetHeight(frameHeight+40);
	
	this:fillTrackingFrame();
end

function QuestieTracker:saveFramePosition()
	local frame = getglobal("QuestieTrackerFrame");
	local point, _, relativePoint, xOfs, yOfs = frame:GetPoint();
	-- receiving relativeTo causes wow to crash sometimes
	-- but the values are ALWAYS TOPLEFT, UIParent, TOPLEFT anyway
	QuestieTrackerVariables["position"] = {
		["point"] = point,
		["relativePoint"] = relativePoint,
		["relativeTo"] = "UIParent",
		["yOfs"] = yOfs,
		["xOfs"] = xOfs,
	};
end

function QuestieTracker:createTrackingFrame()
	this.frame = CreateFrame("Frame", "QuestieTrackerFrame", UIParent);
	this.frame:SetWidth(250);
	this.frame:SetHeight(400);
	this.frame:SetPoint(QuestieTrackerVariables["position"]["point"], QuestieTrackerVariables["position"]["relativeTo"], QuestieTrackerVariables["position"]["relativePoint"],
		QuestieTrackerVariables["position"]["xOfs"], QuestieTrackerVariables["position"]["yOfs"]);
	this.frame:SetAlpha(0.2)
	this.frame.texture = this.frame:CreateTexture(nil, "BACKGROUND");
	--this.frame.texture:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background");
	this.frame.texture:SetTexture(0,0,0); -- black
	this.frame.texture:SetAllPoints(this.frame);
	this.frame:Show();
	
	--this.frame:RegisterForDrag("LeftButton");
	this.frame:EnableMouse(true);
	this.frame:SetMovable(true);
	this.frame:SetScript("OnMouseDown", function()
		this:StartMoving();
	end);
	this.frame:SetScript("OnMouseUp", function()
		this:StopMovingOrSizing();
		this:SetUserPlaced(false);
		--can't call saveFramePosition because it RANDOMLY THROWS WOW ERRORS (WTF?)
		QuestieTracker:saveFramePosition()
	end);
end
