---@diagnostic disable

local _, core = ...;

function core.ClampChatFrameToScreen(chatFrame)
	if not chatFrame then
		return;
	end;
	if chatFrame.UpdateClampOffsets and not chatFrame.ChitChatClampHooked then
		hooksecurefunc(chatFrame, "UpdateClampOffsets", function()
			chatFrame:SetClampRectInsets(0, 0, 0, 0);
		end);
		chatFrame.ChitChatClampHooked = true;
	end;
	chatFrame:SetClampRectInsets(0, 0, 0, 0);
	chatFrame:SetClampedToScreen(true);
end;

function core.HookChatFrameCornerPosition(chatFrame)
	if not chatFrame.OnDragStart or not chatFrame.StopMovingOrSizing or not chatFrame.OnSystemPositionChange
		or chatFrame.ChitChatCornerPositionHooked then
		return;
	end;

	hooksecurefunc(chatFrame, "OnDragStart", function(frame)
		frame.ChitChatEditModeDragging = frame.isDragging;
		frame.ChitChatDroppedAtCorner = nil;
	end);

	hooksecurefunc(chatFrame, "StopMovingOrSizing", function(frame)
		if not frame.ChitChatEditModeDragging then
			return;
		end;
		frame.ChitChatEditModeDragging = nil;
		local left = frame:GetLeft();
		local bottom = frame:GetBottom();
		local parentLeft = UIParent:GetLeft();
		local parentBottom = UIParent:GetBottom();
		frame.ChitChatDroppedAtCorner = left and bottom and parentLeft and parentBottom
			and math.abs(left - parentLeft) <= 1
			and math.abs(bottom - parentBottom) <= 1;
	end);

	hooksecurefunc(chatFrame, "OnSystemPositionChange", function(frame)
		local normalizeCorner = frame.ChitChatDroppedAtCorner;
		frame.ChitChatDroppedAtCorner = nil;
		if normalizeCorner then
			frame:ClearAllPoints();
			frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0);
			frame:OnSystemPositionChange();
		end;
	end);
	chatFrame.ChitChatCornerPositionHooked = true;
end;

function core.RestoreSavedBottomLeftAnchor(chatFrame)
	local anchorInfo = chatFrame.systemInfo and chatFrame.systemInfo.anchorInfo;
	if not anchorInfo or anchorInfo.point ~= "BOTTOMLEFT"
		or anchorInfo.relativeTo ~= "UIParent"
		or anchorInfo.relativePoint ~= "BOTTOMLEFT"
		or math.abs(anchorInfo.offsetX or math.huge) > 0.1
		or math.abs(anchorInfo.offsetY or math.huge) > 0.1 then
		return;
	end;

	chatFrame:ClearAllPoints();
	chatFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0);
end;
