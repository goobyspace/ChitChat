--errors arent real errors so disable them
---@diagnostic disable

local _, core = ...;

local unnamedBackgroundIndex = 0;

function core.HideDefaultTextures(frame, keepTexture)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region ~= keepTexture and region:GetObjectType() == "Texture" then
			region:Hide();
		end;
	end;
end;

core.CONTROL_BACKGROUND_INSET = 2;

function core.CreateControlBackground(frame, inset, nameSuffix, chatFrame)
	local backgroundParent = frame:GetParent() or UIParent;
	local frameName = frame:GetName();
	if not frameName then
		unnamedBackgroundIndex = unnamedBackgroundIndex + 1;
		frameName = "Control" .. unnamedBackgroundIndex;
	end;
	local background = CreateFrame(
		"Frame",
		"ChitChat" .. frameName .. (nameSuffix or "Background"),
		backgroundParent
	);
	background:SetFrameStrata(frame:GetFrameStrata());
	background:SetFrameLevel(math.max(backgroundParent:GetFrameLevel(), frame:GetFrameLevel() - 1));
	background:SetPoint("TOPLEFT", frame, "TOPLEFT", -inset, inset);
	background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", inset, -inset);
	core.CreateGradientBackground(background, background, "control", 1, "BACKGROUND", nil, nil, chatFrame);
	return background;
end;

local HOVER_INSET = 1.5;
local PRESSED_INSET = 3;
local INSET_SPEED = 30;

function core.AnimateControlButtonIcon(button, textures)
	if button.ChitChatIconAnimated then
		button.ChitChatIconAnimated.textures = textures;
		return;
	end;
	local state = { textures = textures };
	button.ChitChatIconAnimated = state;
	local current = 0;
	local hovered = false;
	local pressed = false;

	local function Apply(inset)
		for _, texture in ipairs(state.textures) do
			texture:ClearAllPoints();
			texture:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset);
			texture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset);
		end;
	end;

	local function Target()
		if pressed then
			return PRESSED_INSET;
		end;
		return hovered and HOVER_INSET or 0;
	end;

	button:HookScript("OnEnter", function()
		hovered = true;
	end);
	button:HookScript("OnLeave", function()
		hovered = false;
		pressed = false;
	end);
	button:HookScript("OnMouseDown", function()
		pressed = true;
	end);
	button:HookScript("OnMouseUp", function()
		pressed = false;
	end);
	button:HookScript("OnHide", function()
		hovered = false;
		pressed = false;
		current = 0;
		Apply(0);
	end);
	button:HookScript("OnUpdate", function(_, elapsed)
		local target = Target();
		if current == target then
			return;
		end;
		local step = INSET_SPEED * elapsed;
		if math.abs(target - current) <= step then
			current = target;
		else
			current = current + (target > current and step or -step);
		end;
		Apply(current);
	end);
end;

function core.ApplyControlButtonIcon(button, iconTexture, chatFrame)
	if not button then
		return;
	end;

	iconTexture = iconTexture or "Interface\\Worldmap\\ChatBubble_64Grey";
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
	core.AnimateControlButtonIcon(button, iconTextures);
	return core.CreateControlBackground(button, core.CONTROL_BACKGROUND_INSET, "Background", chatFrame);
end;
