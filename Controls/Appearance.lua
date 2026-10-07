--errors arent real errors so disable them
---@diagnostic disable

local _, core = ...;

local config = core.config;
local unnamedBackgroundIndex = 0;

function core.HideDefaultTextures(frame, keepTexture)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region ~= keepTexture and region:GetObjectType() == "Texture" then
			region:Hide();
		end;
	end;
end;

function core.CreateControlBackground(frame, inset, nameSuffix)
	local backgroundParent = frame:GetParent() or UIParent;
	local colour = config.backgrounds.chatTab.colour;
	local frameName = frame:GetName();
	if not frameName then
		unnamedBackgroundIndex = unnamedBackgroundIndex + 1;
		frameName = "Control" .. unnamedBackgroundIndex;
	end;
	local background = CreateFrame(
		"Frame",
		"ChitChat" .. frameName .. (nameSuffix or "Background"),
		backgroundParent,
		"BackdropTemplate"
	);
	background:SetFrameStrata(frame:GetFrameStrata());
	background:SetFrameLevel(math.max(backgroundParent:GetFrameLevel(), frame:GetFrameLevel() - 1));
	background:SetPoint("TOPLEFT", frame, "TOPLEFT", -inset, inset);
	background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", inset, -inset);
	background:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	});
	background:SetBackdropColor(colour.r, colour.g, colour.b, colour.a or 1);
	background:SetBackdropBorderColor(0, 0, 0, 1);
	return background;
end;

function core.ApplyControlButtonIcon(button, iconTexture)
	if not button then
		return;
	end;

	iconTexture = iconTexture or config.controlIcon;
	button:SetAlpha(1);
	core.HideDefaultTextures(button);
	local function SetTextureOpaque(texture)
		if not texture then
			return nil;
		end;
		texture:SetAlpha(1);
		texture:SetVertexColor(1, 1, 1, 1);
		if texture.SetDesaturated then
			texture:SetDesaturated(false);
		end;
		if texture.SetIgnoreParentAlpha then
			texture:SetIgnoreParentAlpha(true);
		end;
		return texture;
	end;
	local iconTextures = {};
	local function AddIconTexture(texture)
		texture = SetTextureOpaque(texture);
		if texture then
			iconTextures[#iconTextures + 1] = texture;
		end;
	end;
	if button.SetNormalTexture then
		button:SetNormalTexture(iconTexture);
		AddIconTexture(button:GetNormalTexture());
	end;
	if button.SetPushedTexture then
		button:SetPushedTexture(iconTexture);
		AddIconTexture(button:GetPushedTexture());
	end;
	if button.SetDisabledTexture then
		button:SetDisabledTexture(iconTexture);
		AddIconTexture(button:GetDisabledTexture());
	end;
	button.ChitChatIconTextures = iconTextures;
	return core.CreateControlBackground(button, 2, "Background");
end;

function core.HideSocialButtonDecorations(button)
	for _, region in ipairs({ button:GetRegions() }) do
		if region:GetObjectType() == "FontString" then
			region:Hide();
		end;
	end;
	for _, child in ipairs({ button:GetChildren() }) do
		child:Hide();
	end;
end;
