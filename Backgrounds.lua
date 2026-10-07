local _, core = ...;

local function Clamp(value, minimum, maximum)
	if value < minimum then
		return minimum;
	end;
	if value > maximum then
		return maximum;
	end;
	return value;
end;

local function GetGradientAlpha(x, width, alpha, edgeAlpha, mainColourRatio)
	if width <= 0 then
		return alpha;
	end;

	local gradientWidth = width * (1 - mainColourRatio) / 2;
	if gradientWidth <= 0 then
		return alpha;
	elseif x < gradientWidth then
		return edgeAlpha + (alpha - edgeAlpha) * (x / gradientWidth);
	elseif x <= width - gradientWidth then
		return alpha;
	end;
	return alpha - (alpha - edgeAlpha) * ((x - (width - gradientWidth)) / gradientWidth);
end;

local function GetOneSidedGradientAlpha(x, width, alpha, edgeAlpha, mainColourRatio, mainColourSide)
	if width <= 0 then
		return alpha;
	end;

	if mainColourSide == "right" then
		local mainStart = width * (1 - mainColourRatio);
		if x >= mainStart then
			return alpha;
		elseif mainStart <= 0 then
			return edgeAlpha;
		end;
		return edgeAlpha + (alpha - edgeAlpha) * (x / mainStart);
	end;

	local mainEnd = width * mainColourRatio;
	if x <= mainEnd then
		return alpha;
	elseif mainEnd >= width then
		return edgeAlpha;
	end;
	return alpha - (alpha - edgeAlpha) * ((x - mainEnd) / (width - mainEnd));
end;

local function CreateMaskIfNeeded(parent, texture, corner, layer)
	if not corner then
		return nil;
	end;

	local mask = parent:CreateMaskTexture(nil, layer);
	mask:SetTexture("Interface\\AddOns\\ChitChat\\Assets\\CornerMask.tga");
	mask:SetAllPoints(texture);
	if corner == "topRight" then
		mask:SetTexCoord(1, 0, 0, 1);
	elseif corner == "bottomLeft" then
		mask:SetTexCoord(0, 1, 1, 0);
	elseif corner == "bottomRight" then
		mask:SetTexCoord(1, 0, 1, 0);
	end;
	texture:AddMaskTexture(mask);
	return mask;
end;

local function CreatePart(parent, colour, layer, subLevel, name, corner, left, right)
	local texture = parent:CreateTexture(nil, layer, nil, subLevel);
	texture:SetColorTexture(colour.r, colour.g, colour.b, 1);
	local part = {
		name = name,
		texture = texture,
		left = left,
		right = right,
		mask = CreateMaskIfNeeded(parent, texture, corner, layer),
	};
	return part;
end;

local function CreateBackgroundParts(parent, colour, radius, oneSidedGradient, mainColourRatio, layer, subLevel)
	local parts = {};
	local regions = {};
	local function AddPart(name, corner, left, right)
		local part = CreatePart(parent, colour, layer, subLevel, name, corner, left, right);
		parts[#parts + 1] = part;
		regions[part.texture] = true;
		return part;
	end;

	if radius > 0 then
		AddPart("topLeft", "topLeft", 0, radius);
		AddPart("top", nil, radius, -radius);
		AddPart("topRight", "topRight", -radius, 0);
		AddPart("left", nil, 0, radius);
		AddPart("center", nil, radius, -radius);
		AddPart("right", nil, -radius, 0);
		AddPart("bottomLeft", "bottomLeft", 0, radius);
		AddPart("bottom", nil, radius, -radius);
		AddPart("bottomRight", "bottomRight", -radius, 0);
	elseif oneSidedGradient then
		if mainColourRatio > 0 then
			AddPart("gradientMain", nil, 0, 0);
		end;
		if mainColourRatio < 1 then
			AddPart("gradientFade", nil, 0, 0);
		end;
	elseif mainColourRatio > 0 then
		AddPart("gradientLeft", nil, 0, 0);
		AddPart("gradientCenter", nil, 0, 0);
		AddPart("gradientRight", nil, 0, 0);
	else
		AddPart("left", nil, 0, 0);
		AddPart("right", nil, 0, 0);
	end;

	return parts, regions;
end;

local function GetRoundedPartBounds(part, width)
	local startX = part.left < 0 and width + part.left or part.left;
	local endX = part.right < 0 and width + part.right or part.right;
	if part.right == 0 and part.left < 0 then
		endX = width;
	end;
	return startX, endX;
end;

local function CreatePartPositioners(anchor, rounded, mainColourRatio, mainColourSide)
	local function GetGradientHalfWidth(width)
		return width * (1 - mainColourRatio) / 2;
	end;

	return {
		gradientMain = function(part, width)
			local startX = mainColourSide == "right" and width * (1 - mainColourRatio) or 0;
			local endX = mainColourSide == "right" and width or width * mainColourRatio;
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", startX, 0);
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", endX, 0);
			return startX, endX;
		end,
		gradientFade = function(part, width)
			local startX = mainColourSide == "right" and 0 or width * mainColourRatio;
			local endX = mainColourSide == "right" and width * (1 - mainColourRatio) or width;
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", startX, 0);
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", endX, 0);
			return startX, endX;
		end,
		gradientLeft = function(part, width)
			local gradientWidth = GetGradientHalfWidth(width);
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT");
			part.texture:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT");
			part.texture:SetWidth(gradientWidth);
			return 0, gradientWidth;
		end,
		gradientCenter = function(part, width)
			local gradientWidth = GetGradientHalfWidth(width);
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", gradientWidth, 0);
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -gradientWidth, 0);
			return gradientWidth, width - gradientWidth;
		end,
		gradientRight = function(part, width)
			local gradientWidth = GetGradientHalfWidth(width);
			part.texture:SetPoint("TOPRIGHT", anchor, "TOPRIGHT");
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT");
			part.texture:SetWidth(gradientWidth);
			return width - gradientWidth, width;
		end,
		topLeft = function(part, width, _, cornerRadius)
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT");
			part.texture:SetSize(cornerRadius, cornerRadius);
			return GetRoundedPartBounds(part, width);
		end,
		top = function(part, width, _, cornerRadius)
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", cornerRadius, 0);
			part.texture:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -cornerRadius, 0);
			part.texture:SetHeight(cornerRadius);
			return GetRoundedPartBounds(part, width);
		end,
		topRight = function(part, width, _, cornerRadius)
			part.texture:SetPoint("TOPRIGHT", anchor, "TOPRIGHT");
			part.texture:SetSize(cornerRadius, cornerRadius);
			return GetRoundedPartBounds(part, width);
		end,
		left = function(part, width, _, cornerRadius)
			if rounded then
				part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -cornerRadius);
				part.texture:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, cornerRadius);
				part.texture:SetWidth(cornerRadius);
				return GetRoundedPartBounds(part, width);
			end;
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT");
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOM");
			return 0, width / 2;
		end,
		center = function(part, width, _, cornerRadius)
			part.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", cornerRadius, -cornerRadius);
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -cornerRadius, cornerRadius);
			return GetRoundedPartBounds(part, width);
		end,
		right = function(part, width, _, cornerRadius)
			if rounded then
				part.texture:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, -cornerRadius);
				part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, cornerRadius);
				part.texture:SetWidth(cornerRadius);
				return GetRoundedPartBounds(part, width);
			end;
			part.texture:SetPoint("TOPLEFT", anchor, "TOP");
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT");
			return width / 2, width;
		end,
		bottomLeft = function(part, width, _, cornerRadius)
			part.texture:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT");
			part.texture:SetSize(cornerRadius, cornerRadius);
			return GetRoundedPartBounds(part, width);
		end,
		bottom = function(part, width, _, cornerRadius)
			part.texture:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", cornerRadius, 0);
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -cornerRadius, 0);
			part.texture:SetHeight(cornerRadius);
			return GetRoundedPartBounds(part, width);
		end,
		bottomRight = function(part, width, _, cornerRadius)
			part.texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT");
			part.texture:SetSize(cornerRadius, cornerRadius);
			return GetRoundedPartBounds(part, width);
		end,
	};
end;

function core.CreateGradientBackground(parent, anchor, settings, alpha, layer, subLevel)
	local colour = settings.colour;
	local radius = math.max(settings.roundedCorners, 0);
	local mainColourRatio = Clamp(settings.gradientMainColourRatio or 0, 0, 1);
	local oneSidedGradient = settings.gradientOneSided;
	local mainColourSide = settings.gradientMainColourSide == "right" and "right" or "left";
	local rounded = radius > 0;

	local parts, regions = CreateBackgroundParts(
		parent,
		colour,
		radius,
		oneSidedGradient,
		mainColourRatio,
		layer,
		subLevel
	);
	local partPositioners = CreatePartPositioners(anchor, rounded, mainColourRatio, mainColourSide);

	local function PositionPart(part, width, height, cornerRadius)
		local texture = part.texture;
		texture:ClearAllPoints();
		local positioner = partPositioners[part.name];
		if not positioner then
			error("ChitChat: No background positioner for part " .. tostring(part.name) .. ".");
		end;
		part.startX, part.endX = positioner(part, width, height, cornerRadius);
	end;

	local lastWidth, lastHeight, lastAlpha;
	local background = {
		regions = regions,
	};
	function background:SetOpacity(opacity)
		local width = anchor:GetWidth();
		local height = anchor:GetHeight();
		if not width or not height then
			return;
		end;
		local cornerRadius = rounded and math.min(radius, width / 2, height / 2) or 0;
		if lastWidth ~= width or lastHeight ~= height then
			for _, part in ipairs(parts) do
				PositionPart(part, width, height, cornerRadius);
			end;
		end;
		if lastAlpha == opacity and lastWidth == width and lastHeight == height then
			return;
		end;

		local effectiveAlpha = opacity * (colour.a or 1);
		local edgeAlpha = effectiveAlpha * (settings.gradientEdgeOpacity or 0.5);
		for _, part in ipairs(parts) do
			local leftAlpha = effectiveAlpha;
			local rightAlpha = effectiveAlpha;
			if settings.useGradient then
				if oneSidedGradient then
					leftAlpha = GetOneSidedGradientAlpha(
						part.startX,
						width,
						effectiveAlpha,
						edgeAlpha,
						mainColourRatio,
						mainColourSide
					);
					rightAlpha = GetOneSidedGradientAlpha(
						part.endX,
						width,
						effectiveAlpha,
						edgeAlpha,
						mainColourRatio,
						mainColourSide
					);
				else
					leftAlpha = GetGradientAlpha(part.startX, width, effectiveAlpha, edgeAlpha, mainColourRatio);
					rightAlpha = GetGradientAlpha(part.endX, width, effectiveAlpha, edgeAlpha, mainColourRatio);
				end;
				part.texture:SetGradient(
					"HORIZONTAL",
					CreateColor(colour.r, colour.g, colour.b, leftAlpha),
					CreateColor(colour.r, colour.g, colour.b, rightAlpha)
				);
			else
				part.texture:SetColorTexture(colour.r, colour.g, colour.b, effectiveAlpha);
			end;
		end;
		lastWidth, lastHeight, lastAlpha = width, height, opacity;
	end;

	background:SetOpacity(alpha);
	return background;
end;
